import AVFoundation
import AppKit
import Foundation

@MainActor
final class GameSound: ObservableObject {
    static let shared = GameSound()

    @Published var enabled: Bool {
        didSet { UserDefaults.standard.set(enabled, forKey: Self.enabledKey) }
    }

    private static let enabledKey = "pachinko.soundEnabled"
    private var cache: [String: Data] = [:]
    private var activePlayers: [AVAudioPlayer] = []
    private var musicPlayer: AVAudioPlayer?
    private var currentMusic: MusicTrack?
    private let sampleRate: Double = 22_050

    enum SoundFX: String, CaseIterable {
        case fire, nail0, nail1, nail2, bell
        case chucker, pocket, attacker, outHole
        case reelStart, reelStop, reach
        case fever, jackpot, fanfare, startJingle, gameOver
        case uiClick, coin
    }

    enum MusicTrack: String {
        case menu, sakura, dragon, neon, koi, lantern, river, fever
    }

    private init() {
        if UserDefaults.standard.object(forKey: Self.enabledKey) == nil {
            enabled = true
        } else {
            enabled = UserDefaults.standard.bool(forKey: Self.enabledKey)
        }
        for fx in SoundFX.allCases {
            _ = wavData(for: fx)
        }
        for track in [MusicTrack.menu, .sakura, .dragon, .neon, .fever] {
            _ = musicWAV(for: track)
        }
    }

    func toggle() {
        enabled.toggle()
        if enabled {
            play(.uiClick)
            resumeMusicIfNeeded()
        } else {
            stopMusic()
            for player in activePlayers {
                player.stop()
            }
        }
    }

    func uiClick() { play(.uiClick, volume: 0.45) }
    func coin() { play(.coin, volume: 0.55) }
    func fire(power: Double) {
        let p = Float(min(1, max(0, power)))
        play(.fire, volume: 0.28 + p * 0.34, rate: 0.78 + p * 0.46)
    }

    func nail(speed: Double, gold: Bool) {
        let t = min(1, max(0, (speed - 70) / 720))
        let fx: SoundFX = gold ? .nail2 : (t > 0.55 ? .nail1 : .nail0)
        let rate = Float(0.78 + t * 0.7 + (gold ? 0.14 : 0))
        let volume = Float(0.10 + t * 0.38)
        play(fx, volume: volume, rate: rate)
    }

    func gateChime() { play(.bell, volume: 0.72, rate: 1.08) }
    func chucker() { play(.chucker, volume: 0.62) }
    func pocket() { play(.pocket, volume: 0.5) }
    func attacker() { play(.attacker, volume: 0.58) }
    func outHole() { play(.outHole, volume: 0.42) }
    func reelStart() { play(.reelStart, volume: 0.45) }
    func reelStop() { play(.reelStop, volume: 0.5) }
    func reach() { play(.reach, volume: 0.7) }
    func fever() { play(.fever, volume: 0.85) }
    func jackpot() { play(.jackpot, volume: 0.8) }
    func fanfare() { play(.fanfare, volume: 0.6) }
    func startJingle() { play(.startJingle, volume: 0.65) }
    func gameOver() { play(.gameOver, volume: 0.75) }

    func setMusicContext(menu: Bool, fever: Bool, theme: CabinetTheme) {
        if menu {
            playMusic(.menu)
        } else if fever {
            playMusic(.fever)
        } else {
            switch theme {
            case .sakura: playMusic(.sakura)
            case .dragon: playMusic(.dragon)
            case .neon: playMusic(.neon)
            case .koi: playMusic(.koi)
            case .lantern: playMusic(.lantern)
            case .river: playMusic(.river)
            }
        }
    }

    func playMusic(_ track: MusicTrack) {
        if currentMusic == track, musicPlayer?.isPlaying == true { return }
        currentMusic = track
        guard enabled, DisplaySettings.shared.musicEnabled else {
            musicPlayer?.stop()
            musicPlayer = nil
            return
        }
        guard let data = musicWAV(for: track) else { return }
        do {
            let player = try AVAudioPlayer(data: data)
            player.numberOfLoops = -1
            switch track {
            case .menu: player.volume = 0.22
            case .fever: player.volume = 0.28
            default: player.volume = 0.2
            }
            player.prepareToPlay()
            player.play()
            if let old = musicPlayer {
                old.stop()
                retainUntilQuiet(old)
            }
            musicPlayer = player
        } catch {}
    }

