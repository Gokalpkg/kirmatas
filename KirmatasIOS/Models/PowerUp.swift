import Foundation
import SwiftUI

enum PowerUpKind {
    case buff
    case debuff
}

enum PowerUpType: String, CaseIterable, Identifiable {
    // Buffs
    case wide
    case slow
    case sticky
    case laser
    case fireball
    case bomb
    case doublescore
    case multi
    case life
    case shield
    case pierce
    case rocket
    case net
    case lightning
    case drone
    case chrono
    case vortex
    case mirror
    case lock

    // Debuffs
    case shrink
    case fastball
    case reverse
    case clumsy
    case invis

    var id: String { rawValue }

    var label: String {
        I18n.tr("pup_\(rawValue)")
    }

    var color: Color {
        switch self {
        case .wide: return Color(hex: 0xFF40C4FF)
        case .slow: return Color(hex: 0xFF69F0AE)
        case .sticky: return Color(hex: 0xFFB388FF)
        case .laser: return Color(hex: 0xFFFFD740)
        case .fireball: return Color(hex: 0xFFFF6D00)
        case .bomb: return Color(hex: 0xFF8D6E63)
        case .doublescore: return Color(hex: 0xFFEC407A)
        case .multi: return Color(hex: 0xFFFF9800)
        case .life: return Color(hex: 0xFFFF5252)
        case .shield: return Color(hex: 0xFF26C6DA)
        case .pierce: return Color(hex: 0xFF00E5FF)
        case .rocket: return Color(hex: 0xFFFF5722)
        case .net: return Color(hex: 0xFF8BC34A)
        case .lightning: return Color(hex: 0xFF00E5FF)
        case .drone: return Color(hex: 0xFF00E676)
        case .chrono: return Color(hex: 0xFF80D8FF)
        case .vortex: return Color(hex: 0xFFE040FB)
        case .mirror: return Color(hex: 0xFFF48FB1)
        case .lock: return Color(hex: 0xFFFFAB00)
        case .shrink: return Color(hex: 0xFF90A4AE)
        case .fastball: return Color(hex: 0xFFFFB74D)
        case .reverse: return Color(hex: 0xFFCE93D8)
        case .clumsy: return Color(hex: 0xFF80CBC4)
        case .invis: return Color(hex: 0xFFCFD8DC)
        }
    }

    var duration: Double {
        switch self {
        case .wide: return 10.0
        case .slow: return 8.0
        case .sticky: return 10.0
        case .laser: return 8.0
        case .fireball: return 7.0
        case .bomb: return 7.0
        case .doublescore: return 10.0
        case .multi: return 0.0
        case .life: return 0.0
        case .shield: return 0.0
        case .pierce: return 6.0
        case .rocket: return 9.0
        case .net: return 10.0
        case .lightning: return 8.0
        case .drone: return 12.0
        case .chrono: return 5.0
        case .vortex: return 9.0
        case .mirror: return 0.0
        case .lock: return 0.0
        case .shrink: return 8.0
        case .fastball: return 8.0
        case .reverse: return 7.0
        case .clumsy: return 7.0
        case .invis: return 4.5
        }
    }

    var kind: PowerUpKind {
        switch self {
        case .shrink, .fastball, .reverse, .clumsy, .invis:
            return .debuff
        default:
            return .buff
        }
    }

    var sfSymbol: String {
        switch self {
        case .wide: return "arrow.left.and.right"
        case .slow: return "tortoise.fill"
        case .sticky: return "hand.raised.fill"
        case .laser: return "bolt.fill"
        case .fireball: return "flame.fill"
        case .bomb: return "burst.fill"
        case .doublescore: return "star.fill"
        case .multi: return "circle.grid.cross.fill"
        case .life: return "heart.fill"
        case .shield: return "shield.fill"
        case .pierce: return "arrow.up.circle.fill"
        case .rocket: return "paperplane.fill"
        case .net: return "squareshape.split.3x3"
        case .lightning: return "bolt.horizontal.fill"
        case .drone: return "sparkles"
        case .chrono: return "timer"
        case .vortex: return "tornado"
        case .mirror: return "arrow.left.and.right.righttriangle.left.righttriangle.right.fill"
        case .lock: return "scope"
        case .shrink: return "arrow.right.and.line.vertical.and.arrow.left"
        case .fastball: return "hare.fill"
        case .reverse: return "arrow.triangle.2.circlepath"
        case .clumsy: return "snowflake"
        case .invis: return "eye.slash.fill"
        }
    }

    var isInstant: Bool {
        duration <= 0
    }

    var assetName: String {
        "skill_\(rawValue)"
    }
}

final class FallingCapsule: Identifiable {
    let id = UUID()
    var x: Double
    var y: Double
    var vy: Double
    let type: PowerUpType
    var width: Double = 34.0
    var height: Double = 34.0
    var animTimer: Double = 0.0

    init(
        x: Double,
        y: Double,
        type: PowerUpType,
        vy: Double = 180.0
    ) {
        self.x = x
        self.y = y
        self.type = type
        self.vy = vy
    }

    func update(dt: Double) {
        y += vy * dt
        animTimer += dt
    }
}

final class ActivePowerUp: Identifiable {
    var id: String { type.rawValue }
    let type: PowerUpType
    var timeLeft: Double
    let totalTime: Double

    init(type: PowerUpType) {
        self.type = type
        self.timeLeft = type.duration
        self.totalTime = type.duration
    }

    var progress: Double {
        guard totalTime > 0 else { return 0.0 }
        return min(max(timeLeft / totalTime, 0.0), 1.0)
    }
}
