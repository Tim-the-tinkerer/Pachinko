import Foundation
import SwiftUI
import Combine

@MainActor
final class GameEngine: ObservableObject {
    @Published var phase: GamePhase = .menu
    @Published var score: Int = 0
    @Published var highScore: Int = HighScoreStore.shared.topScore
    @Published var tray: Int = 0
    @Published var paidOut: Int = 0
    @Published var peakTray: Int = 0
    @Published var board: BoardDef
    @Published var balls: [Ball] = []
    @Published var particles: [Particle] = []
    @Published var floatScores: [FloatingScore] = []
    @Published var railStreaks: [RailStreak] = []
    @Published var message: String = "PACHINKO"
    @Published var dmdLine: String = "INSERT COIN"
    @Published var elapsed: Double = 0
    @Published var shake: Double = 0
    @Published var handlePower: Double = 0.62
    /// 1 when a ball has just been struck, falling back to 0. Drives the plunger.
    @Published var launchKick: Double = 0
    /// 0 on a fresh cabinet, 1 after a long run of balls through that machine.
    @Published var cabinetWear: Double = 0
    @Published var firing: Bool = false
    @Published var difficulty: Difficulty = DisplaySettings.shared.difficulty
    @Published var pendingInitials: [Character] = ["A", "A", "A"]
    @Published var initialsCursor: Int = 0
    @Published var pendingScoreRank: Int = 0
    @Published var reels: [Reel] = [Reel(), Reel(), Reel()]
    @Published var fever: Bool = false
    @Published var feverRoundsLeft: Int = 0
    @Published var feverHits: Int = 0
    @Published var spinning: Bool = false
    @Published var reach: Bool = false

    var showsMenuUI: Bool { phase == .menu || phase == .attract }

    private(set) var isAttractMode = false
    private var timer: Timer?
    private var lastTick: Date = .now
    private var menuInputLock: Double = 0.5
    private var attractIdle: Double = 0
    private var messageTimer: Double = 0
    private var nextBallId = 1
    private var fireCool: Double = 0
    private var nailSoundCool: Double = 0
    private var stuckTime: [Int: Double] = [:]
    private var petalTimer: Double = 0
    private var reelTimer: Double = 0
    private var pendingResult: [ReelSymbol] = [.seven, .seven, .seven]
    private var feverGateTimer: Double = 0
    private var feverGateOpen = false
    private var feverSpark: Double = 0
    private var attackerBurstID = 0
    private var attractClock = 0.0
    private var handleGrab: Double?
    private var simBusy = false
    private var simGeneration = 0
    private var simBacklog = 0.0

    init() {
        board = BoardDef.make(DisplaySettings.shared.cabinetTheme, difficulty: DisplaySettings.shared.difficulty)
        cabinetWear = CabinetWear.amount(board.theme)
        board.windmill.speed *= board.theme.wornMillScale(cabinetWear)
        startLoop()
        show("HANABI FEVER", dmd: board.theme.tagline.uppercased(), hold: 3)
        seedPetals(24)
    }

    var inPlay: Int { balls.filter { $0.alive && !$0.captured }.count }
    var attackerOpen: Bool {
        board.pockets.first(where: { $0.kind == .attacker })?.open ?? false
    }

    // MARK: - Loop

    private func startLoop() {
        stopLoop()
        lastTick = .now
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    private func stopLoop() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        let now = Date()
        var dt = now.timeIntervalSince(lastTick)
        lastTick = now
        if dt > 0.05 { dt = 0.05 }
        elapsed += dt

        if shake > 0 { shake = max(0, shake - dt * 5) }
        if launchKick > 0 { launchKick = max(0, launchKick - dt * 5.5) }
        if messageTimer > 0 {
            messageTimer -= dt
            if messageTimer <= 0 && phase != .gameOver { message = "" }
        }
        decayFlashes(dt: dt)
        updateParticles(dt: dt)
        updateFloatScores(dt: dt)
        updatePetals(dt: dt)
        updateRailStreaks(dt: dt)
        updateReels(dt: dt)
        updateFever(dt: dt)

        switch phase {
        case .menu:
            if menuInputLock > 0 { menuInputLock = max(0, menuInputLock - dt) }
            attractIdle += dt
            if attractIdle > 8 { startAttract() }
        case .attract:
            attractAI(dt: dt)
            scheduleWorld(dt: dt)
        case .playing:
            scheduleWorld(dt: dt)
        case .paused:
            break
        case .gameOver, .enteringScore:
            scheduleWorld(dt: dt)
        }
    }

