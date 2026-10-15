import Foundation

final class BlackHole {
    var x: Double
    var y: Double
    var radius: Double
    var mass: Double
    var rotation: Double = 0
    var timeLeft: Double
    let isVortexTrap: Bool
    let isSupercharged: Bool

    var ballAngles: [ObjectIdentifier: Double] = [:]
    var ballAccumulatedAngles: [ObjectIdentifier: Double] = [:]
    var ballOrbitLaps: [ObjectIdentifier: Int] = [:]

    init(
        x: Double,
        y: Double,
        radius: Double,
        mass: Double,
        timeLeft: Double = 5.0,
        isVortexTrap: Bool = false,
        isSupercharged: Bool = false
    ) {
        self.x = x
        self.y = y
        self.radius = radius
        self.mass = mass
        self.timeLeft = timeLeft
        self.isVortexTrap = isVortexTrap
        self.isSupercharged = isSupercharged
    }

    var maxInfluenceDist: Double {
        max(135.0, radius * (isVortexTrap ? 6.5 : (isSupercharged ? 6.0 : 5.5)))
    }

    func update(dt: Double) {
        let speedMultiplier = isVortexTrap ? 4.5 : (isSupercharged ? 3.6 : 2.0)
        rotation += speedMultiplier * dt
        timeLeft -= dt
    }
}
