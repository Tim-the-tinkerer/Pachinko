import Foundation

/// One frame of the board, run off the main actor. Game rules (score, reels, sound)
/// stay on the engine and are applied from the notices this returns.
struct WorldStep: Sendable {
    var dt: Double
    var firing: Bool
    var spendTray: Bool
    var tray: Int
    var fireInterval: Double
    var fireCool: Double
    var handlePower: Double
    var nextBallId: Int
    var nailSoundCool: Double
    var balls: [Ball]
    var nails: [Nail]
    var walls: [Wall]
    var coverWalls: [Wall]
    var pockets: [Pocket]
    var windmill: Windmill
    var stuckTime: [Int: Double]
    var fever: Bool
}

struct WorldStepResult: Sendable {
    var balls: [Ball]
    var windmillAngle: Double
    var fireCool: Double
    var nextBallId: Int
    var nailSoundCool: Double
    var stuckTime: [Int: Double]
    var shots: Int
    var shotPower: Double
    var captures: [Int]
    var lostAt: [Vec]
    var nailHit: NailHit?
}

struct NailHit: Sendable {
    var speed: Double
    var gold: Bool
}

enum TableSimulation {
    static func advance(_ step: WorldStep) -> WorldStepResult {
        var balls = step.balls
        var windmill = step.windmill
        let pockets = step.pockets
        var fireCool = step.fireCool
        var nextBallId = step.nextBallId
        var nailSoundCool = step.nailSoundCool
        var stuckTime = step.stuckTime
        var shots = 0
        var shotPower = step.handlePower
        var captures: [Int] = []
        var lostAt: [Vec] = []
        var nailHit: NailHit?
        let bins = NailBins(nails: step.nails)
        let attackerOpen = pockets.first(where: { $0.kind == .attacker })?.open ?? false

        let scale = step.fever ? 1.8 : 1.0
        windmill.angle += windmill.speed * scale * step.dt

        if nailSoundCool > 0 { nailSoundCool = max(0, nailSoundCool - step.dt) }
        if fireCool > 0 { fireCool = max(0, fireCool - step.dt) }

        if step.firing {
            let interval = step.fireInterval + (1 - step.handlePower) * 0.08
            let inPlay = balls.reduce(0) { $0 + (($1.alive && !$1.captured) ? 1 : 0) }
            if fireCool <= 0, inPlay < 28, !step.spendTray || step.tray > 0 {
                fireCool = interval
                balls.append(Ball(
                    id: nextBallId,
                    pos: Vec(x: 370, y: 680),
                    vel: .zero,
                    radius: Physics.ballRadius,
                    trail: [],
                    alive: true,
                    captured: false,
                    inRail: true,
                    railT: 0,
                    firePower: step.handlePower
                ))
                nextBallId += 1
                shots = 1
                shotPower = step.handlePower
            }
        }

        let spinSpeed = windmill.speed * scale
        let sub = step.dt / 6
        for _ in 0..<6 {
            stepPhysics(
                dt: sub,
                balls: &balls,
                nails: step.nails,
                bins: bins,
                walls: step.walls,
                cover: attackerOpen ? [] : step.coverWalls,
                windmill: windmill,
                spinSpeed: spinSpeed,
                nailSoundCool: &nailSoundCool,
                nailHit: &nailHit,
                lostAt: &lostAt
            )
        }

        for i in balls.indices where balls[i].alive && !balls[i].captured && !balls[i].inRail {
            let p = balls[i].pos
            let v = balls[i].vel
            if !p.x.isFinite || !p.y.isFinite || !v.x.isFinite || !v.y.isFinite {
                balls[i].alive = false
                continue
            }
            var trail = balls[i].trail
            trail.append(p)
            if trail.count > 8 { trail.removeFirst(trail.count - 8) }
            balls[i].trail = trail
        }

        for i in balls.indices where balls[i].alive && !balls[i].captured && !balls[i].inRail {
            let p = balls[i].pos
            for k in pockets.indices {
                let pocket = pockets[k]
                if !pocket.open && pocket.kind == .attacker { continue }
                let reach = pocket.kind == .out ? pocket.radius + 8 : pocket.radius - 1.5
                if (p - pocket.pos).length <= max(4, reach) {
                    balls[i].alive = false
                    balls[i].captured = true
                    captures.append(k)
                    break
                }
            }
        }

        for i in balls.indices where balls[i].alive && !balls[i].inRail {
            if balls[i].speed < 14 {
                stuckTime[balls[i].id, default: 0] += step.dt
                if stuckTime[balls[i].id, default: 0] > 1.4 {
                    balls[i].vel += Vec(x: Double.random(in: -80...80), y: 40)
                    stuckTime[balls[i].id] = 0
                }
            } else {
                stuckTime[balls[i].id] = 0
            }
        }
        balls.removeAll { !$0.alive }
        let live = Set(balls.map(\.id))
        stuckTime = stuckTime.filter { live.contains($0.key) }

        return WorldStepResult(
            balls: balls,
            windmillAngle: windmill.angle,
            fireCool: fireCool,
            nextBallId: nextBallId,
            nailSoundCool: nailSoundCool,
            stuckTime: stuckTime,
            shots: shots,
            shotPower: shotPower,
            captures: captures,
            lostAt: lostAt,
            nailHit: nailHit
        )
    }

