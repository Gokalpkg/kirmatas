import Foundation
import SwiftUI

final class Particle {
    var x: Double
    var y: Double
    var vx: Double
    var vy: Double
    var size: Double
    var color: Color
    var life: Double
    let maxLife: Double

    init(
        x: Double,
        y: Double,
        vx: Double,
        vy: Double,
        size: Double,
        color: Color,
        maxLife: Double
    ) {
        self.x = x
        self.y = y
        self.vx = vx
        self.vy = vy
        self.size = size
        self.color = color
        self.maxLife = maxLife
        self.life = maxLife
    }

    var isDead: Bool { life <= 0 }

    func update(dt: Double) {
        x += vx * dt
        y += vy * dt
        life -= dt
    }
}

final class Shockwave {
    let x: Double
    let y: Double
    let color: Color
    let maxRadius: Double
    var currentRadius: Double = 4.0
    let duration: Double
    var progress: Double = 0.0

    init(
        x: Double,
        y: Double,
        color: Color,
        maxRadius: Double = 45.0,
        duration: Double = 0.35
    ) {
        self.x = x
        self.y = y
        self.color = color
        self.maxRadius = maxRadius
        self.duration = duration
    }

    var isDead: Bool { progress >= 1.0 }

    func update(dt: Double) {
        progress += dt / duration
        let t = min(max(progress, 0.0), 1.0)
        // easeOutCubic: 1 - (1 - t)^3
        let inv = 1.0 - t
        let eased = 1.0 - (inv * inv * inv)
        currentRadius = maxRadius * eased
    }
}

final class FloatingText {
    var x: Double
    var y: Double
    let text: String
    let color: Color
    let isLarge: Bool
    var life: Double
    let maxLife: Double

    init(
        x: Double,
        y: Double,
        text: String,
        color: Color,
        isLarge: Bool = false,
        maxLife: Double = 0.75
    ) {
        self.x = x
        self.y = y
        self.text = text
        self.color = color
        self.isLarge = isLarge
        self.maxLife = maxLife
        self.life = maxLife
    }

    var isDead: Bool { life <= 0 }

    func update(dt: Double) {
        y -= 35.0 * dt
        life -= dt
    }
}

final class ParticleSystem {
    var particles: [Particle] = []
    var shockwaves: [Shockwave] = []
    var floatingTexts: [FloatingText] = []

    var shakeTimeLeft: Double = 0.0
    var shakeMagnitude: Double = 0.0

    static let maxParticles = 50
    static let maxShockwaves = 6
    static let maxFloatingTexts = 5

    func triggerShake(magnitude: Double, duration: Double) {
        shakeMagnitude = magnitude
        shakeTimeLeft = duration
    }

    func getShakeOffset() -> CGPoint {
        guard shakeTimeLeft > 0 else { return .zero }
        let dx = Double.random(in: -1.0...1.0) * shakeMagnitude
        let dy = Double.random(in: -1.0...1.0) * shakeMagnitude
        return CGPoint(x: dx, y: dy)
    }

    func spawnBurst(x: Double, y: Double, color: Color, count: Int = 10, speed: Double = 150.0) {
        let toAdd = min(count, Self.maxParticles - particles.count + 8)
        guard toAdd > 0 else { return }

        for _ in 0..<toAdd {
            if particles.count >= Self.maxParticles {
                particles.removeFirst()
            }
            let angle = Double.random(in: 0...(2.0 * .pi))
            let spd = speed * Double.random(in: 0.4...1.2)
            particles.append(
                Particle(
                    x: x,
                    y: y,
                    vx: cos(angle) * spd,
                    vy: sin(angle) * spd,
                    size: Double.random(in: 2.0...4.5),
                    color: color,
                    maxLife: Double.random(in: 0.25...0.50)
                )
            )
        }
    }

    func spawnShockwave(x: Double, y: Double, color: Color, maxRadius: Double = 45.0) {
        if shockwaves.count >= Self.maxShockwaves {
            shockwaves.removeFirst()
        }
        shockwaves.append(Shockwave(x: x, y: y, color: color, maxRadius: maxRadius))
    }

    func spawnFloatingText(x: Double, y: Double, text: String, color: Color, isLarge: Bool = false) {
        if floatingTexts.count >= Self.maxFloatingTexts {
            floatingTexts.removeFirst()
        }
        floatingTexts.append(FloatingText(x: x, y: y, text: text, color: color, isLarge: isLarge))
    }

    func update(dt: Double) {
        if shakeTimeLeft > 0 {
            shakeTimeLeft -= dt
            if shakeTimeLeft < 0 { shakeTimeLeft = 0 }
        }

        for i in stride(from: particles.count - 1, through: 0, by: -1) {
            particles[i].update(dt: dt)
            if particles[i].isDead {
                particles.remove(at: i)
            }
        }

        for i in stride(from: shockwaves.count - 1, through: 0, by: -1) {
            shockwaves[i].update(dt: dt)
            if shockwaves[i].isDead {
                shockwaves.remove(at: i)
            }
        }

        for i in stride(from: floatingTexts.count - 1, through: 0, by: -1) {
            floatingTexts[i].update(dt: dt)
            if floatingTexts[i].isDead {
                floatingTexts.remove(at: i)
            }
        }
    }

    func clear() {
        particles.removeAll()
        shockwaves.removeAll()
        floatingTexts.removeAll()
        shakeTimeLeft = 0.0
    }
}
