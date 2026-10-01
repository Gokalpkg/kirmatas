import Foundation
import CoreGraphics

final class Paddle {
    var x: Double
    var y: Double
    var width: Double
    var height: Double
    var baseWidth: Double
    var isSticky: Bool
    var hasLaser: Bool
    var laserCooldown: Double
    var hasRockets: Bool
    var rocketCooldown: Double
    var hasDrone: Bool
    var droneAngle: Double
    var hasNet: Bool
    var netHitsRemaining: Int
    var isGhost: Bool
    var isReversed: Bool
    var isClumsy: Bool
    var prevX: Double
    var velocityX: Double
    var skinIndex: Int = SaveManager.shared.equippedPaddleIndex

    init(
        x: Double,
        y: Double,
        width: Double = 88.0,
        height: Double = 14.0,
        baseWidth: Double = 88.0,
        isSticky: Bool = false,
        hasLaser: Bool = false,
        laserCooldown: Double = 0.0,
        hasRockets: Bool = false,
        rocketCooldown: Double = 0.0,
        hasDrone: Bool = false,
        droneAngle: Double = 0.0,
        hasNet: Bool = false,
        netHitsRemaining: Int = 2,
        isGhost: Bool = false,
        isReversed: Bool = false,
        isClumsy: Bool = false,
        prevX: Double = 0.0,
        velocityX: Double = 0.0
    ) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.baseWidth = baseWidth
        self.isSticky = isSticky
        self.hasLaser = hasLaser
        self.laserCooldown = laserCooldown
        self.hasRockets = hasRockets
        self.rocketCooldown = rocketCooldown
        self.hasDrone = hasDrone
        self.droneAngle = droneAngle
        self.hasNet = hasNet
        self.netHitsRemaining = netHitsRemaining
        self.isGhost = isGhost
        self.isReversed = isReversed
        self.isClumsy = isClumsy
        self.prevX = prevX
        self.velocityX = velocityX
    }

    var rect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }

    func update(dt: Double) {
        let safeDt = dt > 0.0001 ? dt : 0.016
        velocityX = (x - prevX) / safeDt
        prevX = x

        if laserCooldown > 0 { laserCooldown -= dt }
        if rocketCooldown > 0 { rocketCooldown -= dt }
        if hasDrone {
            droneAngle += dt * 3.0
        }
    }

    func resetWidth() {
        width = baseWidth
    }
}

final class Projectile {
    var x: Double
    var y: Double
    var vx: Double
    var vy: Double
    var radius: Double
    var isLaser: Bool
    var isRocket: Bool
    var isBossBullet: Bool
    var isAlive: Bool

    init(
        x: Double,
        y: Double,
        vx: Double = 0.0,
        vy: Double = -450.0,
        radius: Double = 4.0,
        isLaser: Bool = false,
        isRocket: Bool = false,
        isBossBullet: Bool = false,
        isAlive: Bool = true
    ) {
        self.x = x
        self.y = y
        self.vx = vx
        self.vy = vy
        self.radius = radius
        self.isLaser = isLaser
        self.isRocket = isRocket
        self.isBossBullet = isBossBullet
        self.isAlive = isAlive
    }

    var rect: CGRect {
        CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
    }

    func update(dt: Double) {
        x += vx * dt
        y += vy * dt
    }
}
