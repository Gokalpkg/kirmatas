import Foundation
import CoreGraphics

// MARK: - Easter Egg Bee
/// An ambient cute chibi bee that periodically flies across the screen.
/// Can be hit by the ball or tapped directly by the player.
final class EasterEggBee {
    var x: Double
    var y: Double
    let baseY: Double
    let vx: Double
    let isFacingRight: Bool
    var flightTime: Double = 0.0
    var isAlive: Bool = true
    let hitRadius: Double

    init(x: Double, baseY: Double, vx: Double, isFacingRight: Bool, hitRadius: Double = 14.0) {
        self.x = x
        self.baseY = baseY
        self.y = baseY
        self.vx = vx
        self.isFacingRight = isFacingRight
        self.hitRadius = hitRadius
    }

    func update(dt: Double) {
        flightTime += dt
        x += vx * dt

        // Realistic organic flight: primary sine oscillation + secondary micro-harmonic
        let verticalOscillation = sin(flightTime * 3.6) * 11.0 + sin(flightTime * 7.5) * 3.2
        y = baseY + verticalOscillation
    }

    /// Dynamic pitch/tilt angle in radians based on vertical flight velocity
    var tiltAngle: Double {
        let verticalVelocity = cos(flightTime * 3.6) * 39.6 + cos(flightTime * 7.5) * 24.0
        let tilt = min(max(verticalVelocity / 350.0, -0.16), 0.16)
        return isFacingRight ? tilt : -tilt
    }

    /// Rapid high-frequency wing flutter oscillation (-1.0 ... 1.0)
    var wingFlap: Double {
        sin(flightTime * 52.0)
    }

    func isOffScreen(screenWidth: Double) -> Bool {
        if vx > 0 && x > screenWidth + 50.0 { return true }
        if vx < 0 && x < -50.0 { return true }
        return false
    }

    /// Generous hitbox test for interactive touchscreen taps
    func containsPoint(_ point: CGPoint) -> Bool {
        guard isAlive else { return false }
        let dx = point.x - x
        let dy = point.y - y
        let touchRadius = hitRadius + 14.0
        return (dx * dx + dy * dy) <= (touchRadius * touchRadius)
    }
}

// MARK: - Windshield Splat
/// A humorous bug splatter mark appearing on the iPhone glass windshield
/// when the bee is hit or swatted.
final class WindshieldSplat {
    let x: Double
    let y: Double
    var timer: Double
    let duration: Double

    init(x: Double, y: Double, duration: Double = 2.2) {
        self.x = x
        self.y = y
        self.duration = duration
        self.timer = duration
    }

    var isDead: Bool { timer <= 0 }

    func update(dt: Double) {
        timer -= dt
        if timer < 0 { timer = 0 }
    }

    /// Full opacity for the first ~1.7s, then fades out smoothly over the final 0.5s
    var alpha: Double {
        if timer > 0.5 { return 1.0 }
        return min(max(timer / 0.5, 0.0), 1.0)
    }
}