    /// Physics runs off the main actor. A later frame applies the balls, the wheel angle, and the pocket hits.
    private func scheduleWorld(dt: Double) {
        simBacklog = min(simBacklog + dt, 1.0 / 30.0)
        guard !simBusy else { return }
        let stepDT = simBacklog
        simBacklog = 0
        guard stepDT > 0 else { return }
        simBusy = true
        let generation = simGeneration
        let step = WorldStep(
            dt: stepDT,
            firing: firing,
            spendTray: !isAttractMode,
            tray: tray,
            fireInterval: (isAttractMode ? Difficulty.arcade : difficulty).fireInterval,
            fireCool: fireCool,
            handlePower: handlePower,
            nextBallId: nextBallId,
            nailSoundCool: nailSoundCool,
            balls: balls,
            nails: board.nails,
            walls: board.walls,
            coverWalls: board.coverWalls,
            pockets: board.pockets,
            windmill: board.windmill,
            stuckTime: stuckTime,
            fever: fever
        )
        Task.detached(priority: .userInitiated) {
            let result = TableSimulation.advance(step)
            await MainActor.run {
                self.applyWorld(result, generation: generation)
            }
        }
    }

    private func applyWorld(_ result: WorldStepResult, generation: Int) {
        guard generation == simGeneration else { return }
        simBusy = false
        guard phase != .paused else { return }
        balls = result.balls
        board.windmill.angle = result.windmillAngle
        fireCool = result.fireCool
        nextBallId = result.nextBallId
        nailSoundCool = result.nailSoundCool
        stuckTime = result.stuckTime
        if result.shots > 0 {
            if !isAttractMode {
                tray = max(0, tray - result.shots)
                let n = CabinetWear.noteShot(board.theme)
                let wear = min(1, Double(n) / 520)
                if abs(wear - cabinetWear) > 0.015 { cabinetWear = wear }
                if n % 40 == 0 {
                    let base = FieldPlan.make(board.theme).millSpeed
                    board.windmill.speed = base * board.theme.wornMillScale(wear)
                }
            }
            launchKick = 1
            shake = min(1, shake + 0.045)
            railStreaks.append(RailStreak(t: 0, power: result.shotPower))
            GameSound.shared.fire(power: result.shotPower)
        }
        if let hit = result.nailHit {
            GameSound.shared.nail(speed: hit.speed, gold: hit.gold)
        }
        for point in result.lostAt {
            loseBallVisual(at: point)
        }
        for pocketIndex in result.captures {
            resolvePocket(pocketIndex)
        }
        if phase == .playing { maybeGameOver() }
    }

    private func invalidateWorld() {
        simGeneration += 1
        simBusy = false
        simBacklog = 0
    }

    // MARK: - Fire

    func setFiring(_ on: Bool) {
        guard phase == .playing || phase == .attract else { return }
        firing = on
    }

    func nudgeHandle(_ delta: Double) {
        handlePower = min(1, max(0, handlePower + delta))
    }

    func setHandle(_ value: Double) {
        handlePower = min(1, max(0, value))
    }

    func beginHandleDrag() {
        if handleGrab == nil { handleGrab = handlePower }
    }

    func updateHandleDrag(translation: Double) {
        beginHandleDrag()
        setHandle((handleGrab ?? 0.62) - translation / 220)
        if phase == .playing { setFiring(true) }
    }

    func endHandleDrag() {
        handleGrab = nil
        setFiring(false)
    }

    // MARK: - Pockets

