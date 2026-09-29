import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var engine = GameEngine()
    @ObservedObject private var settings = DisplaySettings.shared

    private var palette: ColorPalette { settings.palette }

    var body: some View {
        ZStack {
            palette.void.ignoresSafeArea()

            if engine.showsMenuUI {
                MenuView(engine: engine)
            } else {
                gameplay
            }
        }
        .background(KeyEventHandler(engine: engine))
        .onAppear {
            GameSound.shared.setMusicContext(menu: true, fever: false, theme: settings.cabinetTheme)
        }
        .onChange(of: settings.cabinetTheme) { _ in
            if engine.showsMenuUI {
                engine.applySelectedTable()
            }
        }
    }

    private var gameplay: some View {
        VStack(spacing: 0) {
            hudBar
            dmdBar
            ZStack {
                GameCanvasView(engine: engine)
                    .padding(8)
                    .crtScreen(
                        enabled: settings.crtEnabled,
                        shake: CGSize(
                            width: CGFloat(engine.shake * sin(engine.elapsed * 47) * 6),
                            height: CGFloat(engine.shake * cos(engine.elapsed * 53) * 5)
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: settings.crtEnabled ? 10 : 6)
                            .stroke(palette.gold.opacity(0.3), lineWidth: 1)
                            .padding(8)
                    )

                overlayMessages
            }
            footerBar
        }
    }

    private var hudBar: some View {
        HStack(spacing: 14) {
            Text("PACHINKO")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(palette.gold)
                .shadow(color: palette.gold.opacity(0.5), radius: 6)

            Text(engine.board.theme.shortName)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(palette.void)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(palette.hud)
                .clipShape(RoundedRectangle(cornerRadius: 2))

            Text(engine.difficulty.shortName)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(palette.hud.opacity(0.85))

            if engine.fever {
                let throb = 0.72 + 0.28 * sin(engine.elapsed * (engine.attackerOpen ? 14 : 6))
                Text(engine.attackerOpen ? "ATTACK \(engine.feverRoundsLeft)" : "FEVER \(engine.feverRoundsLeft)")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(palette.void)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(palette.fever.opacity(throb))
                    .shadow(color: palette.fever.opacity(0.8), radius: engine.attackerOpen ? 10 : 4)
            }

            Spacer()

            hudStat("SCORE", "\(engine.score)", palette.gold)
            hudStat("HI", "\(engine.highScore)", palette.hudDim)
            hudStat("TRAY", "\(max(engine.tray, 0))", palette.insertA)
            hudStat("PAY", "\(engine.paidOut)", palette.hud)
            hudStat("IN PLAY", "\(engine.inPlay)", palette.hud)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(palette.panel)
        .overlay(alignment: .bottom) {
            Rectangle().fill(palette.gold.opacity(0.3)).frame(height: 1)
        }
    }

    private var dmdBar: some View {
        HStack(spacing: 18) {
            reelGlyph(0)
            reelGlyph(1)
            reelGlyph(2)
            Text(engine.dmdLine)
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundStyle(engine.fever ? palette.fever : palette.insertA)
                .shadow(color: palette.glow.opacity(0.6), radius: 8)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.85))
        .overlay(alignment: .bottom) {
            Rectangle().fill(palette.hud.opacity(0.25)).frame(height: 1)
        }
    }

    private func reelGlyph(_ i: Int) -> some View {
        let reel = engine.reels[i]
        let text = reel.spinning ? "◎" : reel.display.shortGlyph
        return Text(text)
            .font(.system(size: 18, weight: .black, design: .monospaced))
            .foregroundStyle(engine.reach && i == 2 ? palette.fever : palette.gold)
            .frame(width: 48, height: 28)
            .background(RoundedRectangle(cornerRadius: 3).fill(Color.black))
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(palette.gold.opacity(0.5), lineWidth: 1))
    }

    private func hudStat(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(palette.hudDim)
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
        }
    }

    private var footerBar: some View {
        HStack(spacing: 16) {
            Text("HANDLE")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(palette.hudDim)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(palette.void)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(palette.gold)
                        .frame(width: geo.size.width * engine.handlePower)
                    // sweet-spot marker
                    Rectangle()
                        .fill(palette.insertA.opacity(0.9))
                        .frame(width: 2)
                        .offset(x: geo.size.width * 0.60)
                }
            }
            .frame(height: 10)

            Text("\(Int(engine.handlePower * 100))%")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(palette.gold)
                .frame(width: 44, alignment: .trailing)

            Spacer()

            Text(engine.firing ? "FIRING" : "HOLD SPACE TO FIRE")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(engine.firing ? palette.fever : palette.hudDim)

            Text("P PAUSE  ·  ESC MENU")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(palette.hudDim.opacity(0.8))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(palette.panel)
        .overlay(alignment: .top) {
            Rectangle().fill(palette.gold.opacity(0.3)).frame(height: 1)
        }
    }

    @ViewBuilder
    private var overlayMessages: some View {
        if engine.phase == .paused {
            banner(title: "PAUSE", subtitle: "P TO RESUME  ·  ESC MENU")
        } else if engine.phase == .gameOver {
            banner(title: "GAME OVER", subtitle: "PAYOUT \(engine.paidOut)   SCORE \(engine.score)")
        } else if engine.phase == .enteringScore {
            initialsPanel
        } else if !engine.message.isEmpty && engine.phase == .playing {
            Text(engine.message)
                .font(.system(size: 28, weight: .black, design: .monospaced))
                .foregroundStyle(engine.fever ? palette.fever : palette.gold)
                .shadow(color: palette.gold.opacity(0.7), radius: 16)
                .allowsHitTesting(false)
        }
    }

    private var initialsPanel: some View {
        VStack(spacing: 16) {
            Text("HIGH SCORE  #\(engine.pendingScoreRank)")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(palette.gold)
            Text("\(engine.score)")
                .font(.system(size: 28, weight: .black, design: .monospaced))
                .foregroundStyle(palette.insertA)
            HStack(spacing: 10) {
                ForEach(0..<3, id: \.self) { i in
                    Text(String(engine.pendingInitials[i]))
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .foregroundStyle(i == engine.initialsCursor ? palette.void : palette.gold)
                        .frame(width: 44, height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(i == engine.initialsCursor ? palette.gold : palette.panel)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(palette.gold.opacity(0.6), lineWidth: 1.5)
                                )
                        )
                }
            }
            Text("↑↓ / LETTERS  ·  ←→ SELECT  ·  ENTER CONFIRM")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(palette.hudDim)
        }
        .padding(36)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(palette.panel.opacity(0.94))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(palette.gold.opacity(0.55), lineWidth: 1.5)
                )
        )
    }

    private func banner(title: String, subtitle: String, accent: Color? = nil) -> some View {
        let accent = accent ?? palette.gold
        return VStack(spacing: 14) {
            Text(title)
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .foregroundStyle(accent)
                .multilineTextAlignment(.center)
                .shadow(color: accent.opacity(0.6), radius: 12)
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(PachinkoTheme.monoHUD)
                    .foregroundStyle(palette.text.opacity(0.85))
            }
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(palette.panel.opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(accent.opacity(0.6), lineWidth: 1.5)
                )
                .shadow(color: accent.opacity(0.25), radius: 20)
        )
    }
}

