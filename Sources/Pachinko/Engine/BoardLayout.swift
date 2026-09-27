import Foundation

struct BoardDef {
    static let width = 390.0
    static let height = 720.0
    static let playLeft = 22.0
    static let playRight = 348.0
    static let railLeft = 356.0
    static let railRight = 384.0

    var theme: CabinetTheme
    var nails: [Nail]
    var walls: [Wall]
    var railWalls: [Wall]
    var pockets: [Pocket]
    var windmill: Windmill
    var coverWalls: [Wall]

    /// Spare room past a ball's diameter. Below this, a ball rests on the nails instead of falling through.
    private static let passMargin = 1.75

    static func make(_ theme: CabinetTheme, difficulty: Difficulty) -> BoardDef {
        let plan = FieldPlan.make(theme)
        let chucker = plan.chucker
        let leftTulip = plan.leftTulip
        let rightTulip = plan.rightTulip
        let attacker = FieldPlan.attacker

        var walls: [Wall] = []
        func w(_ ax: Double, _ ay: Double, _ bx: Double, _ by: Double, _ e: Double = 0.38, rubber: Bool = false) {
            walls.append(Wall(a: Vec(x: ax, y: ay), b: Vec(x: bx, y: by), restitution: e, isRubber: rubber))
        }

        w(playLeft, 40, playLeft, 500)
        w(playRight, 40, playRight, 500)
        w(playLeft, 40, 80, 22)
        w(80, 22, 200, 16)
        w(200, 16, 300, 22)
        w(300, 22, playRight, 48)

        // Shoulders into the out hole
        w(playLeft, 500, 128, 668, 0.28)
        w(playRight, 500, 244, 668, 0.28)
        w(128, 668, 244, 668, 0.15)
        w(playLeft, 500, playLeft, 700, 0.2)
        w(playRight, 500, playRight, 700, 0.2)

        // Tulip cups
        w(leftTulip.x - 16, leftTulip.y - 6, leftTulip.x - 8, leftTulip.y + 14, 0.22, rubber: true)
        w(leftTulip.x + 16, leftTulip.y - 6, leftTulip.x + 8, leftTulip.y + 14, 0.22, rubber: true)
        w(rightTulip.x - 16, rightTulip.y - 6, rightTulip.x - 8, rightTulip.y + 14, 0.22, rubber: true)
        w(rightTulip.x + 16, rightTulip.y - 6, rightTulip.x + 8, rightTulip.y + 14, 0.22, rubber: true)

        var railWalls: [Wall] = []
        func rw(_ ax: Double, _ ay: Double, _ bx: Double, _ by: Double) {
            railWalls.append(Wall(a: Vec(x: ax, y: ay), b: Vec(x: bx, y: by), restitution: 0.25, isRubber: false))
        }
        rw(railLeft, 720, railLeft, 70)
        rw(railRight, 720, railRight, 36)
        rw(railRight, 36, 300, 18)
        rw(railLeft, 70, railLeft, 44)
        rw(railLeft, 44, 332, 32)

        let pockets: [Pocket] = [
            Pocket(pos: chucker, radius: 11.5, kind: .chucker, payout: 2, open: true, flash: 0, label: "START"),
            Pocket(pos: leftTulip, radius: 10.0, kind: .tulip, payout: 2, open: true, flash: 0, label: "左"),
            Pocket(pos: rightTulip, radius: 10.0, kind: .tulip, payout: 2, open: true, flash: 0, label: "右"),
            Pocket(pos: attacker, radius: 15.5, kind: .attacker, payout: 15, open: false, flash: 0, label: "ATTACK"),
            Pocket(pos: Vec(x: 186, y: 690), radius: 22, kind: .out, payout: 0, open: true, flash: 0, label: "OUT"),
        ]

        // Peaked lid. A flat bar is a shelf, and balls sit on it.
        let cover: [Wall] = [
            Wall(a: Vec(x: attacker.x - 34, y: attacker.y - 6), b: Vec(x: attacker.x, y: attacker.y - 30), restitution: 0.35, isRubber: true),
            Wall(a: Vec(x: attacker.x, y: attacker.y - 30), b: Vec(x: attacker.x + 34, y: attacker.y - 6), restitution: 0.35, isRubber: true),
        ]

        let mill = Windmill(pos: plan.windmill, angle: plan.millAngle, speed: plan.millSpeed, armLength: 30, thickness: 3.4)
        let nails = placeNails(
            walls: walls + cover,
            plan: plan,
            mill: mill,
            gap: difficulty.chuckerGap
        )

        return BoardDef(
            theme: theme,
            nails: nails,
            walls: walls,
            railWalls: railWalls,
            pockets: pockets,
            windmill: mill,
            coverWalls: cover
        )
    }

