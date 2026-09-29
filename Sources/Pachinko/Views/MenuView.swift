import SwiftUI

struct MenuView: View {
    @ObservedObject var engine: GameEngine
    @ObservedObject private var settings = DisplaySettings.shared
    @ObservedObject private var sound = GameSound.shared
    @ObservedObject private var scores = HighScoreStore.shared

    private var palette: ColorPalette { settings.palette }

    var body: some View {
        ZStack {
            GameCanvasView(engine: engine)
                .crtScreen(enabled: settings.crtEnabled)

            VStack(spacing: 0) {
                LinearGradient(
                    colors: [palette.void.opacity(0.94), palette.void.opacity(0.4), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 200)
                Spacer()
                LinearGradient(
                    colors: [.clear, palette.void.opacity(0.55), palette.void.opacity(0.97)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 380)
            }
            .allowsHitTesting(false)

            ScrollView {
            VStack(spacing: 12) {
                Spacer().frame(height: 14)

                VStack(spacing: 6) {
                    Text("PACHINKO")
                        .font(PachinkoTheme.monoTitle)
                        .foregroundStyle(palette.gold)
                        .shadow(color: palette.gold.opacity(0.7), radius: 16)
                    Text("HANABI FEVER  PARLOR")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(palette.hud)
                        .tracking(4)
                }

                if engine.isAttractMode {
                    Text("DEMO")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(palette.void)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(palette.gold)
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                }

                if engine.showingSettings {
                    settingsPanel
                } else {
                    parlorPicker
                }

                if !engine.showingSettings {
                    VStack(alignment: .leading, spacing: 5) {
                        controlRow("HOLD SPACE / CLICK", "Fire balls  ·  handle sets the drop line")
                        controlRow("← →  or  A D", "Handle power. Classic boards favor the middle")
                        controlRow("T    P / ESC", "Cabinet    Pause / menu")
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(palette.panel.opacity(0.82))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(palette.gold.opacity(0.35), lineWidth: 1)
                            )
                    )

                    highScorePanel

                    Button {
                        engine.showingSettings = true
                        GameSound.shared.uiClick()
                    } label: {
                        Text("SETTINGS")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(palette.gold)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 3)
                                    .stroke(palette.gold.opacity(0.7), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)

                    Text(settingsSummary)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(palette.hudDim)

                    Button {
                        engine.startGame()
                    } label: {
                        Text("PRESS ENTER / SPACE — START")
                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                            .foregroundStyle(palette.void)
                            .padding(.horizontal, 28)
                            .padding(.vertical, 12)
                            .background(palette.gold)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                            .shadow(color: palette.gold.opacity(0.45), radius: 12)
                    }
                    .buttonStyle(.plain)

                    Spacer().frame(height: 10)
                }
            }
            .padding(.horizontal, 20)
            }
        }
    }

    private var parlorPicker: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
            spacing: 8
        ) {
            ForEach(CabinetTheme.allCases) { theme in
                cabinetCard(theme)
            }
        }
        .padding(.horizontal, 8)
    }

    private var settingsSummary: String {
        let crt = settings.crtEnabled ? "CRT ON" : "CRT OFF"
        let music = settings.musicEnabled ? "MUSIC ON" : "MUSIC OFF"
        let sfx = sound.enabled ? "SFX ON" : "SFX OFF"
        let wear = settings.wearEnabled ? "WEAR ON" : "WEAR OFF"
        let screen = settings.windowMode == .fullScreen ? "FULL SCREEN" : "WINDOW"
        return "\(screen)  ·  \(settings.difficulty.shortName)  ·  \(crt)  ·  \(music)  ·  \(sfx)  ·  \(wear)"
    }

    private var settingsPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("SETTINGS")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(palette.gold)
                .tracking(3)

            VStack(alignment: .leading, spacing: 8) {
                Text("SCREEN")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(palette.hudDim)
                HStack(spacing: 8) {
                    screenModeButton("WINDOW", mode: .window)
                    screenModeButton("FULL SCREEN", mode: .fullScreen)
                }
                Text("Full screen fills this display. Command-F does the same.")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(palette.text.opacity(0.8))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("DIFFICULTY")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(palette.hudDim)
                HStack(spacing: 8) {
                    ForEach(Difficulty.allCases) { diff in
                        Button {
                            settings.difficulty = diff
                            engine.difficulty = diff
                            GameSound.shared.uiClick()
                        } label: {
                            Text(diff.shortName)
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(settings.difficulty == diff ? palette.void : palette.gold)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(settings.difficulty == diff ? palette.gold : palette.panel.opacity(0.85))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 3)
                                                .stroke(palette.gold.opacity(0.5), lineWidth: 1)
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                Text(settings.difficulty.settingsBlurb)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(palette.text.opacity(0.8))
                Text("Keys 1 · 2 · 3")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(palette.hudDim.opacity(0.7))
            }

            settingsToggle(
                title: "CRT GLASS",
                detail: "Scanlines and vignette over the board",
                on: settings.crtEnabled,
                key: "C"
            ) {
                settings.toggleCRT()
            }
            settingsToggle(
                title: "MUSIC",
                detail: "Cabinet tune and Fever track",
                on: settings.musicEnabled,
                key: "M"
            ) {
                settings.toggleMusic()
            }
            settingsToggle(
                title: "SOUND EFFECTS",
                detail: "Nails, pockets, reels, and the launcher",
                on: sound.enabled,
                key: ""
            ) {
                sound.toggle()
            }
            settingsToggle(
                title: "CABINET WEAR",
                detail: "Scratches on the frame, and a slow drift in the wheel",
                on: settings.wearEnabled,
                key: ""
            ) {
                settings.toggleWear()
                engine.applyWearPresentation()
                engine.confirmWearReset = false
            }

            Button {
                if engine.confirmWearReset {
                    engine.resetCabinetWear()
                    engine.confirmWearReset = false
                    GameSound.shared.uiClick()
                } else {
                    engine.confirmWearReset = true
                    GameSound.shared.uiClick()
                }
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Text(engine.confirmWearReset ? "CONFIRM RESET" : "RESET WEAR")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(engine.confirmWearReset ? palette.void : palette.gold)
                    Text("Clears the marks and wheel drift on every cabinet")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(engine.confirmWearReset ? palette.void.opacity(0.8) : palette.hudDim)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(engine.confirmWearReset ? palette.danger : palette.panel)
                        .overlay(RoundedRectangle(cornerRadius: 3).stroke(palette.gold.opacity(0.45), lineWidth: 1))
                )
            }
            .buttonStyle(.plain)

            Button {
                engine.showingSettings = false
                engine.confirmWearReset = false
                GameSound.shared.uiClick()
            } label: {
                Text("DONE  ·  ESC")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(palette.void)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(palette.gold)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(16)
        .frame(maxWidth: 520, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(palette.panel.opacity(0.94))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(palette.gold.opacity(0.45), lineWidth: 1)
                )
        )
    }

    private func screenModeButton(_ title: String, mode: WindowMode) -> some View {
        let selected = settings.windowMode == mode
        return Button {
            settings.selectWindowMode(mode)
        } label: {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(selected ? palette.void : palette.gold)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(selected ? palette.gold : palette.panel.opacity(0.85))
                        .overlay(
                            RoundedRectangle(cornerRadius: 3)
                                .stroke(palette.gold.opacity(0.5), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private func settingsToggle(title: String, detail: String, on: Bool, key: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(palette.text)
                    Text(detail)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(palette.hudDim)
                }
                Spacer(minLength: 12)
                if !key.isEmpty {
                    Text(key)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(palette.hudDim)
                }
                Text(on ? "ON" : "OFF")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(on ? palette.void : palette.gold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(on ? palette.gold : palette.panel)
                            .overlay(RoundedRectangle(cornerRadius: 3).stroke(palette.gold.opacity(0.45), lineWidth: 1))
                    )
            }
        }
        .buttonStyle(.plain)
    }

    private func cabinetCard(_ theme: CabinetTheme) -> some View {
        let selected = settings.cabinetTheme == theme
        let pal = ColorPalette.make(theme: theme)
        return Button {
            settings.cabinetTheme = theme
            engine.applySelectedTable()
            GameSound.shared.uiClick()
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Circle().fill(pal.insertA).frame(width: 8, height: 8)
                    Circle().fill(pal.insertB).frame(width: 8, height: 8)
                    Circle().fill(pal.gold).frame(width: 8, height: 8)
                    Spacer()
                    Text(theme.machineName)
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(pal.gold.opacity(0.8))
                }
                Text(theme.shortName)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(selected ? pal.goldHi : pal.text)
                Text(theme.tagline)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(pal.hudDim)
                    .lineLimit(2)
                    .frame(minHeight: 24, alignment: .topLeading)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(pal.panel.opacity(selected ? 0.95 : 0.72))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(selected ? pal.gold : pal.gold.opacity(0.25), lineWidth: selected ? 2 : 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func controlRow(_ keys: String, _ desc: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(keys)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(palette.gold)
                .frame(width: 168, alignment: .leading)
            Text(desc)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(palette.text.opacity(0.8))
        }
    }

    private var highScorePanel: some View {
        let rows = Array(scores.entries.prefix(5))
        return VStack(alignment: .leading, spacing: 4) {
            Text("TOP SCORES")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(palette.hudDim)
            if rows.isEmpty {
                Text("NO SCORES YET")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(palette.hudDim.opacity(0.7))
            } else {
                ForEach(Array(rows.enumerated()), id: \.element.id) { idx, row in
                    HStack(spacing: 8) {
                        Text(String(format: "%2d", idx + 1))
                            .foregroundStyle(palette.hudDim)
                            .frame(width: 22, alignment: .trailing)
                        Text(row.initials)
                            .foregroundStyle(palette.gold)
                            .frame(width: 36, alignment: .leading)
                        Text("\(row.score)")
                            .foregroundStyle(palette.insertA)
                            .frame(minWidth: 64, alignment: .trailing)
                        Text(row.table)
                            .foregroundStyle(palette.hud.opacity(0.85))
                        Text(row.difficulty)
                            .foregroundStyle(palette.hudDim)
                    }
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                }
            }
        }
        .padding(12)
        .frame(maxWidth: 520)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(palette.panel.opacity(0.88))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(palette.gold.opacity(0.25)))
        )
    }
}