struct KeyEventHandler: NSViewRepresentable {
    @ObservedObject var engine: GameEngine

    func makeNSView(context: Context) -> KeyCatcherView {
        let v = KeyCatcherView()
        v.engine = engine
        DispatchQueue.main.async { v.window?.makeFirstResponder(v) }
        return v
    }

    func updateNSView(_ nsView: KeyCatcherView, context: Context) {
        nsView.engine = engine
        guard nsView.window?.isKeyWindow == true, NSApp.modalWindow == nil else { return }
        if nsView.window?.firstResponder !== nsView {
            DispatchQueue.main.async {
                guard nsView.window?.isKeyWindow == true, NSApp.modalWindow == nil else { return }
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }
}

final class KeyCatcherView: NSView {
    weak var engine: GameEngine?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.contains(.command) {
            super.keyDown(with: event)
            return
        }
        if event.isARepeat && !Self.isHeld(event) { return }
        let key = Self.mapKey(event)
        let repeated = event.isARepeat
        Task { @MainActor in
            // Holding Space to fire also repeats. That repeat must not cancel Pause.
            if repeated, engine?.phase == .paused, key == " " || key == "return" { return }
            if engine?.phase == .enteringScore {
                engine?.handleKeyDown(key)
                return
            }
            switch key {
            case "t":
                if engine?.showsMenuUI == true {
                    DisplaySettings.shared.cycleCabinet()
                    engine?.applySelectedTable()
                }
            case "c":
                DisplaySettings.shared.toggleCRT()
            case "m":
                if event.modifierFlags.contains(.command) { break }
                DisplaySettings.shared.toggleMusic()
            default:
                engine?.handleKeyDown(key)
            }
        }
    }

    override func keyUp(with event: NSEvent) {
        let key = Self.mapKey(event)
        Task { @MainActor in
            engine?.handleKeyUp(key)
        }
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // Command shortcuts belong to the menus: Minimize, full screen, sound.
        if event.modifierFlags.contains(.command) {
            return super.performKeyEquivalent(with: event)
        }
        if Self.isGameKey(event) {
            keyDown(with: event)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    static func isHeld(_ event: NSEvent) -> Bool {
        switch event.keyCode {
        case 123, 124, 125, 126, 0, 2, 1, 13, 49: return true
        default: return false
        }
    }

    static func isGameKey(_ event: NSEvent) -> Bool {
        switch event.keyCode {
        case 123, 124, 125, 126, 49, 53, 36, 76, 0, 1, 2, 13, 17, 8, 46, 18, 19, 20, 35:
            return true
        default:
            return false
        }
    }

    static func mapKey(_ event: NSEvent) -> String {
        switch event.keyCode {
        case 126: return "uparrow"
        case 125: return "downarrow"
        case 123: return "leftarrow"
        case 124: return "rightarrow"
        case 53: return "escape"
        case 36, 76: return "return"
        case 49: return " "
        case 35: return "p"
        case 13: return "w"
        case 1: return "s"
        case 0: return "a"
        case 2: return "d"
        case 17: return "t"
        case 8: return "c"
        case 46: return "m"
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        default:
            return event.charactersIgnoringModifiers?.lowercased() ?? ""
        }
    }
}
