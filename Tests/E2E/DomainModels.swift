import Foundation

// MARK: - Rarity
public enum CosmeticRarity: String, CaseIterable, Codable {
    case common
    case rare
    case epic
    case legendary
    
    public var duplicateRefund: Int {
        switch self {
        case .common: return 150
        case .rare: return 350
        case .epic: return 700
        case .legendary: return 1200
        }
    }
    
    public var gphBonus: Double {
        switch self {
        case .common: return 0.1
        case .rare: return 0.25
        case .epic: return 0.5
        case .legendary: return 1.0
        }
    }
}

// MARK: - Fish Species
public struct FishSpecies: Identifiable, Equatable {
    public let id: String
    public let family: String
    public let rarity: CosmeticRarity
    public let size: Double
    public let assetName: String
    
    public init(id: String, family: String, rarity: CosmeticRarity, size: Double, assetName: String) {
        self.id = id
        self.family = family
        self.rarity = rarity
        self.size = size
        self.assetName = assetName
    }
    
    public static let all18Species: [FishSpecies] = [
        // Guppy
        FishSpecies(id: "guppy", family: "guppy", rarity: .common, size: 1.0, assetName: "fish_guppy"),
        FishSpecies(id: "guppy_blue", family: "guppy", rarity: .rare, size: 1.0, assetName: "fish_guppy_blue"),
        FishSpecies(id: "guppy_green", family: "guppy", rarity: .rare, size: 1.0, assetName: "fish_guppy_green"),
        
        // Tetra / Discus
        FishSpecies(id: "tetra", family: "tetra", rarity: .common, size: 1.1, assetName: "fish_tetra"),
        FishSpecies(id: "tetra_gold", family: "tetra", rarity: .rare, size: 1.1, assetName: "fish_tetra_gold"),
        FishSpecies(id: "tetra_purple", family: "tetra", rarity: .epic, size: 1.1, assetName: "fish_tetra_purple"),
        
        // Betta
        FishSpecies(id: "betta", family: "betta", rarity: .rare, size: 1.2, assetName: "fish_betta"),
        FishSpecies(id: "betta_blue", family: "betta", rarity: .epic, size: 1.2, assetName: "fish_betta_blue"),
        FishSpecies(id: "betta_orange", family: "betta", rarity: .legendary, size: 1.2, assetName: "fish_betta_orange"),
        
        // Angel
        FishSpecies(id: "angel", family: "angel", rarity: .rare, size: 1.3, assetName: "fish_angel"),
        FishSpecies(id: "angel_aqua", family: "angel", rarity: .epic, size: 1.3, assetName: "fish_angel_aqua"),
        FishSpecies(id: "angel_ruby", family: "angel", rarity: .legendary, size: 1.3, assetName: "fish_angel_ruby"),
        
        // Discus
        FishSpecies(id: "discus", family: "discus", rarity: .epic, size: 1.35, assetName: "fish_discus"),
        FishSpecies(id: "discus_blue", family: "discus", rarity: .epic, size: 1.35, assetName: "fish_discus_blue"),
        FishSpecies(id: "discus_green", family: "discus", rarity: .legendary, size: 1.35, assetName: "fish_discus_green"),
        
        // Arowana
        FishSpecies(id: "arowana", family: "arowana", rarity: .legendary, size: 1.5, assetName: "fish_arowana"),
        FishSpecies(id: "arowana_red", family: "arowana", rarity: .legendary, size: 1.5, assetName: "fish_arowana_red"),
        FishSpecies(id: "arowana_silver", family: "arowana", rarity: .legendary, size: 1.5, assetName: "fish_arowana_silver"),
    ]
}

// MARK: - Aquarium Simulation Models
public struct FoodPellet {
    public var x: Double
    public var y: Double
    public var vy: Double
    public var swayPhase: Double
    public var life: Double
    
