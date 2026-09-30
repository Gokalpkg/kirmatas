import Foundation
import CoreGraphics

struct TrailPoint {
    let position: CGPoint
    let time: Double
}

final class Ball {
    var x: Double
    var y: Double
    var vx: Double
    var vy: Double
    var radius: Double
    var isStuck: Bool
    var stuckOffsetX: Double
    var trail: [TrailPoint] = []
    var isFireball: Bool
    var isBomb: Bool
    var isPierce: Bool
    var isMirror: Bool
    var overload: Int
    var squashTimer: Double
    var squashAngle: Double
    var stuckTimer: Double
    var cornerBoostTimer: Double

    init(
        x: Double,
        y: Double,
        vx: Double = 0.0,
        vy: Double = 0.0,
        radius: Double = 7.5,
        isStuck: Bool = true,
        stuckOffsetX: Double = 0.0,
        isFireball: Bool = false,
        isBomb: Bool = false,
        isPierce: Bool = false,
        isMirror: Bool = false,
        overload: Int = 0,
        squashTimer: Double = 0.0,
        squashAngle: Double = 0.0,
        stuckTimer: Double = 0.0,
        cornerBoostTimer: Double = 0.0
    ) {
        self.x = x
        self.y = y
        self.vx = vx
        self.vy = vy
        self.radius = radius
        self.isStuck = isStuck
        self.stuckOffsetX = stuckOffsetX
        self.isFireball = isFireball
        self.isBomb = isBomb
        self.isPierce = isPierce
        self.isMirror = isMirror
        self.overload = overload
        self.squashTimer = squashTimer
        self.squashAngle = squashAngle
        self.stuckTimer = stuckTimer
        self.cornerBoostTimer = cornerBoostTimer
    }

    var speed: Double {
        sqrt(vx * vx + vy * vy)
    }

    func setSpeed(_ targetSpeed: Double) {
        let currentSpeed = speed
        if currentSpeed > 0.001 {
            let factor = targetSpeed / currentSpeed
            vx *= factor
            vy *= factor
        } else {
            vx = targetSpeed * 0.5
            vy = -targetSpeed * 0.866
        }
    }

    func triggerSquash(_ angle: Double) {
        squashTimer = 0.22
        squashAngle = angle
    }

    func update(dt: Double) {
        if squashTimer > 0 {
            squashTimer -= dt
            if squashTimer < 0 { squashTimer = 0 }
        }
        if cornerBoostTimer > 0 {
            cornerBoostTimer -= dt
            if cornerBoostTimer < 0 { cornerBoostTimer = 0.0 }
        }

        if !isStuck {
            x += vx * dt
            y += vy * dt

            trail.insert(TrailPoint(position: CGPoint(x: x, y: y), time: dt), at: 0)
            if trail.count > 16 {
                trail.removeLast()
            }
        }
    }
}