    func stopMusic() {
        if let old = musicPlayer {
            old.stop()
            retainUntilQuiet(old)
        }
        musicPlayer = nil
    }

    func resumeMusicIfNeeded() {
        guard let track = currentMusic else { return }
        playMusic(track)
    }

    private func play(_ fx: SoundFX, volume: Float = 1.0, rate: Float = 1) {
        guard enabled else { return }
        guard let data = wavData(for: fx) else { return }
        do {
            let player = try AVAudioPlayer(data: data)
            player.enableRate = true
            player.rate = min(2, max(0.5, rate))
            player.volume = min(1, max(0, volume))
            player.prepareToPlay()
            player.play()
            let rate = Double(player.rate)
            let seconds = max(1.0, player.duration / max(rate, 0.5) + 0.75)
            retainUntilQuiet(player, seconds: seconds)
        } catch {}
    }

    /// AVAudioPlayer posts finishedPlaying: on the run loop after isPlaying flips.
    /// Releasing the player in that window crashes in objc_msgSend.
    private func retainUntilQuiet(_ player: AVAudioPlayer, seconds: Double = 1.0) {
        activePlayers.append(player)
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { [weak self, weak player] in
            guard let self, let player else { return }
            self.activePlayers.removeAll { $0 === player }
        }
    }

    private func wavData(for fx: SoundFX) -> Data? {
        let key = fx.rawValue
        if let cached = cache[key] { return cached }
        let mono: [Float]
        switch fx {
        case .fire: mono = synthFire()
        case .nail0: mono = metalDing(freq: 1680, dur: 0.055, gain: 0.2)
        case .nail1: mono = metalDing(freq: 2140, dur: 0.05, gain: 0.2)
        case .nail2: mono = metalDing(freq: 2680, dur: 0.06, gain: 0.22)
        case .bell: mono = arpeggio([(1174, 0), (1568, 0.07), (1976, 0.14)], duration: 0.42, gain: 0.3)
        case .chucker: mono = arpeggio([(392, 0), (523, 0.07), (659, 0.14)], duration: 0.38, gain: 0.26)
        case .pocket: mono = ding(freq: 784, dur: 0.14, gain: 0.26)
        case .attacker: mono = arpeggio([(523, 0), (659, 0.06), (784, 0.12)], duration: 0.32, gain: 0.28)
        case .outHole: mono = thump(freq: 70, dur: 0.16, gain: 0.26)
        case .reelStart: mono = noiseBurst(dur: 0.18, gain: 0.16, tone: 180)
        case .reelStop: mono = ding(freq: 440, dur: 0.09, gain: 0.24)
        case .reach: mono = arpeggio([(440, 0), (554, 0.1), (659, 0.2), (880, 0.32)], duration: 0.7, gain: 0.26)
        case .fever: mono = synthFever()
        case .jackpot: mono = arpeggio([(523, 0), (659, 0.08), (784, 0.16), (1046, 0.26)], duration: 0.5, gain: 0.28)
        case .fanfare: mono = arpeggio([(392, 0), (494, 0.07), (587, 0.14), (784, 0.22)], duration: 0.42, gain: 0.24)
        case .startJingle: mono = arpeggio([(262, 0), (330, 0.12), (392, 0.24), (523, 0.38), (659, 0.52)], duration: 0.85, gain: 0.24)
        case .gameOver: mono = arpeggio([(392, 0), (330, 0.18), (262, 0.36), (196, 0.56)], duration: 1.0, gain: 0.24)
        case .uiClick: mono = ding(freq: 1400, dur: 0.05, gain: 0.2)
        case .coin: mono = ding(freq: 1480, dur: 0.12, gain: 0.26)
        }
        let data = makeStereoWAV(mono: mono)
        cache[key] = data
        return data
    }

