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

                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
                    spacing: 8
                ) {
                    ForEach(CabinetTheme.allCases) { theme in
                        cabinetCard(theme)
                    }
                }
                .padding(.horizontal, 8)

                HStack(spacing: 8) {
                    Text("DIFFICULTY")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(palette.hudDim)
                    ForEach(Difficulty.allCases) { diff in
                        Button {
                            settings.difficulty = diff
                            engine.difficulty = diff
                            GameSound.shared.uiClick()
                        } label: {
                            Text(diff.shortName)
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(settings.difficulty == diff ? palette.void : palette.gold)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
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
                    Text("1 · 2 · 3")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(palette.hudDim.opacity(0.7))
                }

                VStack(alignment: .leading, spacing: 5) {
                    controlRow("HOLD SPACE / CLICK", "Fire balls  ·  handle sets the drop line")
                    controlRow("← →  or  A D", "Handle power. Classic boards favor the middle")
                    controlRow("T / C / M    P / ESC", "Cabinet  ·  CRT  ·  Music    Pause")
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

                HStack(spacing: 12) {
                    toggleChip(title: settings.crtEnabled ? "CRT ON" : "CRT OFF", active: settings.crtEnabled) {
                        settings.toggleCRT()
                    }
                    toggleChip(title: settings.musicEnabled ? "MUSIC ON" : "MUSIC OFF", active: settings.musicEnabled) {
                        settings.toggleMusic()
                    }
                    toggleChip(title: sound.enabled ? "SFX ON" : "SFX OFF", active: sound.enabled) {
                        sound.toggle()
                    }
                }

                highScorePanel

                Text("PRESS ENTER / SPACE — START")
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundStyle(palette.void)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(palette.gold)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                    .shadow(color: palette.gold.opacity(0.45), radius: 12)

                Spacer().frame(height: 10)
            }
            .padding(.horizontal, 20)
            }
        }
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

    private func toggleChip(title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(active ? palette.void : palette.hud)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 3).fill(active ? palette.gold : palette.panel))
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(palette.gold.opacity(0.45), lineWidth: 1))
        }
        .buttonStyle(.plain)
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