    private func resolvePocket(_ k: Int) {
        guard board.pockets.indices.contains(k) else { return }
        board.pockets[k].flash = 1.35
        let pocket = board.pockets[k]
        burst(at: pocket.pos, color: pocket.kind == .out ? 3 : 1, n: pocket.kind == .attacker ? 18 : 10)
        shake = min(1, shake + (pocket.kind == .out ? 0.08 : 0.18))

        switch pocket.kind {
        case .out:
            loseBallVisual(at: pocket.pos)
        case .chucker:
            pay(pocket.payout, at: pocket.pos, label: "+\(pocket.payout)")
            GameSound.shared.chucker()
            if !spinning && !fever { startSpin() }
        case .tulip:
            pay(pocket.payout, at: pocket.pos, label: "+\(pocket.payout)")
            GameSound.shared.pocket()
        case .attacker:
            pay(pocket.payout, at: pocket.pos, label: "+\(pocket.payout)")
            GameSound.shared.attacker()
            if fever {
                feverHits += 1
                if feverHits % 5 == 0 {
                    show("FEVER HIT \(feverHits)", dmd: "ATTACK \(feverHits)", hold: 1.2)
                }
            }
        }
    }

    private func pay(_ n: Int, at p: Vec, label: String) {
        if isAttractMode { return }
        tray += n
        paidOut += n
        score += n * 100
        if tray > peakTray { peakTray = tray }
        floatScores.append(FloatingScore(pos: p, text: label, life: 1.1, colorIndex: 1))
        if score > highScore { highScore = score }
    }

    private func loseBallVisual(at p: Vec) {
        GameSound.shared.outHole()
        burst(at: p, color: 3, n: 6)
    }

    // MARK: - Reels

    private func startSpin() {
        spinning = true
        reach = false
        pendingResult = rollResult()
        reelTimer = 0
        for i in reels.indices {
            reels[i].spinning = true
            reels[i].speed = 18 + Double(i) * 3
            reels[i].stopIndex = pendingResult[i].rawValue
        }
        dmdLine = "CHANCE"
        GameSound.shared.reelStart()
        show("CHANCE", dmd: "START HOLE", hold: 1.2)
    }

    private func rollResult() -> [ReelSymbol] {
        let rules = isAttractMode ? Difficulty.arcade : difficulty
        let r = Double.random(in: 0...1)
        if r < rules.feverChance {
            return [.seven, .seven, .seven]
        }
        if r < rules.feverChance + 0.07 {
            return [.bar, .bar, .bar]
        }
        if r < rules.feverChance + 0.13 {
            return [.cherry, .cherry, .cherry]
        }
        if r < rules.feverChance + 0.20 {
            return [.star, .star, .star]
        }
        if r < rules.feverChance + 0.30 {
            let s: ReelSymbol = [.cherry, .bell, .bar, .star].randomElement()!
            return [s, s, .blank]
        }
        if r < rules.feverChance + 0.42 {
            return [.seven, .seven, [.bar, .cherry, .bell, .blank].randomElement()!]
        }
        return untunedRoll()
    }

    /// The leftover draw must not mint a second copy of a scripted win.
    private func untunedRoll() -> [ReelSymbol] {
        let symbols = ReelSymbol.allCases
        for _ in 0..<12 {
            let roll = (0..<3).map { _ in symbols.randomElement()! }
            if roll[0] == roll[1], roll[0] != .blank { continue }
            return roll
        }
        return [.blank, .cherry, .bar]
    }

    private func updateReels(dt: Double) {
        for i in reels.indices {
            if reels[i].spinning {
                reels[i].offset += reels[i].speed * dt
                reels[i].speed *= max(0.4, 1 - dt * 0.15)
            }
        }
        guard spinning else { return }
        reelTimer += dt

        let t1 = 0.85
        let t2 = 1.55
        var t3 = 2.25
        if pendingResult[0] == .seven && pendingResult[1] == .seven {
            t3 = 3.4
            if reelTimer > t2 && !reach {
                reach = true
                dmdLine = "REACH"
                show("REACH", dmd: "COME ON 7", hold: 1.6)
                GameSound.shared.reach()
            }
        }

        if reelTimer >= t1 { stopReel(0) }
        if reelTimer >= t2 { stopReel(1) }
        if reelTimer >= t3 { stopReel(2) }
    }