    private func musicWAV(for track: MusicTrack) -> Data? {
        let key = "music.\(track.rawValue)"
        if let cached = cache[key] { return cached }
        let mono: [Float]
        switch track {
        case .menu: mono = loop(bpm: 100, melody: [392, 440, 523, 440, 494, 392, 330, 294], bass: [98, 98, 110, 87], wave: 0, color: 0.3)
        case .sakura: mono = loop(bpm: 108, melody: [523, 587, 659, 784, 659, 587, 523, 440, 392, 440, 523, 587], bass: [130.8, 116.5, 98, 110], wave: 0, color: 0.85)
        case .dragon: mono = loop(bpm: 84, melody: [196, 233, 262, 233, 220, 196, 175, 165, 196, 220, 262, 294], bass: [65.4, 73.4, 55, 49], wave: 1, color: 0.35, pulse: true)
        case .neon: mono = loop(bpm: 144, melody: [523, 659, 784, 1046, 784, 659, 587, 698, 880, 698, 523, 440], bass: [110, 146.8, 130.8, 87.3], wave: 2, color: 1, pulse: true)
        case .koi: mono = loop(bpm: 76, melody: [330, 392, 440, 494, 440, 392, 349, 330, 294, 330, 392, 440], bass: [82.4, 73.4, 87.3, 65.4], wave: 0, color: 0.7)
        case .lantern: mono = loop(bpm: 116, melody: [392, 494, 587, 494, 440, 392, 349, 330, 392, 440, 523, 440], bass: [98, 110, 87.3, 73.4], wave: 1, color: 0.55, pulse: true)
        case .river: mono = loop(bpm: 104, melody: [349, 415, 466, 523, 466, 415, 349, 311, 294, 311, 349, 392], bass: [87.3, 73.4, 98, 65.4], wave: 0, color: 0.45)
        case .fever: mono = loop(bpm: 168, melody: [784, 880, 988, 1046, 988, 880, 784, 659], bass: [164.8, 196, 164.8, 146.8], wave: 2, color: 0.8, pulse: true)
        }
        let data = makeStereoWAV(mono: mono)
        cache[key] = data
        return data
    }