    public init(x: Double, y: Double, vy: Double = 36.0, swayPhase: Double = 0.0, life: Double = 0.0) {
        self.x = x
        self.y = y
        self.vy = vy
        self.swayPhase = swayPhase
        self.life = life
    }
    
    public mutating func update(dt: Double) {
        y += vy * dt
        swayPhase += dt * 3.0
        x += sin(swayPhase) * 12.0 * dt
        life += dt
    }
}

public struct SimFish {
    public let species: FishSpecies
    public var x: Double
    public var y: Double
    public var vx: Double
    public var vy: Double
    public var facingRight: Bool
    
    public init(species: FishSpecies, x: Double, y: Double, vx: Double, vy: Double, facingRight: Bool) {
        self.species = species
        self.x = x
        self.y = y
        self.vx = vx
        self.vy = vy
        self.facingRight = facingRight
    }
    
    public mutating func update(dt: Double, tankWidth: Double, tankHeight: Double) {
        x += vx * dt
        y += vy * dt
        
        if x < 20 {
            x = 20
            vx = abs(vx)
            facingRight = true
        } else if x > tankWidth - 20 {
            x = tankWidth - 20
            vx = -abs(vx)
            facingRight = false
        }
        
        if y < 60 {
            y = 60
            vy = abs(vy)
        } else if y > tankHeight - 60 {
            y = tankHeight - 60
            vy = -abs(vy)
        }
    }
    
    public mutating func steerTowards(targetX: Double, targetY: Double, strength: Double = 40.0, dt: Double) {
        let dx = targetX - x
        let dy = targetY - y
        let dist = sqrt(dx * dx + dy * dy)
        if dist > 1.0 {
            vx += (dx / dist) * strength * dt
            vy += (dy / dist) * strength * dt
            facingRight = vx > 0
        }
    }
}

// MARK: - Hay Day 4-Hour Passive Economy
public struct AquariumEconomy {
    public static let activeFeedWindowSeconds: Double = 4.0 * 3600.0 // 14,400s
    public static let maxBankCapSeconds: Double = 8.0 * 3600.0      // 28,800s
    public static let baseGph: Double = 1.5
    public static let comebackBonus: Int = 20
    
    public var lastFedTime: Date
    public var accumulatedBank: Int
    public var unlockedFishIds: Set<String>
    public var floraSand: Int
    public var floraMoss: Int
    public var floraKelp: Int
    public var floraAnubias: Int
    
    public init(lastFedTime: Date = Date(), accumulatedBank: Int = 0, unlockedFishIds: Set<String> = ["guppy", "tetra"]) {
        self.lastFedTime = lastFedTime
        self.accumulatedBank = accumulatedBank
        self.unlockedFishIds = unlockedFishIds
        self.floraSand = 1
        self.floraMoss = 2
        self.floraKelp = 1
        self.floraAnubias = 1
    }
    
    public func isHungry(at currentTime: Date) -> Bool {
        return currentTime.timeIntervalSince(lastFedTime) >= Self.activeFeedWindowSeconds
    }
    
    public func calculateFloraBonus() -> Double {
        return Double(floraSand) * 0.2 + Double(floraMoss) * 0.4 + Double(floraKelp) * 0.6 + Double(floraAnubias) * 0.8
    }
    
    public func calculateFishBonus() -> Double {
        var bonus = 0.0
        for id in unlockedFishIds {
            if let f = FishSpecies.all18Species.first(where: { $0.id == id }) {
                bonus += f.rarity.gphBonus
            }
        }
        return bonus
    }
    
    public func totalRatePerHour() -> Double {
        return Self.baseGph + calculateFloraBonus() + calculateFishBonus()
    }
    
    public func calculateAccumulatedGold(from startTime: Date, to endTime: Date) -> Int {
        let elapsed = max(0.0, endTime.timeIntervalSince(startTime))
        // Passive generation halts after 4 hours of being fed
        let activeSeconds = min(elapsed, Self.activeFeedWindowSeconds)
        // Hard cap at 8h total max bank if active
        let cappedSeconds = min(activeSeconds, Self.maxBankCapSeconds)
        let rate = totalRatePerHour()
        let earned = floor(rate * (cappedSeconds / 3600.0))
        return Int(earned)
    }
    
