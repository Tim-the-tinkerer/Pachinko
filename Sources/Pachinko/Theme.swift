import SwiftUI
import AppKit
import Combine

enum CabinetTheme: String, CaseIterable, Identifiable {
    case sakura = "Sakura Hanabi"
    case dragon = "Gold Dragon"
    case neon = "Shinjuku Night"
    case koi = "Koi Garden"
    case lantern = "Lantern Alley"
    case river = "Split River"

    var id: String { rawValue }

    var shortName: String {
        switch self {
        case .sakura: return "SAKURA"
        case .dragon: return "DRAGON"
        case .neon: return "NEON"
        case .koi: return "KOI"
        case .lantern: return "LANTERN"
        case .river: return "RIVER"
        }
    }

    var tagline: String {
        switch self {
        case .sakura: return "Classic field, petals of fortune"
        case .dragon: return "Wheel to the right, scale-shaped nails"
        case .neon: return "Wheel on the left, city grid"
        case .koi: return "Wide garden, slow wheel"
        case .lantern: return "Diagonal nails, start sits right"
        case .river: return "The wheel splits two currents"
        }
    }

    /// How a long run of balls settles into the wheel. Sakura does not drift.
    func wornMillScale(_ wear: Double) -> Double {
        let w = min(1, max(0, wear))
        switch self {
        case .sakura: return 1
        case .dragon: return 1 - 0.07 * w
        case .neon: return 1 + 0.05 * w
        case .koi: return 1 - 0.06 * w
        case .lantern: return 1 + 0.04 * w
        case .river: return 1 + 0.08 * w
        }
    }
}

enum CabinetWear {
    private static func key(_ theme: CabinetTheme) -> String {
        "pachinko.shots.\(theme.rawValue)"
    }

    static func amount(_ theme: CabinetTheme) -> Double {
        min(1, Double(UserDefaults.standard.integer(forKey: key(theme))) / 520)
    }

    @discardableResult
    static func noteShot(_ theme: CabinetTheme) -> Int {
        let k = key(theme)
        let n = UserDefaults.standard.integer(forKey: k) + 1
        UserDefaults.standard.set(n, forKey: k)
        return n
    }
}

extension CabinetTheme {
    var machineName: String {
        switch self {
        case .sakura: return "CR HANABI"
        case .dragon: return "CR RYU"
        case .neon: return "CR NEON"
        case .koi: return "CR KOI"
        case .lantern: return "CR CHOCHIN"
        case .river: return "CR NAGARE"
        }
    }
}

struct ColorPalette {
    let void: Color
    let voidNS: NSColor
    let playfield: Color
    let playfieldAlt: Color
    let lacquer: Color
    let gold: Color
    let goldHi: Color
    let nail: Color
    let nailGold: Color
    let ball: Color
    let ballHi: Color
    let insertA: Color
    let insertB: Color
    let insertC: Color
    let hud: Color
    let hudDim: Color
    let text: Color
    let panel: Color
    let danger: Color
    let glow: Color
    let fever: Color
    let wood: Color

