import Foundation
import Combine

final class SaveManager: ObservableObject {
    static let shared = SaveManager()

    private let defaults = UserDefaults.standard

    @Published var gold: Int = 300
    @Published var highScores: [String: Int] = [
        "classic": 0,
        "zen": 0,
        "descend": 0,
        "daily": 0,
        "tuft": 0
    ]
    @Published var lastDailyClaimDate: String?
    @Published var dailyStreak: Int = 1
    @Published var speed: SpeedSetting = .medium
    @Published var sfxEnabled: Bool = true
    @Published var hapticIntensity: HapticIntensity = .strong
    @Published var language: String = "tr"
    @Published var unlockedPaddles: [Int] = [0]
    @Published var equippedPaddleIndex: Int = 0


    var hapticsEnabled: Bool {
        hapticIntensity != .off
    }

    private init() {
        load()
    }

    func load() {
        if defaults.object(forKey: "gold") != nil {
            gold = defaults.integer(forKey: "gold")
        } else {
            gold = 300
        }

        if let savedScores = defaults.dictionary(forKey: "highScores") as? [String: Int] {
            for (k, v) in savedScores {
                highScores[k] = v
            }
        }

        lastDailyClaimDate = defaults.string(forKey: "lastDailyClaimDate")
        if defaults.object(forKey: "dailyStreak") != nil {
            dailyStreak = defaults.integer(forKey: "dailyStreak")
        }

        if defaults.object(forKey: "speedSetting") != nil {
            let idx = defaults.integer(forKey: "speedSetting")
            speed = SpeedSetting(rawValue: idx) ?? .medium
        }

        if defaults.object(forKey: "sfxEnabled") != nil {
            sfxEnabled = defaults.bool(forKey: "sfxEnabled")
        } else {
            sfxEnabled = true
        }

        if defaults.object(forKey: "hapticIntensity") != nil {
            let hIdx = defaults.integer(forKey: "hapticIntensity")
            hapticIntensity = HapticIntensity(rawValue: hIdx) ?? .strong
        }

        language = defaults.string(forKey: "language") ?? "tr"

        if let unl = defaults.array(forKey: "unlockedPaddles") as? [Int] {
            unlockedPaddles = unl
        } else {
            unlockedPaddles = [0]
        }
        if defaults.object(forKey: "equippedPaddleIndex") != nil {
            equippedPaddleIndex = defaults.integer(forKey: "equippedPaddleIndex")
        }

    }

    func unlockPaddle(index: Int) {
        if !unlockedPaddles.contains(index) {
            unlockedPaddles.append(index)
            defaults.set(unlockedPaddles, forKey: "unlockedPaddles")
        }
    }

    func equipPaddle(index: Int) {
        if unlockedPaddles.contains(index) {
            equippedPaddleIndex = index
            defaults.set(index, forKey: "equippedPaddleIndex")
        }
    }


    func addGold(_ amount: Int) {
        gold += amount
        defaults.set(gold, forKey: "gold")
    }

    func updateHighScore(mode: GameMode, score: Int) {
        let current = highScores[mode.rawValue] ?? 0
        if score > current {
            highScores[mode.rawValue] = score
            defaults.set(highScores, forKey: "highScores")
        }
    }

    func getHighScore(_ mode: GameMode) -> Int {
        highScores[mode.rawValue] ?? 0
    }

    func canClaimDaily() -> Bool {
        let today = Self.todayString()
        return lastDailyClaimDate != today
    }

    @discardableResult
    func claimDailyReward() -> Int {
        guard canClaimDaily() else { return 0 }
        let today = Self.todayString()
        lastDailyClaimDate = today
        defaults.set(today, forKey: "lastDailyClaimDate")

        dailyStreak += 1
        defaults.set(dailyStreak, forKey: "dailyStreak")

        let reward = 50 + (dailyStreak % 7) * 15
        addGold(reward)
        return reward
    }

    func setSpeed(_ s: SpeedSetting) {
        speed = s
        defaults.set(s.rawValue, forKey: "speedSetting")
    }

    func setSfx(_ val: Bool) {
        sfxEnabled = val
        defaults.set(val, forKey: "sfxEnabled")
    }

    func setHapticIntensity(_ val: HapticIntensity) {
        hapticIntensity = val
        defaults.set(val.rawValue, forKey: "hapticIntensity")
    }

    func setLanguage(_ lang: String) {
        language = lang
        defaults.set(lang, forKey: "language")
    }

    private static func todayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}