    public mutating func feed(at currentTime: Date) -> (comebackBonusAwarded: Int, hungerCleared: Bool) {
        let wasHungry = isHungry(at: currentTime)
        var bonus = 0
        if wasHungry {
            bonus = Self.comebackBonus
            accumulatedBank += bonus
        }
        lastFedTime = currentTime
        return (bonus, wasHungry)
    }
    
    public mutating func collectBank() -> Int {
        let collected = accumulatedBank
        accumulatedBank = 0
        return collected
    }
}

// MARK: - Cosmetics & Shop Models
public struct CrateTierDef {
    public let id: String
    public let name: String
    public let cost: Int
    public let weights: [CosmeticRarity: Double]
    
    public static let wood = CrateTierDef(
        id: "wood",
        name: "Ahşap Sandık",
        cost: 900,
        weights: [.common: 70.0, .rare: 25.0, .epic: 5.0, .legendary: 0.0]
    )
    
    public static let coral = CrateTierDef(
        id: "coral",
        name: "Mercan Sandığı",
        cost: 1800,
        weights: [.common: 42.0, .rare: 38.0, .epic: 17.0, .legendary: 3.0]
    )
    
    public static let abyss = CrateTierDef(
        id: "abyss",
        name: "Derinlik Sandığı",
        cost: 3200,
        weights: [.common: 12.0, .rare: 38.0, .epic: 38.0, .legendary: 12.0]
    )
    
    public static let allCrates: [CrateTierDef] = [wood, coral, abyss]
}

public struct CosmeticCatalog {
    public static let ballSkins: [(id: String, cost: Int, rarity: CosmeticRarity)] = [
        ("classic", 0, .common),
        ("pembe", 1500, .rare),
        ("plazma", 1800, .rare),
        ("zumrut", 2000, .rare),
        ("golge", 2400, .epic),
        ("ates", 2800, .epic),
        ("isilti", 3200, .legendary),
        ("altin", 4500, .legendary),
        ("rainbow", 5000, .legendary),
        ("cyber", 3000, .epic),
        ("void", 3600, .epic),
        ("supernova", 6000, .legendary)
    ]
    
    public static let paddleSkins: [(id: String, cost: Int, rarity: CosmeticRarity)] = [
        ("pclassic", 0, .common),
        ("ppink", 1800, .rare),
        ("pice", 2400, .rare),
        ("pbat", 2800, .epic),
        ("pcyber", 3200, .epic),
        ("pgold", 4200, .legendary)
    ]
    
    public static let trailSkins: [(id: String, cost: Int, length: Int, rarity: CosmeticRarity)] = [
        ("t1", 0, 6, .common),
        ("t2", 1600, 16, .rare),
        ("spark", 2200, 22, .rare),
        ("fire", 2800, 26, .epic),
        ("rainbow", 3400, 28, .epic),
        ("plasma", 4200, 32, .legendary)
    ]
    
    public static let brickStyles: [(id: String, cost: Int)] = [
        ("b_classic", 0),
        ("b_neon", 1500),
        ("b_crystal", 2200),
        ("b_obsidian", 2800),
        ("b_cyber", 3200),
        ("b_gold", 4000)
    ]
    
    public static let backgrounds: [(id: String, cost: Int)] = [
        ("bg_default", 0),
        ("bg_nebula", 2000),
        ("bg_matrix", 2000),
        ("bg_abyss", 2000),
        ("bg_sunset", 2000),
        ("bg_inferno", 2000)
    ]
    
    public static let upgrades: [String: [Int]] = [
        "battery": [900, 1800, 3200],
        "magnet": [1100, 2100, 3600],
        "luck": [1400, 2600, 4200]
    ]
    