    static func make(theme: CabinetTheme) -> ColorPalette {
        switch theme {
        case .sakura:
            return ColorPalette(
                void: Color(red: 0.07, green: 0.02, blue: 0.04),
                voidNS: NSColor(srgbRed: 0.07, green: 0.02, blue: 0.04, alpha: 1),
                playfield: Color(red: 0.42, green: 0.07, blue: 0.14),
                playfieldAlt: Color(red: 0.28, green: 0.04, blue: 0.10),
                lacquer: Color(red: 0.08, green: 0.03, blue: 0.05),
                gold: Color(red: 0.96, green: 0.78, blue: 0.28),
                goldHi: Color(red: 1.0, green: 0.93, blue: 0.62),
                nail: Color(red: 0.82, green: 0.78, blue: 0.68),
                nailGold: Color(red: 0.95, green: 0.80, blue: 0.28),
                ball: Color(red: 0.78, green: 0.80, blue: 0.84),
                ballHi: Color.white,
                insertA: Color(red: 1.0, green: 0.55, blue: 0.68),
                insertB: Color(red: 1.0, green: 0.82, blue: 0.30),
                insertC: Color(red: 1.0, green: 0.32, blue: 0.38),
                hud: Color(red: 1.0, green: 0.72, blue: 0.78),
                hudDim: Color(red: 0.62, green: 0.42, blue: 0.46),
                text: Color(red: 1.0, green: 0.94, blue: 0.90),
                panel: Color(red: 0.10, green: 0.04, blue: 0.06),
                danger: Color(red: 1.0, green: 0.22, blue: 0.28),
                glow: Color(red: 1.0, green: 0.45, blue: 0.58),
                fever: Color(red: 1.0, green: 0.85, blue: 0.25),
                wood: Color(red: 0.18, green: 0.07, blue: 0.08)
            )
        case .dragon:
            return ColorPalette(
                void: Color(red: 0.05, green: 0.03, blue: 0.01),
                voidNS: NSColor(srgbRed: 0.05, green: 0.03, blue: 0.01, alpha: 1),
                playfield: Color(red: 0.38, green: 0.08, blue: 0.04),
                playfieldAlt: Color(red: 0.22, green: 0.05, blue: 0.03),
                lacquer: Color(red: 0.06, green: 0.03, blue: 0.02),
                gold: Color(red: 0.98, green: 0.80, blue: 0.22),
                goldHi: Color(red: 1.0, green: 0.94, blue: 0.55),
                nail: Color(red: 0.86, green: 0.78, blue: 0.52),
                nailGold: Color(red: 1.0, green: 0.84, blue: 0.22),
                ball: Color(red: 0.82, green: 0.80, blue: 0.72),
                ballHi: Color(red: 1.0, green: 0.98, blue: 0.88),
                insertA: Color(red: 0.18, green: 0.72, blue: 0.42),
                insertB: Color(red: 1.0, green: 0.78, blue: 0.18),
                insertC: Color(red: 0.95, green: 0.28, blue: 0.12),
                hud: Color(red: 1.0, green: 0.78, blue: 0.28),
                hudDim: Color(red: 0.55, green: 0.42, blue: 0.28),
                text: Color(red: 1.0, green: 0.95, blue: 0.84),
                panel: Color(red: 0.08, green: 0.04, blue: 0.02),
                danger: Color(red: 1.0, green: 0.25, blue: 0.12),
                glow: Color(red: 1.0, green: 0.62, blue: 0.18),
                fever: Color(red: 1.0, green: 0.88, blue: 0.22),
                wood: Color(red: 0.16, green: 0.07, blue: 0.03)
            )
        case .neon:
            return ColorPalette(
                void: Color(red: 0.03, green: 0.02, blue: 0.08),
                voidNS: NSColor(srgbRed: 0.03, green: 0.02, blue: 0.08, alpha: 1),
                playfield: Color(red: 0.12, green: 0.04, blue: 0.22),
                playfieldAlt: Color(red: 0.08, green: 0.03, blue: 0.16),
                lacquer: Color(red: 0.04, green: 0.03, blue: 0.10),
                gold: Color(red: 0.95, green: 0.82, blue: 0.28),
                goldHi: Color(red: 1.0, green: 0.94, blue: 0.60),
                nail: Color(red: 0.75, green: 0.82, blue: 0.95),
                nailGold: Color(red: 0.35, green: 0.95, blue: 1.0),
                ball: Color(red: 0.80, green: 0.84, blue: 0.92),
                ballHi: Color.white,
                insertA: Color(red: 0.25, green: 0.95, blue: 1.0),
                insertB: Color(red: 1.0, green: 0.28, blue: 0.78),
                insertC: Color(red: 0.55, green: 0.35, blue: 1.0),
                hud: Color(red: 0.40, green: 0.95, blue: 1.0),
                hudDim: Color(red: 0.42, green: 0.48, blue: 0.62),
                text: Color(red: 0.92, green: 0.95, blue: 1.0),
                panel: Color(red: 0.05, green: 0.04, blue: 0.12),
                danger: Color(red: 1.0, green: 0.30, blue: 0.45),
                glow: Color(red: 0.40, green: 0.85, blue: 1.0),
                fever: Color(red: 1.0, green: 0.35, blue: 0.85),
                wood: Color(red: 0.08, green: 0.05, blue: 0.16)
            )
        case .koi:
            return ColorPalette(
                void: Color(red: 0.02, green: 0.06, blue: 0.07),
                voidNS: NSColor(srgbRed: 0.02, green: 0.06, blue: 0.07, alpha: 1),
                playfield: Color(red: 0.05, green: 0.28, blue: 0.30),
                playfieldAlt: Color(red: 0.03, green: 0.16, blue: 0.20),
                lacquer: Color(red: 0.03, green: 0.08, blue: 0.09),
                gold: Color(red: 0.93, green: 0.84, blue: 0.62),
                goldHi: Color(red: 1.0, green: 0.96, blue: 0.82),
                nail: Color(red: 0.86, green: 0.90, blue: 0.86),
                nailGold: Color(red: 0.98, green: 0.78, blue: 0.42),
                ball: Color(red: 0.84, green: 0.88, blue: 0.86),
                ballHi: Color.white,
                insertA: Color(red: 0.98, green: 0.55, blue: 0.42),
                insertB: Color(red: 0.55, green: 0.86, blue: 0.78),
                insertC: Color(red: 0.95, green: 0.72, blue: 0.38),
                hud: Color(red: 0.72, green: 0.90, blue: 0.84),
                hudDim: Color(red: 0.42, green: 0.58, blue: 0.54),
                text: Color(red: 0.94, green: 0.97, blue: 0.94),
                panel: Color(red: 0.03, green: 0.08, blue: 0.09),
                danger: Color(red: 0.95, green: 0.32, blue: 0.28),
                glow: Color(red: 0.45, green: 0.85, blue: 0.75),
                fever: Color(red: 1.0, green: 0.72, blue: 0.35),
                wood: Color(red: 0.08, green: 0.16, blue: 0.15)
            )
        case .lantern:
            return ColorPalette(
                void: Color(red: 0.07, green: 0.03, blue: 0.02),
                voidNS: NSColor(srgbRed: 0.07, green: 0.03, blue: 0.02, alpha: 1),
                playfield: Color(red: 0.36, green: 0.12, blue: 0.05),
                playfieldAlt: Color(red: 0.20, green: 0.06, blue: 0.04),
                lacquer: Color(red: 0.10, green: 0.04, blue: 0.03),
                gold: Color(red: 1.0, green: 0.72, blue: 0.28),
                goldHi: Color(red: 1.0, green: 0.90, blue: 0.55),
                nail: Color(red: 0.95, green: 0.86, blue: 0.70),
                nailGold: Color(red: 1.0, green: 0.62, blue: 0.18),
                ball: Color(red: 0.90, green: 0.84, blue: 0.72),
                ballHi: Color(red: 1.0, green: 0.96, blue: 0.86),
                insertA: Color(red: 1.0, green: 0.45, blue: 0.18),
                insertB: Color(red: 1.0, green: 0.82, blue: 0.35),
                insertC: Color(red: 0.85, green: 0.22, blue: 0.18),
                hud: Color(red: 1.0, green: 0.78, blue: 0.42),
                hudDim: Color(red: 0.62, green: 0.42, blue: 0.28),
                text: Color(red: 1.0, green: 0.94, blue: 0.84),
                panel: Color(red: 0.12, green: 0.05, blue: 0.03),
                danger: Color(red: 1.0, green: 0.28, blue: 0.16),
                glow: Color(red: 1.0, green: 0.55, blue: 0.20),
                fever: Color(red: 1.0, green: 0.78, blue: 0.22),
                wood: Color(red: 0.22, green: 0.08, blue: 0.04)
            )
        case .river:
            return ColorPalette(
                void: Color(red: 0.03, green: 0.05, blue: 0.08),
                voidNS: NSColor(srgbRed: 0.03, green: 0.05, blue: 0.08, alpha: 1),
                playfield: Color(red: 0.10, green: 0.18, blue: 0.28),
                playfieldAlt: Color(red: 0.06, green: 0.10, blue: 0.18),
                lacquer: Color(red: 0.04, green: 0.06, blue: 0.10),
                gold: Color(red: 0.78, green: 0.86, blue: 0.92),
                goldHi: Color(red: 0.94, green: 0.97, blue: 1.0),
                nail: Color(red: 0.78, green: 0.84, blue: 0.90),
                nailGold: Color(red: 0.55, green: 0.82, blue: 0.95),
                ball: Color(red: 0.82, green: 0.88, blue: 0.92),
                ballHi: Color.white,
                insertA: Color(red: 0.35, green: 0.75, blue: 0.95),
                insertB: Color(red: 0.95, green: 0.35, blue: 0.32),
                insertC: Color(red: 0.45, green: 0.62, blue: 0.85),
                hud: Color(red: 0.70, green: 0.86, blue: 0.95),
                hudDim: Color(red: 0.42, green: 0.52, blue: 0.62),
                text: Color(red: 0.92, green: 0.95, blue: 0.98),
                panel: Color(red: 0.04, green: 0.07, blue: 0.12),
                danger: Color(red: 0.95, green: 0.32, blue: 0.30),
                glow: Color(red: 0.40, green: 0.72, blue: 0.95),
                fever: Color(red: 0.95, green: 0.42, blue: 0.38),
                wood: Color(red: 0.08, green: 0.12, blue: 0.18)
            )
        }
    }
}