    private static func stepPhysics(
        dt: Double,
        balls: inout [Ball],
        nails: [Nail],
        bins: NailBins,
        walls: [Wall],
        cover: [Wall],
        windmill: Windmill,
        spinSpeed: Double,
        nailSoundCool: inout Double,
        nailHit: inout NailHit?,
        lostAt: inout [Vec]
    ) {
        let g = Physics.gravity
        for i in balls.indices where balls[i].alive && !balls[i].captured {
            if balls[i].inRail {
                balls[i].railT += dt / 0.16
                if balls[i].railT >= 1 {
                    dropFromRail(index: i, balls: &balls)
                }
                continue
            }

            balls[i].vel.y += g * dt
            balls[i].vel = balls[i].vel * (1 - Physics.airDrag * dt)
            balls[i].pos += balls[i].vel * dt
            Physics.clampSpeed(&balls[i])

            for wall in walls {
                let impact = balls[i].speed
                if Physics.collideWall(ball: &balls[i], wall: wall) {
                    noteHit(speed: impact * 0.45, gold: false, cool: &nailSoundCool, hit: &nailHit)
                }
            }
            for wall in cover {
                _ = Physics.collideWall(ball: &balls[i], wall: wall)
            }

            let pos = balls[i].pos
            bins.forEach(near: pos, nails: nails) { nail in
                let impact = balls[i].speed
                if Physics.collideNail(ball: &balls[i], nail: nail) {
                    noteHit(speed: impact, gold: nail.gold, cool: &nailSoundCool, hit: &nailHit)
                }
            }

            for arm in 0..<4 {
                let ang = windmill.angle + Double(arm) * .pi / 2
                if Physics.collideSpinningArm(
                    ball: &balls[i],
                    hub: windmill.pos,
                    angle: ang,
                    length: windmill.armLength,
                    thickness: windmill.thickness,
                    angularVel: spinSpeed
                ) {
                    noteHit(speed: 220, gold: true, cool: &nailSoundCool, hit: &nailHit)
                }
            }

            if balls[i].pos.x < 8 {
                balls[i].pos.x = 8
                balls[i].vel.x = abs(balls[i].vel.x) * 0.4
            }
            if balls[i].pos.x > BoardDef.playRight + 6 && balls[i].pos.x < BoardDef.railLeft {
                balls[i].pos.x = BoardDef.playRight
                balls[i].vel.x = -abs(balls[i].vel.x) * 0.4
            }
            if balls[i].pos.y < 10 {
                balls[i].pos.y = 10
                balls[i].vel.y = abs(balls[i].vel.y) * 0.35
            }
            if balls[i].pos.y > 652 && balls[i].pos.x > 118 && balls[i].pos.x < 254 {
                if balls[i].alive && lostAt.count < 4 {
                    lostAt.append(balls[i].pos)
                }
                balls[i].alive = false
            } else if balls[i].pos.y > BoardDef.height + 40 {
                if balls[i].alive && lostAt.count < 4 {
                    lostAt.append(balls[i].pos)
                }
                balls[i].alive = false
            }
        }

        if balls.count > 1 {
            let limit = (Physics.ballRadius * 2 + 1) * (Physics.ballRadius * 2 + 1)
            for a in balls.indices where balls[a].alive && !balls[a].inRail && !balls[a].captured {
                for b in balls.indices where b > a && balls[b].alive && !balls[b].inRail && !balls[b].captured {
                    let dx = balls[a].pos.x - balls[b].pos.x
                    let dy = balls[a].pos.y - balls[b].pos.y
                    if dx * dx + dy * dy > limit { continue }
                    var ba = balls[a]
                    var bb = balls[b]
                    _ = Physics.collideBalls(&ba, &bb)
                    balls[a] = ba
                    balls[b] = bb
                }
            }
        }
    }

    private static func noteHit(speed: Double, gold: Bool, cool: inout Double, hit: inout NailHit?) {
        guard speed > 70, cool <= 0, hit == nil else { return }
        cool = 0.03
        hit = NailHit(speed: speed, gold: gold)
    }

    private static func dropFromRail(index: Int, balls: inout [Ball]) {
        let power = balls[index].firePower
        let jitter = Double.random(in: -14...14)
        let x = 328.0 - power * 286.0 + jitter
        balls[index].inRail = false
        balls[index].pos = Vec(x: min(max(x, 36), 330), y: 48)
        balls[index].vel = Vec(x: Double.random(in: -55...25), y: 50 + Double.random(in: 0...40))
        balls[index].railT = 1
    }
}

/// Nails do not move, so each ball only tests the cells around it.
private struct NailBins {
    static let cell = 42.0
    static let cols = 10
    static let rows = 18

    var bins: [[Int]]

    init(nails: [Nail]) {
        bins = Array(repeating: [], count: Self.cols * Self.rows)
        for index in nails.indices {
            let nail = nails[index]
            let c = min(Self.cols - 1, max(0, Int(nail.pos.x / Self.cell)))
            let r = min(Self.rows - 1, max(0, Int(nail.pos.y / Self.cell)))
            bins[r * Self.cols + c].append(index)
        }
    }

    func forEach(near p: Vec, nails: [Nail], body: (Nail) -> Void) {
        let c = Int(p.x / Self.cell)
        let r = Int(p.y / Self.cell)
        for dr in -1...1 {
            for dc in -1...1 {
                let cc = c + dc
                let rr = r + dr
                guard cc >= 0, rr >= 0, cc < Self.cols, rr < Self.rows else { continue }
                for index in bins[rr * Self.cols + cc] {
                    body(nails[index])
                }
            }
        }
    }
}