    public static let boosts: [String: Int] = [
        "life": 900,
        "wide": 1100,
        "multi": 1700
    ]
    
    public static func rainbowHue(gameTime: Double) -> Double {
        return (gameTime * 120.0).truncatingRemainder(dividingBy: 360.0)
    }
}

// MARK: - Daily Quests & 7-Day Login Streak
public enum QuestType: String, CaseIterable {
    case q_bricks
    case q_fish
    case q_matches
    case q_combo
    case q_clutch
    
    public var target: Int {
        switch self {
        case .q_bricks: return 50
        case .q_fish: return 3
        case .q_matches: return 2
        case .q_combo: return 5
        case .q_clutch: return 1
        }
    }
    
    public var goldReward: Int {
        switch self {
        case .q_bricks: return 100
        case .q_fish: return 80
        case .q_matches: return 120
        case .q_combo: return 90
        case .q_clutch: return 150
        }
    }
}

public struct DailyQuestModel: Identifiable {
    public let type: QuestType
    public var progress: Int
    public var isClaimed: Bool
    
    public var id: String { type.rawValue }
    public var isCompleted: Bool { progress >= type.target }
    public var canClaim: Bool { isCompleted && !isClaimed }
    
    public init(type: QuestType, progress: Int = 0, isClaimed: Bool = false) {
        self.type = type
        self.progress = progress
        self.isClaimed = isClaimed
    }
    
    public mutating func addProgress(_ amount: Int) {
        guard amount > 0 else { return }
        progress = min(type.target, progress + amount)
    }
}

public struct LoginStreakModel {
    public var currentStreak: Int
    public var lastClaimDate: String?
    
    public init(currentStreak: Int = 0, lastClaimDate: String? = nil) {
        self.currentStreak = currentStreak
        self.lastClaimDate = lastClaimDate
    }
    
    public func canClaim(today: String) -> Bool {
        return lastClaimDate != today
    }
    
    public mutating func claim(today: String, isConsecutive: Bool) -> (reward: Int, day: Int) {
        guard canClaim(today: today) else { return (0, currentStreak) }
        
        if isConsecutive {
            if currentStreak >= 7 {
                currentStreak = 1
            } else {
                currentStreak += 1
            }
        } else {
            currentStreak = 1
        }
        
        lastClaimDate = today
        
        let reward: Int
        if currentStreak == 7 {
            reward = 250 // Day 7 Jackpot
        } else {
            reward = 50 + (currentStreak % 7) * 15
        }
        
        return (reward, currentStreak)
    }
}

// MARK: - Game Physics & Engine Invariants
public struct BallPhysics {
    public var x: Double
    public var y: Double
    public var vx: Double
    public var vy: Double
    public var radius: Double
    
    public init(x: Double, y: Double, vx: Double, vy: Double, radius: Double = 8.0) {
        self.x = x
        self.y = y
        self.vx = vx
        self.vy = vy
        self.radius = radius
    }
    
    public var speed: Double {
        sqrt(vx * vx + vy * vy)
    }
}

public struct PaddlePhysics {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    
    public init(x: Double, y: Double, width: Double = 100.0, height: Double = 18.0) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
    
    public mutating func trackTouch(touchX: Double, tankWidth: Double) {
        // Absolute tracking clamped to boundaries
        let minX = 0.0
        let maxX = tankWidth - width
        let targetX = touchX - (width / 2.0)
        x = min(max(targetX, minX), maxX)
    }
    
    public func cornerBoostMultiplier(hitX: Double) -> (factor: Double, isCorner: Bool) {
        let rel = (hitX - x) / width
        // Outer 22% zone left or right
        if rel < 0.22 || rel > 0.78 {
            return (1.45, true)
        }
        return (1.0, false)
    }
}

