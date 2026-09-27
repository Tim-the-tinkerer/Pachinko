import Foundation

struct Vec: Equatable {
    var x: Double
    var y: Double

    static let zero = Vec(x: 0, y: 0)

    var length: Double { hypot(x, y) }
    var lengthSquared: Double { x * x + y * y }

    func normalized() -> Vec {
        let l = length
        guard l > 1e-9 else { return .zero }
        return Vec(x: x / l, y: y / l)
    }

    func dot(_ o: Vec) -> Double { x * o.x + y * o.y }
    func perp() -> Vec { Vec(x: -y, y: x) }

    static func + (a: Vec, b: Vec) -> Vec { Vec(x: a.x + b.x, y: a.y + b.y) }
    static func - (a: Vec, b: Vec) -> Vec { Vec(x: a.x - b.x, y: a.y - b.y) }
    static func * (a: Vec, s: Double) -> Vec { Vec(x: a.x * s, y: a.y * s) }
    static func * (s: Double, a: Vec) -> Vec { a * s }
    static func / (a: Vec, s: Double) -> Vec { Vec(x: a.x / s, y: a.y / s) }
    static func += (a: inout Vec, b: Vec) { a = a + b }
    static func -= (a: inout Vec, b: Vec) { a = a - b }
}

struct Wall {
    var a: Vec
    var b: Vec
    var restitution: Double
    var isRubber: Bool
}

struct Nail {
    var pos: Vec
    var radius: Double
    var restitution: Double
    var gold: Bool
}

struct Ball {
    var id: Int
    var pos: Vec
    var vel: Vec
    var radius: Double
    var trail: [Vec]
    var alive: Bool
    var captured: Bool
    var inRail: Bool
    var railT: Double
    var firePower: Double

    var speed: Double { vel.length }
}

enum Physics {
    static let gravity = 980.0
    static let maxSpeed = 1600.0
    static let airDrag = 0.10
    static let ballRadius = 7.15
    static let nailRadius = 2.18

    static func closestPointOnSegment(_ p: Vec, _ a: Vec, _ b: Vec) -> Vec {
        let ab = b - a
        let d = ab.lengthSquared
        if d < 1e-12 { return a }
        let t = max(0, min(1, (p - a).dot(ab) / d))
        return a + ab * t
    }

    static func collideWall(ball: inout Ball, wall: Wall) -> Bool {
        let closest = closestPointOnSegment(ball.pos, wall.a, wall.b)
        let delta = ball.pos - closest
        var dist = delta.length
        let minDist = ball.radius
        if dist >= minDist { return false }
        var n: Vec
        if dist < 1e-8 {
            let seg = wall.b - wall.a
            n = seg.perp().normalized()
            if n.dot(ball.vel) > 0 { n = n * -1 }
            dist = 0
        } else {
            n = delta / dist
        }
        let pen = minDist - dist
        ball.pos += n * (pen + 0.05)
        let vn = ball.vel.dot(n)
        if vn < 0 {
            let e = wall.restitution
            ball.vel -= n * (1 + e) * vn
            let tangent = n.perp()
            let vt = ball.vel.dot(tangent)
            let friction = wall.isRubber ? 0.14 : 0.05
            ball.vel -= tangent * vt * friction
        }
        return true
    }

    static func collideNail(ball: inout Ball, nail: Nail) -> Bool {
        let delta = ball.pos - nail.pos
        var dist = delta.length
        let minDist = ball.radius + nail.radius
        if dist >= minDist { return false }
        var n: Vec
        if dist < 1e-8 {
            n = ball.vel.length > 1 ? (ball.vel * -1).normalized() : Vec(x: 0, y: -1)
            dist = 0
        } else {
            n = delta / dist
        }
        let pen = minDist - dist
        ball.pos += n * (pen + 0.06)
        let vn = ball.vel.dot(n)
        if vn < 0 {
            ball.vel -= n * (1 + nail.restitution) * vn
            let tangent = n.perp()
            let vt = ball.vel.dot(tangent)
            ball.vel -= tangent * vt * 0.08
        }
        return true
    }

    static func collideSpinningArm(
        ball: inout Ball,
        hub: Vec,
        angle: Double,
        length: Double,
        thickness: Double,
        angularVel: Double
    ) -> Bool {
        let tip = Vec(x: hub.x + cos(angle) * length, y: hub.y + sin(angle) * length)
        let closest = closestPointOnSegment(ball.pos, hub, tip)
        let delta = ball.pos - closest
        var dist = delta.length
        let minDist = ball.radius + thickness
        if dist >= minDist { return false }
        var n: Vec
        if dist < 1e-8 {
            n = (tip - hub).perp().normalized()
            dist = 0
        } else {
            n = delta / dist
        }
        let pen = minDist - dist
        ball.pos += n * (pen + 0.08)
        let r = closest - hub
        let surfaceVel = Vec(x: -angularVel * r.y, y: angularVel * r.x)
        var rel = ball.vel - surfaceVel
        let vn = rel.dot(n)
        if vn < 0 {
            rel -= n * (1 + 0.35) * vn
            ball.vel = rel + surfaceVel
        }
        return true
    }

    static func collideBalls(_ a: inout Ball, _ b: inout Ball) -> Bool {
        guard a.alive, b.alive, !a.captured, !b.captured, !a.inRail, !b.inRail else { return false }
        let delta = b.pos - a.pos
        var dist = delta.length
        let minDist = a.radius + b.radius
        if dist >= minDist { return false }
        var n: Vec
        if dist < 1e-8 {
            n = Vec(x: 1, y: 0)
            dist = 0
        } else {
            n = delta / dist
        }
        let pen = minDist - dist
        a.pos -= n * (pen * 0.5 + 0.04)
        b.pos += n * (pen * 0.5 + 0.04)
        let rel = a.vel.dot(n) - b.vel.dot(n)
        if rel > 0 {
            let j = rel * 0.88
            a.vel -= n * j
            b.vel += n * j
        }
        return true
    }

    static func clampSpeed(_ ball: inout Ball) {
        let s = ball.vel.length
        if s > maxSpeed {
            ball.vel = ball.vel * (maxSpeed / s)
        }
    }
}