    private func stopReel(_ i: Int) {
        guard reels[i].spinning else { return }
        reels[i].spinning = false
        reels[i].speed = 0
        reels[i].display = pendingResult[i]
        reels[i].offset = Double(pendingResult[i].rawValue)
        GameSound.shared.reelStop()
        if i == 2 {
            spinning = false
            resolveSpin()
        }
    }

    private func resolveSpin() {
        let a = reels[0].display
        let b = reels[1].display
        let c = reels[2].display
        dmdLine = "\(a.shortGlyph)  \(b.shortGlyph)  \(c.shortGlyph)"

        if a == .seven && b == .seven && c == .seven {
            beginFever()
        } else if a == .bar && b == .bar && c == .bar {
            pay(5, at: Vec(x: 186, y: 120), label: "+5")
            openAttackerBurst(2.8)
            show("BAR BONUS", dmd: "ATTACK OPEN", hold: 2)
            GameSound.shared.jackpot()
        } else if a == .cherry && b == .cherry && c == .cherry {
            pay(4, at: Vec(x: 186, y: 120), label: "+4")
            show("SAKURA", dmd: "CHERRY 4", hold: 1.8)
            GameSound.shared.fanfare()
        } else if a == .star && b == .star && c == .star {
            pay(3, at: Vec(x: 186, y: 120), label: "+3")
            show("STAR", dmd: "LUCKY 3", hold: 1.6)
            GameSound.shared.fanfare()
        } else if a == b && a != .blank && c == .blank {
            pay(2, at: Vec(x: 186, y: 120), label: "+2")
            GameSound.shared.pocket()
        } else if a == .seven && b == .seven {
            dmdLine = "REACH"
        } else {
            dmdLine = fever ? "FEVER" : "HAZURE"
        }
        reach = false
    }

    // MARK: - Fever

    private func beginFever() {
        fever = true
        feverRoundsLeft = (isAttractMode ? Difficulty.arcade : difficulty).feverRounds
        feverHits = 0
        feverGateTimer = 0
        feverGateOpen = true
        setAttacker(true)
        show("FEVER", dmd: "\(feverRoundsLeft) ROUNDS", hold: 2.8)
        GameSound.shared.fever()
        GameSound.shared.setMusicContext(menu: false, fever: true, theme: board.theme)
        fireworks()
        shake = 1
        feverSpark = 0
    }

    private func updateFever(dt: Double) {
        guard fever else { return }
        feverGateTimer += dt
        let openDur = 2.15
        let closedDur = 0.75
        let cycle = openDur + closedDur
        let t = feverGateTimer.truncatingRemainder(dividingBy: cycle)
        let shouldOpen = t < openDur
        if shouldOpen != feverGateOpen {
            feverGateOpen = shouldOpen
            setAttacker(shouldOpen)
            if !shouldOpen {
                feverRoundsLeft -= 1
                if feverRoundsLeft <= 0 {
                    endFever()
                } else {
                    dmdLine = "FEVER \(feverRoundsLeft)"
                }
            } else if feverRoundsLeft > 0 {
                dmdLine = "ATTACK OPEN  \(feverRoundsLeft)"
                shake = min(1, shake + 0.62)
                if let gateIndex = board.pockets.firstIndex(where: { $0.kind == .attacker }) {
                    burst(at: board.pockets[gateIndex].pos, color: 2, n: 26)
                    board.pockets[gateIndex].flash = 1.35
                }
                GameSound.shared.gateChime()
            }
        }
        feverSpark += dt
        if feverSpark > 0.16 {
            feverSpark = 0
            let spark = Vec(x: Double.random(in: 48...330), y: Double.random(in: 36...220))
            burst(at: spark, color: Int.random(in: 1...2), n: 4)
        }
    }

