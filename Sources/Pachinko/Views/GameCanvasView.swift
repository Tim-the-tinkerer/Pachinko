import SwiftUI

struct TableLayoutScale {
    let origin: CGPoint
    let scale: CGFloat

    init(size: CGSize) {
        let sx = size.width / BoardDef.width
        let sy = size.height / BoardDef.height
        scale = min(sx, sy)
        origin = CGPoint(
            x: (size.width - BoardDef.width * scale) / 2,
            y: (size.height - BoardDef.height * scale) / 2
        )
    }

    func p(_ v: Vec) -> CGPoint {
        guard v.x.isFinite, v.y.isFinite, scale.isFinite else { return origin }
        return CGPoint(x: origin.x + v.x * scale, y: origin.y + v.y * scale)
    }

    func s(_ n: Double) -> CGFloat { n * scale }

    func rect(_ c: Vec, r: Double) -> CGRect {
        let pt = p(c)
        let rad = s(r)
        return CGRect(x: pt.x - rad, y: pt.y - rad, width: rad * 2, height: rad * 2)
    }
}

struct GameCanvasView: View {
    @ObservedObject var engine: GameEngine

    private var palette: ColorPalette { ColorPalette.make(theme: engine.board.theme) }

    var body: some View {
        GeometryReader { geo in
            let L = TableLayoutScale(size: geo.size)
            Canvas { context, size in
                let L = TableLayoutScale(size: size)
                drawCabinet(context: &context, L: L, size: size)
                drawPlayfield(context: &context, L: L)
                drawThemeArt(context: &context, L: L)
                drawReels(context: &context, L: L)
                drawWalls(context: &context, L: L)
                drawPockets(context: &context, L: L)
                drawWindmill(context: &context, L: L)
                drawNails(context: &context, L: L)
                drawRail(context: &context, L: L)
                drawBalls(context: &context, L: L)
                drawGlassSheen(context: &context, L: L)
                drawHandle(context: &context, L: L)
                drawParticles(context: &context, L: L)
            }
            .background(palette.void)
            // Labels stay outside the canvas. Resolving Text inside it every frame
            // crashes SwiftUI's drawing view (bad release of the previous drawable).
            .overlay {
                boardLabels(L)
                    .allowsHitTesting(false)
            }
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if engine.showsMenuUI { return }
                    engine.updateHandleDrag(translation: Double(value.translation.height))
                }
                .onEnded { _ in
                    engine.endHandleDrag()
                }
        )
    }

    // MARK: - Cabinet

    private func drawCabinet(context: inout GraphicsContext, L: TableLayoutScale, size: CGSize) {
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(palette.void))
        let field = CGRect(
            x: L.origin.x - L.s(18),
            y: L.origin.y - L.s(18),
            width: L.s(BoardDef.width) + L.s(36),
            height: L.s(BoardDef.height) + L.s(36)
        )
        let wood = Path(roundedRect: field, cornerRadius: L.s(22))
        context.fill(wood, with: .color(palette.lacquer))
        context.stroke(wood, with: .color(palette.gold.opacity(0.55)), lineWidth: max(2, L.s(3)))
        let inner = Path(roundedRect: field.insetBy(dx: L.s(6), dy: L.s(6)), cornerRadius: L.s(16))
        context.stroke(inner, with: .color(palette.goldHi.opacity(0.25)), lineWidth: 1)

        let marquee = CGRect(
            x: field.minX + L.s(24),
            y: field.minY + L.s(4),
            width: field.width - L.s(48),
            height: L.s(16)
        )
        context.fill(Path(roundedRect: marquee, cornerRadius: 4), with: .color(palette.gold.opacity(0.15)))
        drawMarqueeLamps(context: &context, L: L, marquee: marquee)
        drawSideLamps(context: &context, L: L, frame: field)
        drawCabinetWear(context: &context, L: L, frame: field)
        drawPayoutFlap(context: &context, L: L, frame: field)
    }

    private func drawSideLamps(context: inout GraphicsContext, L: TableLayoutScale, frame: CGRect) {
        let count = 9
        for i in 0..<count {
            let v = CGFloat(i + 1) / CGFloat(count + 1)
            let y = frame.minY + v * frame.height
            let phase = engine.elapsed * (engine.fever ? 7 : 1.3) + Double(i) * 0.7
            let glow = engine.fever
                ? 0.35 + 0.65 * max(0, sin(phase))
                : 0.18 + 0.22 * sin(phase)
            let color = (engine.fever && engine.attackerOpen) ? palette.fever : palette.insertC
            for x in [frame.minX + L.s(8), frame.maxX - L.s(8)] {
                let sway = engine.isAttractMode ? sin(engine.elapsed * 1.4 + Double(i)) * L.s(1.2) : 0
                context.fill(
                    Path(ellipseIn: CGRect(x: x - L.s(2.4) + sway, y: y - L.s(2.4), width: L.s(4.8), height: L.s(4.8))),
                    with: .color(color.opacity(glow))
                )
            }
        }
    }

    private func drawCabinetWear(context: inout GraphicsContext, L: TableLayoutScale, frame: CGRect) {
        guard DisplaySettings.shared.wearEnabled else { return }
        let wear = 0.28 + engine.cabinetWear * 0.72
        let seed = engine.board.theme.rawValue.unicodeScalars.reduce(0.0) { $0 + Double($1.value) }
        for i in 0..<6 {
            let u = wearUnit(i, seed)
            let v = wearUnit(i + 3, seed)
            let len = 10.0 + wearUnit(i + 6, seed) * 22
            let x = frame.minX + L.s(16) + u * (frame.width - L.s(32))
            let y = frame.minY + L.s(28) + v * (frame.height * 0.72)
            var scratch = Path()
            scratch.move(to: CGPoint(x: x, y: y))
            scratch.addLine(to: CGPoint(x: x + L.s(len), y: y + L.s(len * 0.18)))
            context.stroke(scratch, with: .color(palette.goldHi.opacity(0.045 * wear)), lineWidth: 1)
        }
        let dull = CGRect(
            x: frame.maxX - L.s(36),
            y: frame.maxY - L.s(48),
            width: L.s(18),
            height: L.s(10)
        )
        context.fill(Path(roundedRect: dull, cornerRadius: 2), with: .color(Color.black.opacity(0.08 * wear)))
    }

    private func wearUnit(_ i: Int, _ seed: Double) -> CGFloat {
        let x = sin(Double(i) * 12.9898 + seed * 0.017) * 43758.5453
        return CGFloat(x - floor(x))
    }

    private func drawPayoutFlap(context: inout GraphicsContext, L: TableLayoutScale, frame: CGRect) {
        let flash = engine.board.pockets.map(\.flash).max() ?? 0
        let open = min(8, flash * 6)
        let flap = CGRect(
            x: frame.midX - L.s(16),
            y: frame.maxY - L.s(14) - L.s(open),
            width: L.s(32),
            height: L.s(6)
        )
        context.fill(Path(roundedRect: flap, cornerRadius: 1), with: .color(palette.gold.opacity(0.35 + flash * 0.4)))
    }

    private func drawGlassSheen(context: inout GraphicsContext, L: TableLayoutScale) {
        let field = CGRect(
            x: L.origin.x + L.s(BoardDef.playLeft - 8),
            y: L.origin.y + L.s(12),
            width: L.s(BoardDef.playRight - BoardDef.playLeft + 16),
            height: L.s(BoardDef.height - 20)
        )
        var glass = context
        glass.clip(to: Path(roundedRect: field, cornerRadius: L.s(10)))
        let travel = engine.elapsed * 0.045
        let shift = travel - floor(travel)
        let y = field.minY - L.s(30) + shift * (field.height + L.s(60))
        let band = CGRect(x: field.minX, y: y, width: field.width, height: L.s(22))
        glass.fill(
            Path(band),
            with: .linearGradient(
                Gradient(colors: [.clear, Color.white.opacity(0.055), .clear]),
                startPoint: CGPoint(x: band.midX, y: band.minY),
                endPoint: CGPoint(x: band.midX, y: band.maxY)
            )
        )
    }

    private func drawMarqueeLamps(context: inout GraphicsContext, L: TableLayoutScale, marquee: CGRect) {
        let count = 14
        let fever = engine.fever
        let speed = fever ? 9.0 : 1.6
        for i in 0..<count {
            let u = CGFloat(i) / CGFloat(count - 1)
            let x = marquee.minX + u * marquee.width
            let phase = engine.elapsed * speed - Double(i) * 0.45
            let lamp = fever ? (0.45 + 0.55 * max(0, sin(phase))) : (0.25 + 0.2 * sin(phase))
            let color = fever && engine.attackerOpen ? palette.fever : palette.gold
            context.fill(
                Path(ellipseIn: CGRect(x: x - L.s(3.2), y: marquee.midY - L.s(3.2), width: L.s(6.4), height: L.s(6.4))),
                with: .color(color.opacity(lamp))
            )
        }
    }

    private func drawPlayfield(context: inout GraphicsContext, L: TableLayoutScale) {
        let field = CGRect(
            x: L.origin.x + L.s(BoardDef.playLeft - 8),
            y: L.origin.y + L.s(12),
            width: L.s(BoardDef.playRight - BoardDef.playLeft + 16),
            height: L.s(BoardDef.height - 20)
        )
        let g = Gradient(colors: [palette.playfield, palette.playfieldAlt, palette.playfield])
        context.fill(
            Path(roundedRect: field, cornerRadius: L.s(10)),
            with: .linearGradient(g, startPoint: CGPoint(x: field.minX, y: field.minY), endPoint: CGPoint(x: field.maxX, y: field.maxY))
        )
        drawThemeWash(context: &context, L: L, field: field)
        if engine.fever {
            let open = engine.attackerOpen
            let pulse = open
                ? 0.20 + 0.14 * sin(engine.elapsed * 16)
                : 0.07 + 0.04 * sin(engine.elapsed * 5)
            context.fill(
                Path(roundedRect: field, cornerRadius: L.s(10)),
                with: .color(palette.fever.opacity(pulse))
            )
            if open {
                context.stroke(
                    Path(roundedRect: field.insetBy(dx: L.s(3), dy: L.s(3)), cornerRadius: L.s(8)),
                    with: .color(palette.fever.opacity(0.35 + 0.35 * sin(engine.elapsed * 16))),
                    lineWidth: L.s(3)
                )
            }
        }
    }

    private func drawThemeWash(context: inout GraphicsContext, L: TableLayoutScale, field: CGRect) {
        let shape = Path(roundedRect: field, cornerRadius: L.s(10))
        switch engine.board.theme {
        case .sakura:
            context.fill(
                shape,
                with: .linearGradient(
                    Gradient(colors: [palette.insertA.opacity(0.22), .clear, palette.playfieldAlt.opacity(0.15)]),
                    startPoint: CGPoint(x: field.midX, y: field.minY),
                    endPoint: CGPoint(x: field.midX, y: field.midY)
                )
            )
        case .dragon:
            context.fill(
                shape,
                with: .radialGradient(
                    Gradient(colors: [palette.insertC.opacity(0.28), palette.gold.opacity(0.08), .clear]),
                    center: CGPoint(x: field.maxX - L.s(70), y: field.minY + L.s(220)),
                    startRadius: L.s(10),
                    endRadius: L.s(280)
                )
            )
        case .neon:
            context.fill(
                shape,
                with: .linearGradient(
                    Gradient(colors: [palette.insertB.opacity(0.20), .clear, palette.insertA.opacity(0.16)]),
                    startPoint: CGPoint(x: field.minX, y: field.minY),
                    endPoint: CGPoint(x: field.maxX, y: field.maxY)
                )
            )
        case .koi:
            context.fill(
                shape,
                with: .linearGradient(
                    Gradient(colors: [palette.insertB.opacity(0.20), .clear, palette.playfield.opacity(0.35)]),
                    startPoint: CGPoint(x: field.midX, y: field.minY),
                    endPoint: CGPoint(x: field.midX, y: field.maxY)
                )
            )
        case .lantern:
            context.fill(
                shape,
                with: .radialGradient(
                    Gradient(colors: [palette.gold.opacity(0.18), .clear]),
                    center: CGPoint(x: field.midX, y: field.minY + L.s(80)),
                    startRadius: L.s(8),
                    endRadius: L.s(220)
                )
            )
        case .river:
            context.fill(
                shape,
                with: .linearGradient(
                    Gradient(colors: [palette.insertA.opacity(0.16), .clear, palette.void.opacity(0.35)]),
                    startPoint: CGPoint(x: field.midX, y: field.minY),
                    endPoint: CGPoint(x: field.midX, y: field.maxY)
                )
            )
        }
    }

    private func drawThemeArt(context: inout GraphicsContext, L: TableLayoutScale) {
        switch engine.board.theme {
        case .sakura:
            drawSakuraArt(context: &context, L: L)
        case .dragon:
            drawDragonArt(context: &context, L: L)
        case .neon:
            drawNeonArt(context: &context, L: L)
        case .koi:
            drawKoiArt(context: &context, L: L)
        case .lantern:
            drawLanternArt(context: &context, L: L)
        case .river:
            drawRiverArt(context: &context, L: L)
        }
    }

    private func drawSakuraArt(context: inout GraphicsContext, L: TableLayoutScale) {
        context.fill(
            Path(ellipseIn: L.rect(Vec(x: 300, y: 70), r: 22)),
            with: .color(palette.goldHi.opacity(0.10))
        )
        for i in 0..<6 {
            let cx = 48.0 + Double(i) * 52
            var branch = Path()
            branch.move(to: L.p(Vec(x: cx, y: 28)))
            branch.addQuadCurve(to: L.p(Vec(x: cx + 14, y: 110)), control: L.p(Vec(x: cx - 22, y: 60)))
            context.stroke(branch, with: .color(palette.insertA.opacity(0.28)), lineWidth: L.s(2))
            context.fill(
                Path(ellipseIn: L.rect(Vec(x: cx + 8, y: 78), r: 5)),
                with: .color(palette.insertA.opacity(0.35))
            )
            context.fill(
                Path(ellipseIn: L.rect(Vec(x: cx - 6, y: 96), r: 3.5)),
                with: .color(palette.goldHi.opacity(0.30))
            )
        }
        context.stroke(
            Path(ellipseIn: L.rect(Vec(x: 186, y: 250), r: 78)),
            with: .color(palette.insertA.opacity(0.16)),
            lineWidth: 1.5
        )
    }

    private func drawDragonArt(context: inout GraphicsContext, L: TableLayoutScale) {
        var coil = Path()
        coil.move(to: L.p(Vec(x: 48, y: 140)))
        coil.addCurve(
            to: L.p(Vec(x: 250, y: 214)),
            control1: L.p(Vec(x: 40, y: 40)),
            control2: L.p(Vec(x: 160, y: 90))
        )
        coil.addCurve(
            to: L.p(Vec(x: 300, y: 460)),
            control1: L.p(Vec(x: 340, y: 250)),
            control2: L.p(Vec(x: 210, y: 360))
        )
        context.stroke(coil, with: .color(palette.gold.opacity(0.22)), lineWidth: L.s(11))
        context.stroke(coil, with: .color(palette.insertC.opacity(0.35)), lineWidth: L.s(2.2))
        for i in 0..<5 {
            let y = 150.0 + Double(i) * 62
            var scale = Path()
            scale.addArc(
                center: L.p(Vec(x: 300, y: y)),
                radius: L.s(16),
                startAngle: .degrees(200),
                endAngle: .degrees(20),
                clockwise: false
            )
            context.stroke(scale, with: .color(palette.goldHi.opacity(0.28)), lineWidth: 1.4)
        }
        context.fill(Path(ellipseIn: L.rect(Vec(x: 262, y: 200), r: 6)), with: .color(palette.insertC.opacity(0.55)))
    }

    private func drawNeonArt(context: inout GraphicsContext, L: TableLayoutScale) {
        var grid = Path()
        for x in stride(from: 48.0, through: 320.0, by: 24) {
            grid.move(to: L.p(Vec(x: x, y: 36)))
            grid.addLine(to: L.p(Vec(x: x, y: 150)))
        }
        for y in stride(from: 48.0, through: 140.0, by: 26) {
            grid.move(to: L.p(Vec(x: 36, y: y)))
            grid.addLine(to: L.p(Vec(x: 330, y: y)))
        }
        context.stroke(grid, with: .color(palette.insertA.opacity(0.16)), lineWidth: 1)
        let blocks: [(Double, Double, Double)] = [(46, 520, 28), (86, 490, 46), (150, 530, 22), (210, 500, 38), (270, 540, 18), (310, 505, 30)]
        for block in blocks {
            var tower = Path()
            tower.move(to: L.p(Vec(x: block.0, y: 560)))
            tower.addLine(to: L.p(Vec(x: block.0, y: block.1)))
            tower.addLine(to: L.p(Vec(x: block.0 + block.2, y: block.1 - 8)))
            tower.addLine(to: L.p(Vec(x: block.0 + block.2, y: 560)))
            context.fill(tower, with: .color(palette.insertB.opacity(0.10)))
            context.stroke(tower, with: .color(palette.insertA.opacity(0.28)), lineWidth: 1)
        }
        context.stroke(
            Path(ellipseIn: L.rect(Vec(x: 112, y: 78), r: 26)),
            with: .color(palette.insertB.opacity(0.45)),
            lineWidth: 2
        )
        context.stroke(
            Path(ellipseIn: L.rect(Vec(x: 112, y: 78), r: 18)),
            with: .color(palette.insertA.opacity(0.35)),
            lineWidth: 1
        )
    }

    private func drawKoiArt(context: inout GraphicsContext, L: TableLayoutScale) {
        for i in 0..<4 {
            let r = 36.0 + Double(i) * 28
            context.stroke(
                Path(ellipseIn: L.rect(Vec(x: 186, y: 300), r: r)),
                with: .color(palette.insertB.opacity(0.10)),
                lineWidth: 1.2
            )
        }
        var fish = Path()
        fish.move(to: L.p(Vec(x: 70, y: 210)))
        fish.addQuadCurve(to: L.p(Vec(x: 150, y: 250)), control: L.p(Vec(x: 90, y: 160)))
        fish.addQuadCurve(to: L.p(Vec(x: 70, y: 210)), control: L.p(Vec(x: 120, y: 280)))
        context.stroke(fish, with: .color(palette.insertA.opacity(0.20)), lineWidth: L.s(1.6))
    }

    private func drawLanternArt(context: inout GraphicsContext, L: TableLayoutScale) {
        for i in 0..<5 {
            let y = 80.0 + Double(i) * 78
            for x in [36.0, 330.0] {
                context.fill(
                    Path(ellipseIn: L.rect(Vec(x: x, y: y), r: 7)),
                    with: .color(palette.insertA.opacity(0.22))
                )
                var cord = Path()
                cord.move(to: L.p(Vec(x: x, y: y - 16)))
                cord.addLine(to: L.p(Vec(x: x, y: y - 7)))
                context.stroke(cord, with: .color(palette.gold.opacity(0.25)), lineWidth: 1)
            }
        }
    }

    private func drawRiverArt(context: inout GraphicsContext, L: TableLayoutScale) {
        var left = Path()
        left.move(to: L.p(Vec(x: 70, y: 40)))
        left.addCurve(
            to: L.p(Vec(x: 90, y: 520)),
            control1: L.p(Vec(x: 130, y: 160)),
            control2: L.p(Vec(x: 40, y: 340))
        )
        var right = Path()
        right.move(to: L.p(Vec(x: 300, y: 40)))
        right.addCurve(
            to: L.p(Vec(x: 270, y: 520)),
            control1: L.p(Vec(x: 240, y: 180)),
            control2: L.p(Vec(x: 330, y: 360))
        )
        context.stroke(left, with: .color(palette.insertA.opacity(0.16)), lineWidth: L.s(8))
        context.stroke(right, with: .color(palette.insertB.opacity(0.12)), lineWidth: L.s(8))
    }

    // MARK: - Reels

    private func drawReels(context: inout GraphicsContext, L: TableLayoutScale) {
        let box = CGRect(
            x: L.p(Vec(x: 108, y: 52)).x,
            y: L.p(Vec(x: 108, y: 52)).y,
            width: L.s(156),
            height: L.s(44)
        )
        context.fill(Path(roundedRect: box, cornerRadius: 4), with: .color(Color.black.opacity(0.85)))
        context.stroke(Path(roundedRect: box, cornerRadius: 4), with: .color(palette.gold.opacity(0.65)), lineWidth: 1.5)

        let w = box.width / 3
        for i in 0..<3 {
            let cell = CGRect(x: box.minX + CGFloat(i) * w, y: box.minY, width: w, height: box.height)
            if i > 0 {
                var div = Path()
                div.move(to: CGPoint(x: cell.minX, y: cell.minY + 4))
                div.addLine(to: CGPoint(x: cell.minX, y: cell.maxY - 4))
                context.stroke(div, with: .color(palette.gold.opacity(0.35)), lineWidth: 1)
            }
        }
    }

    private func boardLabels(_ L: TableLayoutScale) -> some View {
        let box = CGRect(
            x: L.p(Vec(x: 108, y: 52)).x,
            y: L.p(Vec(x: 108, y: 52)).y,
            width: L.s(156),
            height: L.s(44)
        )
        let cellW = box.width / 3
        return ZStack {
            ForEach(0..<3, id: \.self) { i in
                let reel = engine.reels[i]
                let glow = engine.reach && i == 2 ? palette.fever : palette.insertB
                let symbol = reel.spinning ? spinGlyph(reel) : reel.display.shortGlyph
                Text(symbol)
                    .font(.system(size: L.s(16), weight: .black, design: .monospaced))
                    .foregroundStyle(glow)
                    .position(x: box.minX + cellW * (CGFloat(i) + 0.5), y: box.midY)
            }
            ForEach(Array(engine.floatScores.enumerated()), id: \.offset) { _, score in
                Text(score.text)
                    .font(.system(size: L.s(11), weight: .bold, design: .monospaced))
                    .foregroundStyle(palette.goldHi.opacity(score.life))
                    .position(L.p(score.pos))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func spinGlyph(_ reel: Reel) -> String {
        let symbols = ReelSymbol.allCases
        let idx = Int(reel.offset * 3) % symbols.count
        return symbols[abs(idx)].shortGlyph
    }

    // MARK: - Playfield bits

    private func drawWalls(context: inout GraphicsContext, L: TableLayoutScale) {
        var path = Path()
        for wall in engine.board.walls {
            path.move(to: L.p(wall.a))
            path.addLine(to: L.p(wall.b))
        }
        context.stroke(path, with: .color(palette.gold.opacity(0.55)), lineWidth: max(1.5, L.s(2.2)))

        if !engine.attackerOpen {
            var cover = Path()
            for wall in engine.board.coverWalls {
                cover.move(to: L.p(wall.a))
                cover.addLine(to: L.p(wall.b))
            }
            context.stroke(cover, with: .color(palette.nail.opacity(0.9)), lineWidth: max(2, L.s(3.5)))
        }
    }

    private func drawPockets(context: inout GraphicsContext, L: TableLayoutScale) {
        for pocket in engine.board.pockets where pocket.kind != .out {
            let lit = pocket.flash > 0 || (pocket.kind == .attacker && pocket.open)
            let color: Color = {
                switch pocket.kind {
                case .chucker: return palette.insertB
                case .tulip: return palette.insertA
                case .attacker: return palette.fever
                case .out: return palette.danger
                }
            }()
            let breathe = 0.55 + 0.45 * sin(engine.elapsed * 3 + pocket.pos.x * 0.02)
            let glowR = pocket.radius + 8 + pocket.flash * 22 + (lit ? 4 : 0)
            context.fill(
                Path(ellipseIn: L.rect(pocket.pos, r: glowR)),
                with: .radialGradient(
                    Gradient(colors: [
                        color.opacity(lit ? min(0.9, 0.35 + pocket.flash * 0.5) : 0.10 * breathe),
                        color.opacity(lit ? 0.22 : 0),
                        .clear,
                    ]),
                    center: L.p(pocket.pos),
                    startRadius: 0,
                    endRadius: L.s(glowR)
                )
            )
            if pocket.flash > 0.05 {
                let ring = pocket.radius + 10 + (1.35 - pocket.flash) * 16
                context.stroke(
                    Path(ellipseIn: L.rect(pocket.pos, r: ring)),
                    with: .color(color.opacity(pocket.flash * 0.85)),
                    lineWidth: L.s(2.2)
                )
                for ray in 0..<8 {
                    let ang = engine.elapsed * 2.2 + Double(ray) * .pi / 4
                    let inner = pocket.radius + 6
                    let outer = inner + 10 + pocket.flash * 14
                    var spoke = Path()
                    spoke.move(to: L.p(Vec(
                        x: pocket.pos.x + cos(ang) * inner,
                        y: pocket.pos.y + sin(ang) * inner
                    )))
                    spoke.addLine(to: L.p(Vec(
                        x: pocket.pos.x + cos(ang) * outer,
                        y: pocket.pos.y + sin(ang) * outer
                    )))
                    context.stroke(spoke, with: .color(color.opacity(pocket.flash * 0.7)), lineWidth: L.s(1.4))
                }
            }
            context.fill(Path(ellipseIn: L.rect(pocket.pos, r: pocket.radius)), with: .color(Color.black.opacity(0.75)))
            context.stroke(
                Path(ellipseIn: L.rect(pocket.pos, r: pocket.radius)),
                with: .color(color.opacity(pocket.open ? 0.95 : 0.35 + 0.15 * breathe)),
                lineWidth: max(1.2, L.s(1.8))
            )
            if pocket.kind == .attacker && pocket.open {
                context.stroke(
                    Path(ellipseIn: L.rect(pocket.pos, r: pocket.radius + 7 + 3 * sin(engine.elapsed * 10))),
                    with: .color(palette.fever.opacity(0.85)),
                    lineWidth: L.s(2.4)
                )
            }
        }

        // Out hole mouth
        var mouth = Path()
        mouth.move(to: L.p(Vec(x: 132, y: 650)))
        mouth.addLine(to: L.p(Vec(x: 240, y: 650)))
        mouth.addLine(to: L.p(Vec(x: 228, y: 710)))
        mouth.addLine(to: L.p(Vec(x: 144, y: 710)))
        mouth.closeSubpath()
        context.fill(mouth, with: .color(Color.black.opacity(0.72)))
        context.stroke(mouth, with: .color(palette.danger.opacity(0.45)), lineWidth: 1)
    }

    private func drawWindmill(context: inout GraphicsContext, L: TableLayoutScale) {
        let mill = engine.board.windmill
        let hubR = mill.thickness + 6
        context.stroke(
            Path(ellipseIn: L.rect(mill.pos, r: hubR + 3)),
            with: .color(palette.gold.opacity(0.45)),
            lineWidth: L.s(1.2)
        )
        for tooth in 0..<8 {
            let ang = -mill.angle * 0.65 + Double(tooth) * .pi / 4
            let a = Vec(x: mill.pos.x + cos(ang) * hubR, y: mill.pos.y + sin(ang) * hubR)
            let b = Vec(x: mill.pos.x + cos(ang) * (hubR + 3.2), y: mill.pos.y + sin(ang) * (hubR + 3.2))
            var tick = Path()
            tick.move(to: L.p(a))
            tick.addLine(to: L.p(b))
            context.stroke(tick, with: .color(palette.goldHi.opacity(0.7)), lineWidth: L.s(1.3))
        }
        context.fill(
            Path(ellipseIn: L.rect(mill.pos, r: mill.thickness + 3)),
            with: .color(palette.gold)
        )
        for arm in 0..<4 {
            let ang = mill.angle + Double(arm) * .pi / 2
            let tip = Vec(x: mill.pos.x + cos(ang) * mill.armLength, y: mill.pos.y + sin(ang) * mill.armLength)
            var p = Path()
            p.move(to: L.p(mill.pos))
            p.addLine(to: L.p(tip))
            context.stroke(p, with: .color(palette.goldHi.opacity(0.9)), lineWidth: L.s(mill.thickness * 1.6))
            context.fill(Path(ellipseIn: L.rect(tip, r: 1.7)), with: .color(palette.insertC.opacity(0.85)))
        }
        context.fill(Path(ellipseIn: L.rect(mill.pos, r: 4)), with: .color(palette.insertC))
        context.fill(Path(ellipseIn: L.rect(mill.pos, r: 1.6)), with: .color(palette.goldHi))
    }

    private func drawNails(context: inout GraphicsContext, L: TableLayoutScale) {
        for nail in engine.board.nails {
            let r = nail.radius
            let color = nail.gold ? palette.nailGold : palette.nail
            context.fill(Path(ellipseIn: L.rect(nail.pos, r: r)), with: .color(color))
            let hi = CGRect(
                x: L.p(nail.pos).x - L.s(r * 0.45),
                y: L.p(nail.pos).y - L.s(r * 0.55),
                width: L.s(r * 0.55),
                height: L.s(r * 0.55)
            )
            context.fill(Path(ellipseIn: hi), with: .color(Color.white.opacity(0.55)))
        }
    }

    private func drawRail(context: inout GraphicsContext, L: TableLayoutScale) {
        let rail = CGRect(
            x: L.p(Vec(x: BoardDef.railLeft, y: 40)).x,
            y: L.p(Vec(x: BoardDef.railLeft, y: 40)).y,
            width: L.s(BoardDef.railRight - BoardDef.railLeft),
            height: L.s(680)
        )
        context.fill(Path(roundedRect: rail, cornerRadius: L.s(6)), with: .color(Color.black.opacity(0.35)))
        context.stroke(Path(roundedRect: rail, cornerRadius: L.s(6)), with: .color(palette.gold.opacity(0.4)), lineWidth: 1)

        for streak in engine.railStreaks {
            let y = 680.0 - streak.t * 640.0
            let p = Vec(x: 370, y: y)
            let shadow = CGRect(
                x: L.p(p).x + L.s(1.4) - L.s(Physics.ballRadius),
                y: L.p(p).y + L.s(2.2) - L.s(Physics.ballRadius * 0.4),
                width: L.s(Physics.ballRadius * 2),
                height: L.s(Physics.ballRadius * 0.8)
            )
            context.fill(Path(ellipseIn: shadow), with: .color(Color.black.opacity(0.18)))
            context.fill(Path(ellipseIn: L.rect(p, r: Physics.ballRadius)), with: .color(palette.ball))
        }
    }

    private func drawBalls(context: inout GraphicsContext, L: TableLayoutScale) {
        for ball in engine.balls where ball.alive && !ball.inRail {
            if ball.trail.count > 1 {
                var trail = Path()
                trail.move(to: L.p(ball.trail[0]))
                for t in ball.trail.dropFirst() {
                    trail.addLine(to: L.p(t))
                }
                context.stroke(trail, with: .color(palette.ballHi.opacity(0.22)), lineWidth: L.s(2.2))
            }
            let stretch = min(2.2, hypot(ball.vel.x, ball.vel.y) * 0.0016)
            let shadow = CGRect(
                x: L.p(ball.pos).x + L.s(1.6 + ball.vel.x * 0.003) - L.s(ball.radius + stretch),
                y: L.p(ball.pos).y + L.s(2.6) - L.s(ball.radius * 0.42),
                width: L.s((ball.radius + stretch) * 2),
                height: L.s(ball.radius * 0.85)
            )
            context.fill(Path(ellipseIn: shadow), with: .color(Color.black.opacity(0.22)))
            let contact = CGRect(
                x: L.p(ball.pos).x - L.s(ball.radius * 0.55),
                y: L.p(ball.pos).y + L.s(ball.radius * 0.35),
                width: L.s(ball.radius * 1.1),
                height: L.s(ball.radius * 0.36)
            )
            context.fill(Path(ellipseIn: contact), with: .color(Color.black.opacity(0.16)))
            let rect = L.rect(ball.pos, r: ball.radius)
            context.fill(
                Path(ellipseIn: rect),
                with: .radialGradient(
                    Gradient(colors: [palette.ballHi, palette.ball, Color(red: 0.35, green: 0.38, blue: 0.42)]),
                    center: CGPoint(x: rect.midX - rect.width * 0.22, y: rect.midY - rect.height * 0.22),
                    startRadius: 0,
                    endRadius: rect.width * 0.7
                )
            )
        }
    }

    private func drawHandle(context: inout GraphicsContext, L: TableLayoutScale) {
        let c = Vec(x: 370, y: 648)
        let power = engine.handlePower
        let kick = engine.launchKick
        let cocked = power * 28
        let headY = 592 + cocked - kick * 36

        var spring = Path()
        let springTop = 548.0
        let coils = 7
        spring.move(to: L.p(Vec(x: 370, y: springTop)))
        for i in 0..<coils {
            let y0 = springTop + (headY - 8 - springTop) * Double(i) / Double(coils)
            let y1 = springTop + (headY - 8 - springTop) * Double(i + 1) / Double(coils)
            let mid = (y0 + y1) * 0.5
            let side = i % 2 == 0 ? 8.0 : -8.0
            spring.addLine(to: L.p(Vec(x: 370 + side, y: mid)))
        }
        spring.addLine(to: L.p(Vec(x: 370, y: headY - 6)))
        context.stroke(spring, with: .color(palette.nail.opacity(0.85)), lineWidth: L.s(1.5))

        let head = Vec(x: 370, y: headY)
        context.fill(Path(roundedRect: L.rect(head, r: 7).insetBy(dx: L.s(-1), dy: L.s(1)), cornerRadius: L.s(2)), with: .color(palette.gold))
        context.fill(Path(ellipseIn: L.rect(Vec(x: 370, y: headY - 5), r: 5.5)), with: .color(palette.goldHi))
        context.stroke(Path(ellipseIn: L.rect(Vec(x: 370, y: headY - 5), r: 5.5)), with: .color(palette.wood), lineWidth: 1)

        let r = 22.0
        context.fill(Path(ellipseIn: L.rect(c, r: r + 5)), with: .color(palette.lacquer))
        context.stroke(Path(ellipseIn: L.rect(c, r: r + 5)), with: .color(palette.gold), lineWidth: L.s(2.2))
        context.fill(
            Path(ellipseIn: L.rect(c, r: r)),
            with: .radialGradient(
                Gradient(colors: [palette.goldHi, palette.gold, palette.wood]),
                center: L.p(Vec(x: c.x - 6, y: c.y - 6)),
                startRadius: 0,
                endRadius: L.s(r)
            )
        )
        let ang = .pi * 0.15 + power * .pi * 1.35
        for ridge in 0..<10 {
            let a = ang + Double(ridge) * .pi * 2 / 10
            let inner = Vec(x: c.x + cos(a) * 12, y: c.y + sin(a) * 12)
            let outer = Vec(x: c.x + cos(a) * 19, y: c.y + sin(a) * 19)
            var grip = Path()
            grip.move(to: L.p(inner))
            grip.addLine(to: L.p(outer))
            context.stroke(grip, with: .color(palette.wood.opacity(0.9)), lineWidth: L.s(2.2))
        }
        let grip = Vec(x: c.x + cos(ang) * 16, y: c.y + sin(ang) * 16)
        context.fill(Path(ellipseIn: L.rect(grip, r: 5.5)), with: .color(palette.insertC))
        context.stroke(Path(ellipseIn: L.rect(grip, r: 5.5)), with: .color(palette.goldHi), lineWidth: 1)
        context.fill(Path(ellipseIn: L.rect(c, r: 4)), with: .color(Color.black.opacity(0.75)))
        context.fill(Path(ellipseIn: L.rect(c, r: 1.8)), with: .color(palette.goldHi))
    }

    private func drawParticles(context: inout GraphicsContext, L: TableLayoutScale) {
        for p in engine.particles {
            let alpha = max(0, p.life / max(0.01, p.maxLife))
            let color: Color = {
                if p.petal { return palette.insertA }
                switch p.colorIndex {
                case 1: return palette.gold
                case 2: return palette.fever
                case 3: return palette.danger
                default: return palette.insertA
                }
            }()
            if p.petal {
                let rect = CGRect(
                    x: L.p(p.pos).x - L.s(p.size),
                    y: L.p(p.pos).y - L.s(p.size * 0.55),
                    width: L.s(p.size * 2),
                    height: L.s(p.size)
                )
                context.fill(Path(ellipseIn: rect), with: .color(color.opacity(0.35 * alpha)))
            } else {
                context.fill(
                    Path(ellipseIn: L.rect(p.pos, r: p.size)),
                    with: .color(color.opacity(0.85 * alpha))
                )
            }
        }
    }

}