    /// Staggered field. Every gap between nails, and between a nail and a wall, is wider than a ball.
    private static func placeNails(
        walls: [Wall],
        plan: FieldPlan,
        mill: Windmill,
        gap: Double
    ) -> [Nail] {
        let nr = Physics.nailRadius
        let lipRadius = nr + 0.3
        let lipGap = max(gap, minCenter(lipRadius, lipRadius))
        let lipY = plan.chucker.y - 22
        let lips = [
            Vec(x: plan.chucker.x - lipGap * 0.5, y: lipY),
            Vec(x: plan.chucker.x + lipGap * 0.5, y: lipY),
        ]
        let wheelClear = mill.armLength + mill.thickness + nr + 2.5
        let minX = playLeft + minWall(nr)
        let maxX = playRight - minWall(nr)

        var nails: [Nail] = []
        // Row -1 is the top spreader, on the same stagger as the field below it.
        for row in -1..<plan.rows {
            let y = plan.originY + Double(row) * plan.rowSpacing
            let odd = !row.isMultiple(of: 2)
            let offset = odd ? plan.colSpacing * plan.oddFraction : 0
            for col in 0..<24 {
                let x = plan.originX + Double(col) * plan.colSpacing + offset
                if x > maxX { break }
                if x < minX { continue }
                let p = Vec(x: x, y: y)
                if !clearsWalls(p, radius: nr, walls: walls) { continue }
                if (p - plan.chucker).length < 20 { continue }
                if (p - plan.leftTulip).length < 22 { continue }
                if (p - plan.rightTulip).length < 22 { continue }
                if (p - FieldPlan.attacker).length < 28 { continue }
                if (p - mill.pos).length < wheelClear { continue }
                if lips.contains(where: { (p - $0).length < minCenter(nr, lipRadius) }) { continue }
                let gold = ((row + col) % plan.goldEvery + plan.goldEvery) % plan.goldEvery == 0
                nails.append(Nail(pos: p, radius: nr, restitution: gold ? 0.48 : 0.42, gold: gold))
            }
        }

        for lip in lips {
            nails.append(Nail(pos: lip, radius: lipRadius, restitution: 0.4, gold: true))
        }
        assert(gapsFit(nails, walls: walls), "A nail gap is narrower than a ball")
        return nails
    }

    private static func minCenter(_ a: Double, _ b: Double) -> Double {
        Physics.ballRadius * 2 + a + b + passMargin
    }

    private static func minWall(_ radius: Double) -> Double {
        Physics.ballRadius * 2 + radius + passMargin
    }

    private static func clearsWalls(_ p: Vec, radius: Double, walls: [Wall]) -> Bool {
        let need = minWall(radius)
        for wall in walls {
            let closest = Physics.closestPointOnSegment(p, wall.a, wall.b)
            if (p - closest).length < need { return false }
        }
        return true
    }

    private static func gapsFit(_ nails: [Nail], walls: [Wall]) -> Bool {
        let ballD = Physics.ballRadius * 2
        for i in nails.indices {
            let a = nails[i]
            for j in nails.indices where j > i {
                let b = nails[j]
                let spare = (a.pos - b.pos).length - a.radius - b.radius - ballD
                if spare + 0.001 < passMargin { return false }
            }
            for wall in walls {
                let closest = Physics.closestPointOnSegment(a.pos, wall.a, wall.b)
                let spare = (a.pos - closest).length - a.radius - ballD
                if spare + 0.001 < passMargin { return false }
            }
        }
        return true
    }
}