    private func endFever() {
        fever = false
        feverGateOpen = false
        setAttacker(false)
        show("FEVER END", dmd: "HITS \(feverHits)", hold: 2.2)
        GameSound.shared.fanfare()
        GameSound.shared.setMusicContext(menu: false, fever: false, theme: board.theme)
        dmdLine = "HITS \(feverHits)"
    }

    private func setAttacker(_ open: Bool) {
        for i in board.pockets.indices where board.pockets[i].kind == .attacker {
            board.pockets[i].open = open
        }
    }

    private func openAttackerBurst(_ seconds: Double) {
        attackerBurstID += 1
        let token = attackerBurstID
        setAttacker(true)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard self.attackerBurstID == token, !self.fever else { return }
            self.setAttacker(false)
        }
    }

    // MARK: - Game flow

    func startGame() {
        invalidateWorld()
        isAttractMode = false
        difficulty = DisplaySettings.shared.difficulty
        board = BoardDef.make(DisplaySettings.shared.cabinetTheme, difficulty: difficulty)
        cabinetWear = CabinetWear.amount(board.theme)
        board.windmill.speed *= board.theme.wornMillScale(cabinetWear)
        balls.removeAll()
        particles.removeAll()
        floatScores.removeAll()
        railStreaks.removeAll()
        tray = difficulty.startingBalls
        paidOut = 0
        peakTray = tray
        score = 0
        fever = false
        feverRoundsLeft = 0
        feverHits = 0
        spinning = false
        reach = false
        firing = false
        fireCool = 0
        nailSoundCool = 0
        launchKick = 0
        feverGateOpen = false
        feverGateTimer = 0
        feverSpark = 0
        attackerBurstID += 1
        handlePower = 0.62
        reels = [Reel(display: .seven), Reel(display: .seven), Reel(display: .seven)]
        phase = .playing
        stuckTime.removeAll()
        seedPetals(18)
        show("GOOD LUCK", dmd: "\(tray) BALLS", hold: 2)
        GameSound.shared.startJingle()
        GameSound.shared.setMusicContext(menu: false, fever: false, theme: board.theme)
    }

    func applySelectedTable() {
        invalidateWorld()
        board = BoardDef.make(DisplaySettings.shared.cabinetTheme, difficulty: DisplaySettings.shared.difficulty)
        cabinetWear = CabinetWear.amount(board.theme)
        board.windmill.speed *= board.theme.wornMillScale(cabinetWear)
        GameSound.shared.setMusicContext(menu: true, fever: false, theme: board.theme)
    }

    func backToMenu() {
        invalidateWorld()
        isAttractMode = false
        firing = false
        fever = false
        spinning = false
        setAttacker(false)
        attackerBurstID += 1
        feverGateOpen = false
        feverGateTimer = 0
        fireCool = 0
        balls.removeAll()
        phase = .menu
        attractIdle = 0
        menuInputLock = 0.35
        message = "PACHINKO"
        dmdLine = "INSERT COIN"
        GameSound.shared.setMusicContext(menu: true, fever: false, theme: board.theme)
    }

    private func startAttract() {
        invalidateWorld()
        isAttractMode = true
        phase = .attract
        board = BoardDef.make(DisplaySettings.shared.cabinetTheme, difficulty: .arcade)
        cabinetWear = CabinetWear.amount(board.theme)
        board.windmill.speed *= board.theme.wornMillScale(cabinetWear)
        balls.removeAll()
        tray = 200
        firing = false
        attractClock = 0
        handlePower = attractPower(forX: attractChuckerX())
        dmdLine = "DEMO"
        show("HANABI", dmd: "DEMO", hold: 2.2)
    }

    private func attractChuckerX() -> Double {
        board.pockets.first(where: { $0.kind == .chucker })?.pos.x ?? 186
    }

    private func attractPower(forX x: Double) -> Double {
        min(0.92, max(0.12, (328.0 - x) / 286.0))
    }

    private func attractAI(dt: Double) {
        attractClock += dt
        let cycle = attractClock.truncatingRemainder(dividingBy: 18)
        let show = attractPower(forX: attractChuckerX())
        let sideX = board.pockets.first(where: { $0.kind == .tulip })?.pos.x ?? 72
        let target: Double
        let wantFire: Bool
        let caption: String
        switch cycle {
        case 0..<3.4:
            target = show
            wantFire = cycle > 0.55 && inPlay < 9
            caption = "CENTER"
        case 3.4..<6.2:
            target = show + 0.045 * sin(cycle * 3)
            wantFire = false
            caption = "HOLD"
        case 6.2..<11:
            let u = (cycle - 6.2) / 4.8
            target = 0.22 + u * 0.62
            wantFire = inPlay < 7 && cycle.truncatingRemainder(dividingBy: 0.85) < 0.38
            caption = "SWEEP"
        case 11..<14.2:
            target = attractPower(forX: sideX)
            wantFire = inPlay < 11
            caption = "SIDE"
        default:
            target = show
            wantFire = inPlay < 12
            caption = "CENTER"
        }
        let ease = min(1, dt * 2.6)
        handlePower += (min(0.94, max(0.08, target)) - handlePower) * ease
        firing = wantFire
        if dmdLine != caption { dmdLine = caption }
    }

    private func maybeGameOver() {
        guard phase == .playing else { return }
        guard tray <= 0, inPlay == 0, !spinning, !fever else { return }
        phase = .gameOver
        firing = false
        show("GAME OVER", dmd: "PAYOUT \(paidOut)", hold: 4)
        GameSound.shared.gameOver()
        GameSound.shared.setMusicContext(menu: true, fever: false, theme: board.theme)
        if HighScoreStore.shared.qualifies(score) {
            pendingScoreRank = HighScoreStore.shared.rank(for: score) ?? 1
            pendingInitials = ["A", "A", "A"]
            initialsCursor = 0
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { [weak self] in
                guard let self, self.phase == .gameOver else { return }
                self.phase = .enteringScore
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) { [weak self] in
                guard let self, self.phase == .gameOver else { return }
                self.backToMenu()
            }
        }
    }

    func submitInitials() {
        let s = String(pendingInitials)
        HighScoreStore.shared.submit(
            initials: s,
            score: score,
            table: board.theme,
            difficulty: difficulty
        )
        highScore = HighScoreStore.shared.topScore
        GameSound.shared.uiClick()
        backToMenu()
    }

    func pauseToggle() {
        if phase == .playing {
            phase = .paused
            firing = false
            show("PAUSE", dmd: "PAUSED", hold: 99)
        } else if phase == .paused {
            phase = .playing
            message = ""
            dmdLine = fever ? "FEVER \(feverRoundsLeft)" : "PLAY"
        }
    }

    // MARK: - Input

    func handleKeyDown(_ key: String) {
        if phase == .enteringScore {
            handleInitials(key)
            return
        }
        switch key {
        case " ", "return":
            if showsMenuUI {
                startGame()
            } else if phase == .gameOver {
                backToMenu()
            } else if phase == .playing {
                setFiring(true)
            } else if phase == .paused {
                pauseToggle()
            }
        case "escape":
            if phase == .playing || phase == .paused || phase == .gameOver {
                backToMenu()
            }
        case "p":
            if phase == .playing || phase == .paused { pauseToggle() }
        case "leftarrow", "a":
            nudgeHandle(-0.035)
        case "rightarrow", "d":
            nudgeHandle(0.035)
        case "uparrow", "w":
            nudgeHandle(0.05)
        case "downarrow", "s":
            nudgeHandle(-0.05)
        case "1":
            if showsMenuUI {
                DisplaySettings.shared.difficulty = .novice
                difficulty = .novice
                GameSound.shared.uiClick()
            }
        case "2":
            if showsMenuUI {
                DisplaySettings.shared.difficulty = .arcade
                difficulty = .arcade
                GameSound.shared.uiClick()
            }
        case "3":
            if showsMenuUI {
                DisplaySettings.shared.difficulty = .insane
                difficulty = .insane
                GameSound.shared.uiClick()
            }
        default:
            break
        }
    }

    func handleKeyUp(_ key: String) {
        if key == " " {
            setFiring(false)
        }
    }

    private func handleInitials(_ key: String) {
        switch key {
        case "leftarrow":
            initialsCursor = max(0, initialsCursor - 1)
        case "rightarrow":
            initialsCursor = min(2, initialsCursor + 1)
        case "uparrow", "w":
            cycleInitial(1)
        case "downarrow", "s":
            cycleInitial(-1)
        case "return", " ":
            if initialsCursor < 2 {
                initialsCursor += 1
            } else {
                submitInitials()
            }
        case "escape":
            submitInitials()
        default:
            if let ch = key.uppercased().first, ch.isLetter {
                pendingInitials[initialsCursor] = ch
                if initialsCursor < 2 { initialsCursor += 1 }
                GameSound.shared.uiClick()
            }
        }
    }

    private func cycleInitial(_ dir: Int) {
        let letters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        let cur = pendingInitials[initialsCursor]
        let idx = letters.firstIndex(of: cur) ?? 0
        let next = (idx + dir + letters.count) % letters.count
        pendingInitials[initialsCursor] = letters[next]
        GameSound.shared.uiClick()
    }

    // MARK: - FX helpers

    private func show(_ msg: String, dmd: String, hold: Double) {
        message = msg
        dmdLine = dmd
        messageTimer = hold
    }

    private func decayFlashes(dt: Double) {
        for i in board.pockets.indices {
            if board.pockets[i].flash > 0 {
                board.pockets[i].flash = max(0, board.pockets[i].flash - dt * 1.15)
            }
        }
    }

    private func burst(at p: Vec, color: Int, n: Int) {
        for _ in 0..<n {
            let ang = Double.random(in: 0..<(2 * .pi))
            let sp = Double.random(in: 40...220)
            particles.append(Particle(
                pos: p,
                vel: Vec(x: cos(ang) * sp, y: sin(ang) * sp),
                life: Double.random(in: 0.25...0.7),
                maxLife: 0.7,
                colorIndex: color,
                size: Double.random(in: 1.6...3.8),
                petal: false
            ))
        }
    }

    private func fireworks() {
        for _ in 0..<5 {
            let p = Vec(x: Double.random(in: 60...310), y: Double.random(in: 70...240))
            burst(at: p, color: 1, n: 16)
            burst(at: p, color: 2, n: 10)
        }
    }

    private func updateParticles(dt: Double) {
        for i in particles.indices {
            particles[i].life -= dt
            particles[i].pos += particles[i].vel * dt
            particles[i].vel.y += (particles[i].petal ? 30 : 80) * dt
            particles[i].vel = particles[i].vel * (1 - dt * 1.4)
        }
        particles.removeAll { $0.life <= 0 || !$0.pos.x.isFinite || !$0.pos.y.isFinite }
        if particles.count > 280 {
            particles.removeFirst(particles.count - 280)
        }
    }

    private func updateFloatScores(dt: Double) {
        for i in floatScores.indices {
            floatScores[i].life -= dt
            floatScores[i].pos.y -= 28 * dt
        }
        floatScores.removeAll { $0.life <= 0 }
    }

    private func updateRailStreaks(dt: Double) {
        for i in railStreaks.indices {
            railStreaks[i].t += dt / 0.16
        }
        railStreaks.removeAll { $0.t >= 1 }
    }

    private func seedPetals(_ n: Int) {
        for _ in 0..<n {
            particles.append(makePetal(resetY: Double.random(in: 20...680)))
        }
    }

    private func updatePetals(dt: Double) {
        petalTimer += dt
        if petalTimer > 0.35 {
            petalTimer = 0
            if particles.filter(\.petal).count < 22 {
                particles.append(makePetal(resetY: -10))
            }
        }
    }

    private func makePetal(resetY: Double) -> Particle {
        Particle(
            pos: Vec(x: Double.random(in: 24...340), y: resetY),
            vel: Vec(x: Double.random(in: -18...18), y: Double.random(in: 18...46)),
            life: Double.random(in: 6...12),
            maxLife: 10,
            colorIndex: 0,
            size: Double.random(in: 2.4...5.2),
            petal: true
        )
    }

}
