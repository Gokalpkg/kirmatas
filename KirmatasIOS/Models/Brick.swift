import Foundation
import SwiftUI

final class Brick {
    var x: Double
    var y: Double
    var targetY: Double
    var width: Double
    var height: Double
    var hp: Int
    var maxHp: Int
    var isSteel: Bool
    var isHeavySteel: Bool
    var isMover: Bool
    var moverVx: Double
    var minX: Double
    var maxX: Double
    var isBoss: Bool
    var bossVx: Double
    var shootTimer: Double
    var isTuft: Bool
    var tuftFilled: Bool
    var tuftColor: Color
    var jelly: Double // wobble deformation amount (0.0 to 1.0)
    var color: Color
    var points: Int
    var isAlive: Bool

    init(
        x: Double,
        y: Double,
        targetY: Double? = nil,
        width: Double,
        height: Double,
        hp: Int = 1,
        maxHp: Int = 1,
        isSteel: Bool = false,
        isHeavySteel: Bool = false,
        isMover: Bool = false,
        moverVx: Double = 60.0,
        minX: Double = 10.0,
        maxX: Double = 380.0,
        isBoss: Bool = false,
        bossVx: Double = 70.0,
        shootTimer: Double = 2.0,
        isTuft: Bool = false,
        tuftFilled: Bool = false,
        tuftColor: Color = Color(hex: 0xFFFF7043),
        jelly: Double = 0.0,
        color: Color,
        points: Int = 10,
        isAlive: Bool = true
    ) {
        self.x = x
        self.y = y
        self.targetY = targetY ?? y
        self.width = width
        self.height = height
        self.hp = hp
        self.maxHp = maxHp
        self.isSteel = isSteel
        self.isHeavySteel = isHeavySteel
        self.isMover = isMover
        self.moverVx = moverVx
        self.minX = minX
        self.maxX = maxX
        self.isBoss = isBoss
        self.bossVx = bossVx
        self.shootTimer = shootTimer
        self.isTuft = isTuft
        self.tuftFilled = tuftFilled
        self.tuftColor = tuftColor
        self.jelly = jelly
        self.color = color
        self.points = points
        self.isAlive = isAlive
    }

    var rect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }

    func update(dt: Double) {
        guard isAlive else { return }

        // Smooth Y sliding for descend mode
        if abs(targetY - y) > 0.2 {
            y += (targetY - y) * (1.0 - exp(-12.0 * dt))
        } else {
            y = targetY
        }

        // Jelly decay
        if jelly > 0 {
            jelly -= dt * 3.5
            if jelly < 0 { jelly = 0 }
        }

        // Moving brick horizontal oscillation
        if isMover {
            x += moverVx * dt
            if x <= minX {
                x = minX
                moverVx = abs(moverVx)
            } else if x + width >= maxX {
                x = maxX - width
                moverVx = -abs(moverVx)
            }
        }

        // Boss brick logic
        if isBoss {
            x += bossVx * dt
            if x <= minX {
                x = minX
                bossVx = abs(bossVx)
            } else if x + width >= maxX {
                x = maxX - width
                bossVx = -abs(bossVx)
            }
            shootTimer -= dt
        }
    }
}