@MainActor
final class DisplaySettings: ObservableObject {
    static let shared = DisplaySettings()

    @Published var cabinetTheme: CabinetTheme {
        didSet { UserDefaults.standard.set(cabinetTheme.rawValue, forKey: Self.themeKey) }
    }

    @Published var crtEnabled: Bool {
        didSet { UserDefaults.standard.set(crtEnabled, forKey: Self.crtKey) }
    }

    @Published var musicEnabled: Bool {
        didSet {
            UserDefaults.standard.set(musicEnabled, forKey: Self.musicKey)
            if musicEnabled {
                GameSound.shared.resumeMusicIfNeeded()
            } else {
                GameSound.shared.stopMusic()
            }
        }
    }

    @Published var difficulty: Difficulty {
        didSet { UserDefaults.standard.set(difficulty.rawValue, forKey: Self.diffKey) }
    }

    private static let themeKey = "pachinko.cabinetTheme"
    private static let crtKey = "pachinko.crtEnabled"
    private static let musicKey = "pachinko.musicEnabled"
    private static let diffKey = "pachinko.difficulty"

    var palette: ColorPalette { ColorPalette.make(theme: cabinetTheme) }

    private init() {
        if let raw = UserDefaults.standard.string(forKey: Self.themeKey),
           let theme = CabinetTheme(rawValue: raw) {
            cabinetTheme = theme
        } else {
            cabinetTheme = .sakura
        }
        if UserDefaults.standard.object(forKey: Self.crtKey) == nil {
            crtEnabled = true
        } else {
            crtEnabled = UserDefaults.standard.bool(forKey: Self.crtKey)
        }
        if UserDefaults.standard.object(forKey: Self.musicKey) == nil {
            musicEnabled = true
        } else {
            musicEnabled = UserDefaults.standard.bool(forKey: Self.musicKey)
        }
        if let raw = UserDefaults.standard.string(forKey: Self.diffKey),
           let d = Difficulty(rawValue: raw) {
            difficulty = d
        } else {
            difficulty = .arcade
        }
    }

    func cycleCabinet() {
        let all = CabinetTheme.allCases
        guard let idx = all.firstIndex(of: cabinetTheme) else { return }
        cabinetTheme = all[(idx + 1) % all.count]
        GameSound.shared.uiClick()
    }

    func toggleCRT() {
        crtEnabled.toggle()
        GameSound.shared.uiClick()
    }

    func toggleMusic() {
        musicEnabled.toggle()
        if musicEnabled { GameSound.shared.uiClick() }
    }
}

enum PachinkoTheme {
    @MainActor static var palette: ColorPalette { DisplaySettings.shared.palette }

    static let monoHUD = Font.system(size: 13, weight: .semibold, design: .monospaced)
    static let monoTitle = Font.system(size: 42, weight: .bold, design: .monospaced)
    static let monoBig = Font.system(size: 22, weight: .bold, design: .monospaced)
}