    private func makeStereoWAV(mono: [Float]) -> Data {
        let n = mono.count
        var data = Data()
        data.reserveCapacity(44 + n * 4)

        func appendUInt16(_ v: UInt16) {
            var le = v.littleEndian
            withUnsafeBytes(of: &le) { data.append(contentsOf: $0) }
        }
        func appendUInt32(_ v: UInt32) {
            var le = v.littleEndian
            withUnsafeBytes(of: &le) { data.append(contentsOf: $0) }
        }

        let dataSize = UInt32(n * 4)
        data.append(contentsOf: Array("RIFF".utf8))
        appendUInt32(36 + dataSize)
        data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8))
        appendUInt32(16)
        appendUInt16(1)
        appendUInt16(2)
        appendUInt32(UInt32(sampleRate))
        appendUInt32(UInt32(sampleRate) * 4)
        appendUInt16(4)
        appendUInt16(16)
        data.append(contentsOf: Array("data".utf8))
        appendUInt32(dataSize)

        for s in mono {
            let clipped = max(-1, min(1, s))
            let v = Int16((clipped * Float(Int16.max - 1)).rounded())
            appendUInt16(UInt16(bitPattern: v))
            appendUInt16(UInt16(bitPattern: v))
        }
        return data
    }

    private func sampleCount(_ seconds: Double) -> Int {
        Int((seconds * sampleRate).rounded())
    }

    private func sine(_ phase: Double) -> Float { Float(sin(phase * 2 * Double.pi)) }
    private func square(_ phase: Double) -> Float { sine(phase) >= 0 ? 1 : -1 }
    private func noise() -> Float { Float.random(in: -1...1) }

    private func ding(freq: Double, dur: Double, gain: Float) -> [Float] {
        let n = sampleCount(dur)
        var out = [Float](repeating: 0, count: n)
        for i in 0..<n {
            let t = Double(i) / sampleRate
            let e = exp(Float(-t * 16))
            out[i] = sine(t * freq) * e * gain
            out[i] += sine(t * freq * 2) * e * gain * 0.18
        }
        return out
    }

    private func thump(freq: Double, dur: Double, gain: Float) -> [Float] {
        let n = sampleCount(dur)
        var out = [Float](repeating: 0, count: n)
        for i in 0..<n {
            let t = Double(i) / sampleRate
            let e = exp(Float(-t * 20))
            out[i] = sine(t * freq) * e * gain
            out[i] += noise() * e * gain * 0.12
        }
        return out
    }

    private func noiseBurst(dur: Double, gain: Float, tone: Double) -> [Float] {
        let n = sampleCount(dur)
        var out = [Float](repeating: 0, count: n)
        for i in 0..<n {
            let t = Double(i) / sampleRate
            let e = exp(Float(-t * 22))
            out[i] = noise() * e * gain
            out[i] += sine(t * tone) * e * gain * 0.35
        }
        return out
    }

    private func arpeggio(_ notes: [(Double, Double)], duration: Double, gain: Float) -> [Float] {
        let n = sampleCount(duration)
        var out = [Float](repeating: 0, count: n)
        for (freq, start) in notes {
            let startI = Int(start * sampleRate)
            for i in startI..<n {
                let t = Double(i - startI) / sampleRate
                let e = exp(Float(-t * 7))
                out[i] += sine(t * freq) * e * gain
                out[i] += sine(t * freq * 2) * e * gain * 0.2
            }
        }
        return out
    }

    private func metalDing(freq: Double, dur: Double, gain: Float) -> [Float] {
        let n = sampleCount(dur)
        var out = [Float](repeating: 0, count: n)
        for i in 0..<n {
            let t = Double(i) / sampleRate
            let e = exp(Float(-t * 28))
            let click = t < 0.006 ? Float(1 - t / 0.006) : 0
            out[i] = sine(t * freq) * e * gain
            out[i] += sine(t * freq * 2.03) * e * gain * 0.42
            out[i] += sine(t * freq * 2.71) * e * gain * 0.16
            out[i] += noise() * click * gain * 0.55
        }
        return out
    }

    private func synthFire() -> [Float] {
        let n = sampleCount(0.16)
        var out = [Float](repeating: 0, count: n)
        for i in 0..<n {
            let t = Double(i) / sampleRate
            let click = t < 0.012 ? Float(1 - t / 0.012) : 0
            let freq = 70 + t * 520
            let e = exp(Float(-t * 11))
            out[i] = sine(t * freq) * e * 0.2
            out[i] += sine(t * 90) * click * 0.28
            out[i] += noise() * click * 0.18
        }
        return out
    }

    private func synthFever() -> [Float] {
        arpeggio(
            [(392, 0), (523, 0.06), (659, 0.12), (784, 0.18), (1046, 0.26), (1318, 0.36), (1568, 0.48), (2093, 0.62)],
            duration: 1.15,
            gain: 0.3
        )
    }

    private func loop(
        bpm: Double,
        melody: [Double],
        bass: [Double],
        wave: Int,
        color: Double = 0,
        pulse: Bool = false
    ) -> [Float] {
        let beat = 60.0 / bpm
        let dur = beat * Double(melody.count)
        let n = sampleCount(dur)
        var out = [Float](repeating: 0, count: n)
        for i in 0..<n {
            let t = Double(i) / sampleRate
            let beatPos = t / beat
            let mIdx = Int(beatPos) % melody.count
            let bIdx = Int(beatPos / 2) % bass.count
            let local = beatPos - floor(beatPos)
            let env = Float(max(0, 1 - local * 1.35))
            let m = melody[mIdx]
            switch wave {
            case 0:
                out[i] = sine(t * m) * env * 0.09
            case 2:
                out[i] = (sine(t * m) * 0.65 + square(t * m * 0.5) * 0.35) * env * 0.08
            default:
                out[i] = square(t * m) * env * 0.06
            }
            out[i] += sine(t * m * 2) * env * 0.025
            if color > 0 {
                out[i] += sine(t * m * 1.5) * env * Float(0.045 * color)
            }
            let bassEnv = Float(0.55 + 0.45 * max(0, 1 - local))
            out[i] += sine(t * bass[bIdx]) * 0.09 * bassEnv
            out[i] += sine(t * bass[bIdx] * 2) * 0.02
            if pulse {
                let sub = beatPos - floor(beatPos)
                if Int(beatPos) % 2 == 1 && sub < 0.07 {
                    let hat = Float(1 - sub / 0.07)
                    out[i] += noise() * 0.045 * hat
                }
            }
        }
        return out
    }
}
