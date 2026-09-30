import Foundation
import SwiftUI

enum GameMode: String, CaseIterable, Identifiable {
    case classic
    case zen
    case descend
    case daily
    case tuft

    var id: String { rawValue }

    var displayName: String {
        I18n.tr(rawValue)
    }

    var description: String {
        I18n.tr("\(rawValue)_desc")
    }
}

enum GameStatus: Equatable {
    case ready
    case playing
    case paused
    case gameOver
    case victory
}

enum SpeedSetting: Int, CaseIterable, Identifiable {
    case slow = 0
    case medium = 1
    case fast = 2

    var id: Int { rawValue }

    var multiplier: Double {
        switch self {
        case .slow: return 0.5
        case .medium: return 1.48
        case .fast: return 2.05
        }
    }

    var label: String {
        switch self {
        case .slow: return I18n.tr("slow")
        case .medium: return I18n.tr("normal")
        case .fast: return I18n.tr("fast")
        }
    }
}

enum HapticIntensity: Int, CaseIterable, Identifiable {
    case off = 0
    case light = 1
    case medium = 2
    case strong = 3

    var id: Int { rawValue }

    var keyName: String {
        switch self {
        case .off: return "off"
        case .light: return "light"
        case .medium: return "medium"
        case .strong: return "strong"
        }
    }

    var label: String {
        I18n.tr("haptic_\(keyName)")
    }
}

struct MatchStats {
    var score: Int = 0
    var lives: Int = 3
    var maxLives: Int = 3
    var level: Int = 1
    var combo: Int = 0
    var maxCombo: Int = 0
    var bricksBroken: Int = 0
    var goldCollected: Int = 0
    var ultiCharge: Double = 0.0 // 0.0 to 100.0
    var isFever: Bool = false
    var feverTimeLeft: Double = 0.0
    var bulletTimeLeft: Double = 0.0
    var ultiActiveLeft: Double = 0.0

    mutating func reset(initialLives: Int = 3, startLevel: Int = 1) {
        score = 0
        lives = initialLives
        maxLives = initialLives
        level = startLevel
        combo = 0
        maxCombo = 0
        bricksBroken = 0
        goldCollected = 0
        ultiCharge = 0.0
        isFever = false
        feverTimeLeft = 0.0
        bulletTimeLeft = 0.0
        ultiActiveLeft = 0.0
    }
}