public struct MinkowskiCollision {
    public static func resolveBallBrick(ball: inout BallPhysics, brickX: Double, brickY: Double, brickW: Double, brickH: Double) -> Bool {
        let halfBrickW = brickW / 2.0
        let halfBrickH = brickH / 2.0
        let brickCenterX = brickX + halfBrickW
        let brickCenterY = brickY + halfBrickH
        
        let dx = ball.x - brickCenterX
        let dy = ball.y - brickCenterY
        
        let combinedHalfW = halfBrickW + ball.radius
        let combinedHalfH = halfBrickH + ball.radius
        
        let overlapX = combinedHalfW - abs(dx)
        let overlapY = combinedHalfH - abs(dy)
        
        if overlapX > 0 && overlapY > 0 {
            // Collision occurred, resolve on minimum penetration axis
            if overlapX < overlapY {
                ball.x += (dx > 0 ? overlapX : -overlapX)
                ball.vx = -ball.vx
            } else {
                ball.y += (dy > 0 ? overlapY : -overlapY)
                ball.vy = -ball.vy
            }
            return true
        }
        return false
    }
}

public final class AudioThrottler {
    public static let minIntervalSeconds: Double = 0.040 // 40ms
    private var lastPlayTime: Double = -1.0
    
    public init() {}
    
    public func shouldPlay(currentTime: Double) -> Bool {
        if lastPlayTime < 0 || (currentTime - lastPlayTime) >= Self.minIntervalSeconds {
            lastPlayTime = currentTime
            return true
        }
        return false
    }
}

// MARK: - Integrated Player Save State
public final class PlayerSaveState {
    public var gold: Int = 300
    public var unlockedBalls: Set<String> = ["classic"]
    public var unlockedPaddles: Set<String> = ["pclassic"]
    public var unlockedTrails: Set<String> = ["t1"]
    public var unlockedBricks: Set<String> = ["b_classic"]
    public var unlockedBackgrounds: Set<String> = ["bg_default"]
    
    public var equippedBall: String = "classic"
    public var equippedPaddle: String = "pclassic"
    public var equippedTrail: String = "t1"
    public var equippedBrick: String = "b_classic"
    public var equippedBackground: String = "bg_default"
    
    public var upgrades: [String: Int] = ["battery": 0, "magnet": 0, "luck": 0]
    public var boosts: [String: Int] = ["life": 0, "wide": 0, "multi": 0]
    
    public var aquarium: AquariumEconomy = AquariumEconomy()
    public var loginStreak: LoginStreakModel = LoginStreakModel()
    public var quests: [DailyQuestModel] = QuestType.allCases.map { DailyQuestModel(type: $0) }
    
    public init(initialGold: Int = 300) {
        self.gold = initialGold
    }
    
    public func canAfford(_ cost: Int) -> Bool {
        return gold >= cost
    }
    
    public func spendGold(_ cost: Int) -> Bool {
        guard canAfford(cost) else { return false }
        gold -= cost
        return true
    }
    
    public func addGold(_ amount: Int) {
        gold += max(0, amount)
    }
    
    public func openCrate(tier: CrateTierDef, rolledRarity: CosmeticRarity, candidateSkinId: String) -> (droppedSkinId: String, duplicateRefund: Int) {
        guard spendGold(tier.cost) else { return ("", 0) }
        if unlockedBalls.contains(candidateSkinId) {
            let refund = rolledRarity.duplicateRefund
            addGold(refund)
            return (candidateSkinId, refund)
        } else {
            unlockedBalls.insert(candidateSkinId)
            return (candidateSkinId, 0)
        }
    }
    
    public func buyUpgrade(_ upgradeId: String) -> Bool {
        guard let costs = CosmeticCatalog.upgrades[upgradeId] else { return false }
        let currentLvl = upgrades[upgradeId] ?? 0
        guard currentLvl < costs.count else { return false }
        let cost = costs[currentLvl]
        guard spendGold(cost) else { return false }
        upgrades[upgradeId] = currentLvl + 1
        return true
    }
}
