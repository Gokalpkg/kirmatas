import Foundation

// MARK: - Quest Types & Enums
public enum QuestType: String, Codable, CaseIterable, Sendable {
    case bricks = "q_bricks"
    case fish = "q_fish"
    case matches = "q_matches"
    case combo = "q_combo"
    case clutch = "q_clutch"
}

public enum QuestCategory: String, Codable, Sendable {
    case daily = "daily"
    case challenge = "challenge"
}

public enum StreakBonusType: String, Codable, Sendable {
    case welcome = "welcome"
    case lifeBoost = "life"
    case wideBoost = "wide"
    case jackpot = "jackpot"
}

// MARK: - Struct: DailyQuest
public struct DailyQuest: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let type: QuestType
    public let category: QuestCategory
    public let titleTR: String
    public let titleEN: String
    public let descriptionTR: String
    public let descriptionEN: String
    public let target: Int
    public var current: Int
    public var isClaimed: Bool
    public let goldReward: Int

    public var isCompleted: Bool {
        current >= target
    }

    public var canClaim: Bool {
        isCompleted && !isClaimed
    }

    public var progressFraction: Double {
        guard target > 0 else { return 0.0 }
        return min(max(Double(current) / Double(target), 0.0), 1.0)
    }

    public init(
        id: String,
        type: QuestType,
        category: QuestCategory,
        titleTR: String,
        titleEN: String,
        descriptionTR: String,
        descriptionEN: String,
        target: Int,
        current: Int = 0,
        isClaimed: Bool = false,
        goldReward: Int
    ) {
        self.id = id
        self.type = type
        self.category = category
        self.titleTR = titleTR
        self.titleEN = titleEN
        self.descriptionTR = descriptionTR
        self.descriptionEN = descriptionEN
        self.target = target
        self.current = current
        self.isClaimed = isClaimed
        self.goldReward = goldReward
    }

    public mutating func addProgress(_ amount: Int) {
        guard amount > 0 else { return }
        current = min(target, current + amount)
    }

    public func localizedTitle(lang: String) -> String {
        lang == "tr" ? titleTR : titleEN
    }

    public func localizedDescription(lang: String) -> String {
        lang == "tr" ? descriptionTR : descriptionEN
    }
}

// MARK: - Struct: StreakReward
public struct StreakReward: Identifiable, Codable, Equatable, Sendable {
    public var id: Int { day }
    public let day: Int // 1...7
    public let goldReward: Int
    public let bonusType: StreakBonusType?
    public let bonusDescriptionTR: String?
    public let bonusDescriptionEN: String?

    public init(
        day: Int,
        goldReward: Int,
        bonusType: StreakBonusType? = nil,
        bonusDescriptionTR: String? = nil,
        bonusDescriptionEN: String? = nil
    ) {
        self.day = day
        self.goldReward = goldReward
        self.bonusType = bonusType
        self.bonusDescriptionTR = bonusDescriptionTR
        self.bonusDescriptionEN = bonusDescriptionEN
    }

    public func localizedBonusDescription(lang: String) -> String? {
        lang == "tr" ? bonusDescriptionTR : bonusDescriptionEN
    }
}

// MARK: - Catalog: QuestCatalog
public enum QuestCatalog {
    public static let defaultDailyQuests: [DailyQuest] = [
        DailyQuest(
            id: QuestType.bricks.rawValue,
            type: .bricks,
            category: .daily,
            titleTR: "50 Tuğla Kır",
            titleEN: "Break 50 Bricks",
            descriptionTR: "Herhangi bir modda 50 tuğla kır",
            descriptionEN: "Destroy 50 bricks in any game mode",
            target: 50,
            current: 0,
            isClaimed: false,
            goldReward: 250
        ),
        DailyQuest(
            id: QuestType.fish.rawValue,
            type: .fish,
            category: .daily,
            titleTR: "Balıkları Besle",
            titleEN: "Feed the Fish",
            descriptionTR: "Akvaryumdaki balıkları 3 kez besle",
            descriptionEN: "Drop food and feed aquarium fish 3 times",
            target: 3,
            current: 0,
            isClaimed: false,
            goldReward: 100
        ),
        DailyQuest(
            id: QuestType.matches.rawValue,
            type: .matches,
            category: .daily,
            titleTR: "Maç Tamamla",
            titleEN: "Complete Matches",
            descriptionTR: "Herhangi bir modda 2 maç tamamla",
            descriptionEN: "Complete or survive 2 matches in any mode",
            target: 2,
            current: 0,
            isClaimed: false,
            goldReward: 150
        ),
        DailyQuest(
            id: QuestType.combo.rawValue,
            type: .combo,
            category: .challenge,
            titleTR: "7x Kombo Yap",
            titleEN: "Reach 7x Combo",
            descriptionTR: "Bir maçta 7x kombo serisine ulaş",
            descriptionEN: "Reach a 7-hit combo streak in a game",
            target: 7,
            current: 0,
            isClaimed: false,
            goldReward: 200
        ),
        DailyQuest(
            id: QuestType.clutch.rawValue,
            type: .clutch,
            category: .challenge,
            titleTR: "Clutch Kurtarış",
            titleEN: "Clutch Save",
            descriptionTR: "Topu alt sınırdan (<25px) kurtar",
            descriptionEN: "Save the ball from the bottom edge (<25px)",
            target: 1,
            current: 0,
            isClaimed: false,
            goldReward: 300
        )
    ]

    public static let streakRewards: [StreakReward] = [
        StreakReward(day: 1, goldReward: 65, bonusType: .welcome, bonusDescriptionTR: "Hoş Geldin Hediyesi", bonusDescriptionEN: "Welcome Gift"),
        StreakReward(day: 2, goldReward: 80, bonusType: nil, bonusDescriptionTR: nil, bonusDescriptionEN: nil),
        StreakReward(day: 3, goldReward: 95, bonusType: .lifeBoost, bonusDescriptionTR: "+1 Can Takviyesi", bonusDescriptionEN: "+1 Life Boost"),
        StreakReward(day: 4, goldReward: 110, bonusType: nil, bonusDescriptionTR: nil, bonusDescriptionEN: nil),
        StreakReward(day: 5, goldReward: 125, bonusType: .wideBoost, bonusDescriptionTR: "+1 Geniş Raket", bonusDescriptionEN: "+1 Wide Paddle Boost"),
        StreakReward(day: 6, goldReward: 140, bonusType: nil, bonusDescriptionTR: nil, bonusDescriptionEN: nil),
        StreakReward(day: 7, goldReward: 155, bonusType: .jackpot, bonusDescriptionTR: "Büyük İkramiye (+300 Altın)", bonusDescriptionEN: "Jackpot (+300 Gold)")
    ]

    public static func rewardForDay(_ day: Int) -> StreakReward {
        let cycleDay = ((day - 1) % 7) + 1
        return streakRewards.first(where: { $0.day == cycleDay }) ?? StreakReward(
            day: cycleDay,
            goldReward: 50 + cycleDay * 15,
            bonusType: nil,
            bonusDescriptionTR: nil,
            bonusDescriptionEN: nil
        )
    }
}