/// Nail spacing and where the wheel, start hole, and tulips sit.
/// Spacing stays wider than a ball. The out hole and attacker stay put so the drain does not change.
struct FieldPlan {
    var colSpacing: Double
    var rowSpacing: Double
    var originX: Double
    var originY: Double
    var rows: Int
    var oddFraction: Double
    var goldEvery: Int
    var chucker: Vec
    var leftTulip: Vec
    var rightTulip: Vec
    var windmill: Vec
    var millSpeed: Double
    var millAngle: Double

    static let attacker = Vec(x: 186, y: 578)

    static func make(_ theme: CabinetTheme) -> FieldPlan {
        switch theme {
        case .sakura:
            return FieldPlan(
                colSpacing: 26, rowSpacing: 24, originX: 41, originY: 96,
                rows: 18, oddFraction: 0.5, goldEvery: 7,
                chucker: Vec(x: 186, y: 368),
                leftTulip: Vec(x: 72, y: 458),
                rightTulip: Vec(x: 300, y: 458),
                windmill: Vec(x: 186, y: 198),
                millSpeed: 2.05, millAngle: 0.3
            )
        case .dragon:
            // Wider columns and shorter rows, like scales. The wheel sits on the right.
            return FieldPlan(
                colSpacing: 28, rowSpacing: 22, originX: 42, originY: 94,
                rows: 18, oddFraction: 0.5, goldEvery: 5,
                chucker: Vec(x: 186, y: 368),
                leftTulip: Vec(x: 88, y: 430),
                rightTulip: Vec(x: 268, y: 490),
                windmill: Vec(x: 250, y: 214),
                millSpeed: 1.85, millAngle: 0.9
            )
        case .neon:
            // A slightly square grid that leans. The wheel is up on the left.
            return FieldPlan(
                colSpacing: 24, rowSpacing: 26, originX: 48, originY: 100,
                rows: 16, oddFraction: 0.42, goldEvery: 3,
                chucker: Vec(x: 186, y: 368),
                leftTulip: Vec(x: 70, y: 420),
                rightTulip: Vec(x: 292, y: 486),
                windmill: Vec(x: 112, y: 188),
                millSpeed: 2.35, millAngle: 2.2
            )
        case .koi:
            // Fewer, wider-spaced nails. The wheel turns slowly above a low start hole.
            return FieldPlan(
                colSpacing: 32, rowSpacing: 30, originX: 50, originY: 108,
                rows: 14, oddFraction: 0.5, goldEvery: 5,
                chucker: Vec(x: 186, y: 400),
                leftTulip: Vec(x: 96, y: 490),
                rightTulip: Vec(x: 276, y: 490),
                windmill: Vec(x: 186, y: 176),
                millSpeed: 1.45, millAngle: 0.6
            )
        case .lantern:
            // Rows are closer, and odd rows shift only a third of a gap, so the lanes run diagonally.
            // The start hole sits right of center.
            return FieldPlan(
                colSpacing: 26, rowSpacing: 22, originX: 44, originY: 90,
                rows: 18, oddFraction: 0.35, goldEvery: 4,
                chucker: Vec(x: 214, y: 352),
                leftTulip: Vec(x: 68, y: 430),
                rightTulip: Vec(x: 248, y: 468),
                windmill: Vec(x: 118, y: 200),
                millSpeed: 2.45, millAngle: 1.1
            )
        case .river:
            // A faster wheel in the middle kicks balls into a left current or a right one.
            return FieldPlan(
                colSpacing: 24, rowSpacing: 26, originX: 46, originY: 100,
                rows: 16, oddFraction: 0.5, goldEvery: 6,
                chucker: Vec(x: 186, y: 420),
                leftTulip: Vec(x: 78, y: 360),
                rightTulip: Vec(x: 294, y: 360),
                windmill: Vec(x: 186, y: 230),
                millSpeed: 2.7, millAngle: 0.15
            )
        }
    }
}
