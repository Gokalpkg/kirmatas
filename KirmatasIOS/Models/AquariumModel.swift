import SwiftUI
import Foundation

// MARK: - Fish Family
public enum FishFamily: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case guppy
    case discus
    case angelfish
    case glowTetra
    case royalBetta
    case dragonArowana

    public var id: String { rawValue }

    public var defaultName: String {
        switch self {
        case .guppy: return "Lepistes (Guppy)"
        case .discus: return "Diskus (Discus)"
        case .angelfish: return "Melek Balığı (Angelfish)"
        case .glowTetra: return "Pırıltılı Tetra (Glow Tetra)"
        case .royalBetta: return "Kral Betta (Royal Betta)"
        case .dragonArowana: return "Ejder Arowana (Dragon Arowana)"
        }
    }
}

// MARK: - 18 Fish Species
public struct FishSpecies: Identifiable, Hashable, Sendable {
    public let id: String
    public let nameKey: String
    public let defaultName: String
    public let family: FishFamily
    public let rarity: Rarity
    public let size: Double
    public let primaryColor: Color
    public let secondaryColor: Color
    public let assetName: String

    public var name: String {
        let tr = I18n.tr(nameKey)
        return tr != nameKey ? tr : I18n.name(defaultName)
    }

    public var localizedName: String {
        name
    }

    public var passiveGPH: Double {
        switch rarity {
        case .common: return 2.0
        case .rare: return 4.0
        case .epic: return 7.0
        case .legendary: return 12.0
        }
    }

    public init(
        id: String,
        nameKey: String? = nil,
        defaultName: String,
        family: FishFamily,
        rarity: Rarity,
        size: Double,
        primaryColor: Color,
        secondaryColor: Color,
        assetName: String? = nil
    ) {
        self.id = id
        self.nameKey = nameKey ?? "fish_\(id)"
        self.defaultName = defaultName
        self.family = family
        self.rarity = rarity
        self.size = size
        self.primaryColor = primaryColor
        self.secondaryColor = secondaryColor
        self.assetName = assetName ?? "fish_\(id)"
    }

    public static let allSpecies: [FishSpecies] = [
        // 1. Guppy Family
        FishSpecies(
            id: "guppy",
            defaultName: "Mercan Lepistes",
            family: .guppy,
            rarity: .common,
            size: 1.0,
            primaryColor: Color(hex: 0xFFFF8A80),
            secondaryColor: Color(hex: 0xFFFF5252)
        ),
        FishSpecies(
            id: "guppy_blue",
            defaultName: "Safir Lepistes",
            family: .guppy,
            rarity: .rare,
            size: 1.0,
            primaryColor: Color(hex: 0xFF40C4FF),
            secondaryColor: Color(hex: 0xFF0288D1)
        ),
        FishSpecies(
            id: "guppy_green",
            defaultName: "Zümrüt Lepistes",
            family: .guppy,
            rarity: .rare,
            size: 1.0,
            primaryColor: Color(hex: 0xFF69F0AE),
            secondaryColor: Color(hex: 0xFF00E676)
        ),

        // 2. Discus / Tetra Family
        FishSpecies(
            id: "tetra",
            defaultName: "Neon Diskus",
            family: .discus,
            rarity: .common,
            size: 1.1,
            primaryColor: Color(hex: 0xFF4FC3F7),
            secondaryColor: Color(hex: 0xFF0288D1)
        ),
        FishSpecies(
            id: "tetra_gold",
            defaultName: "Alevli Diskus",
            family: .discus,
            rarity: .rare,
            size: 1.1,
            primaryColor: Color(hex: 0xFFFF4081),
            secondaryColor: Color(hex: 0xFF00E676)
        ),
        FishSpecies(
            id: "tetra_purple",
            defaultName: "Ametist Diskus",
            family: .discus,
            rarity: .epic,
            size: 1.1,
            primaryColor: Color(hex: 0xFFB388FF),
            secondaryColor: Color(hex: 0xFF76FF03)
        ),

        // 3. Angelfish Family
        FishSpecies(
            id: "angel",
            defaultName: "Altın Melek Balığı",
            family: .angelfish,
            rarity: .rare,
            size: 1.45,
            primaryColor: Color(hex: 0xFFFFF59D),
            secondaryColor: Color(hex: 0xFFFBC02D)
        ),
        FishSpecies(
            id: "angel_aqua",
            defaultName: "Okyanus Melek Balığı",
            family: .angelfish,
            rarity: .epic,
            size: 1.45,
            primaryColor: Color(hex: 0xFF00E5FF),
            secondaryColor: Color(hex: 0xFF00B0FF)
        ),
        FishSpecies(
            id: "angel_ruby",
            defaultName: "Yakut Melek Balığı",
            family: .angelfish,
            rarity: .epic,
            size: 1.45,
            primaryColor: Color(hex: 0xFFFF1744),
            secondaryColor: Color(hex: 0xFFD50000)
        ),

        // 4. Glow Tetra Family
        FishSpecies(
            id: "betta",
            defaultName: "Pırıltılı Tetra",
            family: .glowTetra,
            rarity: .rare,
            size: 1.25,
            primaryColor: Color(hex: 0xFFE040FB),
            secondaryColor: Color(hex: 0xFF8E24AA)
        ),
        FishSpecies(
            id: "betta_blue",
            defaultName: "Plazma Tetra",
            family: .glowTetra,
            rarity: .epic,
            size: 1.25,
            primaryColor: Color(hex: 0xFFFF3D00),
            secondaryColor: Color(hex: 0xFF00E5FF)
        ),
        FishSpecies(
            id: "betta_orange",
            defaultName: "Zümrüt Tetra",
            family: .glowTetra,
            rarity: .epic,
            size: 1.25,
            primaryColor: Color(hex: 0xFF00E676),
            secondaryColor: Color(hex: 0xFFD500F9)
        ),

        // 5. Royal Betta Family
        FishSpecies(
            id: "discus",
            defaultName: "Kral Betta",
            family: .royalBetta,
            rarity: .epic,
            size: 1.55,
            primaryColor: Color(hex: 0xFF2979FF),
            secondaryColor: Color(hex: 0xFFFF3D00)
        ),
        FishSpecies(
            id: "discus_blue",
            defaultName: "Altın Kanat Betta",
            family: .royalBetta,
            rarity: .epic,
            size: 1.55,
            primaryColor: Color(hex: 0xFFFFD700),
            secondaryColor: Color(hex: 0xFF00E5FF)
        ),
        FishSpecies(
            id: "discus_green",
            defaultName: "Zehir Betta",
            family: .royalBetta,
            rarity: .legendary,
            size: 1.55,
            primaryColor: Color(hex: 0xFFE040FB),
            secondaryColor: Color(hex: 0xFF76FF03)
        ),

        // 6. Dragon Arowana Family
        FishSpecies(
            id: "arowana",
            defaultName: "Efsanevi Altın Ejder",
            family: .dragonArowana,
            rarity: .legendary,
            size: 1.9,
            primaryColor: Color(hex: 0xFFFFD700),
            secondaryColor: Color(hex: 0xFFFFAB00)
        ),
        FishSpecies(
            id: "arowana_red",
            defaultName: "Kızıl Ejder Arowana",
            family: .dragonArowana,
            rarity: .legendary,
            size: 1.9,
            primaryColor: Color(hex: 0xFFFF1744),
            secondaryColor: Color(hex: 0xFF00B0FF)
        ),
        FishSpecies(
            id: "arowana_silver",
            defaultName: "Platin Ejder Arowana",
            family: .dragonArowana,
            rarity: .legendary,
            size: 1.9,
            primaryColor: Color(hex: 0xFFECEFF1),
            secondaryColor: Color(hex: 0xFFB0BEC5)
        )
    ]

    public static func getById(_ id: String) -> FishSpecies {
        allSpecies.first(where: { $0.id == id }) ?? allSpecies[0]
    }
}

// MARK: - Flora Bonus
public struct FloraBonus: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let nameKey: String
    public let defaultName: String
    public let gphBonus: Double
    public let cost: Int
    public let maxCount: Int
    public let sfSymbol: String

    public var name: String {
        let tr = I18n.tr(nameKey)
        return tr != nameKey ? tr : I18n.name(defaultName)
    }

    public init(
        id: String,
        nameKey: String? = nil,
        defaultName: String,
        gphBonus: Double,
        cost: Int,
        maxCount: Int,
        sfSymbol: String
    ) {
        self.id = id
        self.nameKey = nameKey ?? "flora_\(id)"
        self.defaultName = defaultName
        self.gphBonus = gphBonus
        self.cost = cost
        self.maxCount = maxCount
        self.sfSymbol = sfSymbol
    }

    public static let allFlora: [FloraBonus] = [
        FloraBonus(
            id: "moss",
            defaultName: "Su Yosunu (Moss)",
            gphBonus: 4.0,
            cost: 240,
            maxCount: 6,
            sfSymbol: "leaf.fill"
        ),
        FloraBonus(
            id: "kelp",
            defaultName: "Dev Kelp (Kelp)",
            gphBonus: 7.0,
            cost: 380,
            maxCount: 4,
            sfSymbol: "laurel.leading"
        ),
        FloraBonus(
            id: "anubias",
            defaultName: "Anubias Bitkisi",
            gphBonus: 9.0,
            cost: 520,
            maxCount: 3,
            sfSymbol: "camera.macro"
        ),
        FloraBonus(
            id: "shrimp",
            defaultName: "Amano Karides",
            gphBonus: 6.0,
            cost: 360,
            maxCount: 8,
            sfSymbol: "circle.grid.2x1.fill"
        ),
        FloraBonus(
            id: "snail",
            defaultName: "Zebra Salyangoz",
            gphBonus: 5.0,
            cost: 320,
            maxCount: 6,
            sfSymbol: "oval.portrait.fill"
        ),
        FloraBonus(
            id: "goby",
            defaultName: "Çöpçü Kaya Balığı",
            gphBonus: 11.0,
            cost: 680,
            maxCount: 3,
            sfSymbol: "fish.fill"
        )
    ]

    public static func getById(_ id: String) -> FloraBonus? {
        allFlora.first(where: { $0.id == id })
    }
}

// MARK: - Simulation Entities: FoodPellet, AmbientBubble, EatParticle, SimulatedFish
public struct FoodPellet: Identifiable, Sendable {
    public let id: UUID
    public var x: Double
    public var y: Double
    public var vy: Double
    public var swayPhase: Double
    public var life: Double
    public var radius: Double { 4.0 }

    public init(
        id: UUID = UUID(),
        x: Double,
        y: Double,
        vy: Double = 36.0,
        swayPhase: Double = 0.0,
        life: Double = 0.0
    ) {
        self.id = id
        self.x = x
        self.y = y
        self.vy = vy
        self.swayPhase = swayPhase
        self.life = life
    }

    public mutating func update(dt: Double, floorY: Double = 800.0) {
        if y < floorY {
            y += vy * dt
            swayPhase += dt * 3.0
            x += sin(swayPhase) * 12.0 * dt
        }
        life += dt
    }

    public var isExpired: Bool {
        life > 14.0
    }
}

public struct AmbientBubble: Identifiable, Sendable {
    public let id: UUID
    public var x: Double
    public var y: Double
    public var radius: Double
    public var speed: Double

    public init(
        id: UUID = UUID(),
        x: Double,
        y: Double,
        radius: Double,
        speed: Double
    ) {
        self.id = id
        self.x = x
        self.y = y
        self.radius = radius
        self.speed = speed
    }

    public mutating func update(dt: Double, screenWidth: Double = 400.0, resetY: Double = 800.0) {
        y -= speed * dt * 0.75
        if y < -10.0 {
            y = resetY
            x = Double.random(in: 0...screenWidth)
        }
    }
}

public struct EatParticle: Identifiable, Sendable {
    public let id: UUID
    public var x: Double
    public var y: Double
    public var life: Double
    public let maxLife: Double
    public let color: Color

    public init(
        id: UUID = UUID(),
        x: Double,
        y: Double,
        maxLife: Double = 1.0,
        color: Color? = nil
    ) {
        self.id = id
        self.x = x
        self.y = y
        self.maxLife = maxLife
        self.life = maxLife
        self.color = color ?? Color(hex: 0xFFFFD54F)
    }

    public var alpha: Double {
        max(0.0, min(1.0, life / maxLife))
    }

    public mutating func update(dt: Double) {
        y -= 25.0 * dt
        life -= dt
    }

    public var isExpired: Bool {
        life <= 0.0
    }
}

public struct SimulatedFish: Identifiable, Sendable {
    public let id: UUID
    public let species: FishSpecies
    public var x: Double
    public var y: Double
    public var vx: Double
    public var vy: Double
    public var pitchAngle: Double
    public var facingRight: Bool
    public var tailPhase: Double
    public var eatCooldown: Double

    public init(
        id: UUID = UUID(),
        species: FishSpecies,
        x: Double,
        y: Double,
        vx: Double,
        vy: Double,
        pitchAngle: Double = 0.0,
        facingRight: Bool = true,
        tailPhase: Double = 0.0,
        eatCooldown: Double = 0.0
    ) {
        self.id = id
        self.species = species
        self.x = x
        self.y = y
        self.vx = vx
        self.vy = vy
        self.pitchAngle = pitchAngle
        self.facingRight = facingRight
        self.tailPhase = tailPhase
        self.eatCooldown = eatCooldown
    }

    public mutating func update(dt: Double, tankWidth: Double = 400.0, tankHeight: Double = 800.0) {
        x += vx * dt
        y += vy * dt
        tailPhase += dt * (vx != 0 ? 8.0 : 4.0)
        eatCooldown = max(0.0, eatCooldown - dt)

        let margin: Double = 24.0 * species.size
        if x < margin {
            x = margin
            vx = abs(vx)
            facingRight = true
        } else if x > tankWidth - margin {
            x = tankWidth - margin
            vx = -abs(vx)
            facingRight = false
        }

        if y < 60.0 {
            y = 60.0
            vy = abs(vy)
        } else if y > tankHeight - 80.0 {
            y = tankHeight - 80.0
            vy = -abs(vy)
        }

        pitchAngle = atan2(vy, abs(vx)) * 0.4
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

// MARK: - Persistent Economy State: AquariumState
public struct AquariumState: Codable, Hashable, Sendable {
    public var unlockedFishIds: [String]
    public var floraCounts: [String: Int]
    public var sandLevel: Int
    public var lastFedTime: Date
    public var lastCollectedTime: Date
    public var accumulatedBank: Double
    public var hasClaimedComebackBonus: Bool

    enum CodingKeys: String, CodingKey {
        case unlockedFishIds
        case floraCounts
        case sandLevel
        case lastFedTime
        case lastCollectedTime
        case accumulatedBank
        case hasClaimedComebackBonus
    }

    public init(
        unlockedFishIds: [String] = ["guppy", "tetra"],
        floraCounts: [String: Int] = ["moss": 2, "kelp": 1, "anubias": 1],
        sandLevel: Int = 1,
        lastFedTime: Date = Date(),
        lastCollectedTime: Date = Date(),
        accumulatedBank: Double = 0.0,
        hasClaimedComebackBonus: Bool = false
    ) {
        self.unlockedFishIds = unlockedFishIds
        self.floraCounts = floraCounts
        self.sandLevel = sandLevel
        self.lastFedTime = lastFedTime
        self.lastCollectedTime = lastCollectedTime
        self.accumulatedBank = accumulatedBank
        self.hasClaimedComebackBonus = hasClaimedComebackBonus
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        unlockedFishIds = try container.decodeIfPresent([String].self, forKey: .unlockedFishIds) ?? ["guppy", "tetra"]
        floraCounts = try container.decodeIfPresent([String: Int].self, forKey: .floraCounts) ?? ["moss": 2, "kelp": 1, "anubias": 1]
        sandLevel = try container.decodeIfPresent(Int.self, forKey: .sandLevel) ?? 1
        lastFedTime = try container.decodeIfPresent(Date.self, forKey: .lastFedTime) ?? Date()
        lastCollectedTime = try container.decodeIfPresent(Date.self, forKey: .lastCollectedTime) ?? Date()
        accumulatedBank = try container.decodeIfPresent(Double.self, forKey: .accumulatedBank) ?? 0.0
        hasClaimedComebackBonus = try container.decodeIfPresent(Bool.self, forKey: .hasClaimedComebackBonus) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(unlockedFishIds, forKey: .unlockedFishIds)
        try container.encode(floraCounts, forKey: .floraCounts)
        try container.encode(sandLevel, forKey: .sandLevel)
        try container.encode(lastFedTime, forKey: .lastFedTime)
        try container.encode(lastCollectedTime, forKey: .lastCollectedTime)
        try container.encode(accumulatedBank, forKey: .accumulatedBank)
        try container.encode(hasClaimedComebackBonus, forKey: .hasClaimedComebackBonus)
    }

    /// Fish remain full and productive for 4 hours
    public func isHungry(at date: Date = Date()) -> Bool {
        date.timeIntervalSince(lastFedTime) >= 4.0 * 3600.0
    }

    public var isFishHungry: Bool {
        isHungry(at: Date())
    }

    /// Hunger progression from 0.0 (just fed) to 1.0 (hungry)
    public func hungerProgress(at date: Date = Date()) -> Double {
        let elapsed = max(0.0, date.timeIntervalSince(lastFedTime))
        return min(1.0, elapsed / (4.0 * 3600.0))
    }

    public var hungerProgress: Double {
        hungerProgress(at: Date())
    }

    /// Remaining time until hunger in seconds
    public func remainingFullSeconds(at date: Date = Date()) -> TimeInterval {
        max(0.0, (4.0 * 3600.0) - date.timeIntervalSince(lastFedTime))
    }

    public var remainingFullSeconds: TimeInterval {
        remainingFullSeconds(at: Date())
    }

    /// True if fish are currently fed and actively producing (elapsed < 4 hours)
    public var isFed: Bool {
        remainingFullSeconds > 0
    }

    /// Total hourly generation rate
    public func totalGPH(speciesList: [FishSpecies] = FishSpecies.allSpecies) -> Double {
        let baseRate = 1.5
        let fishGPH = unlockedFishIds.reduce(0.0) { sum, id in
            let species = speciesList.first(where: { $0.id == id }) ?? FishSpecies.getById(id)
            return sum + species.passiveGPH
        }
        let floraGPH = floraCounts.reduce(0.0) { sum, pair in
            let bonus = FloraBonus.getById(pair.key)?.gphBonus ?? 0.0
            return sum + bonus * Double(pair.value)
        }
        let capacityMultiplier = max(1.0, Double(sandLevel))
        return (baseRate + fishGPH + floraGPH) * capacityMultiplier
    }

    /// Offline calculation:
    /// - Caps generation to 4 hours of production if hungry without feeding.
    /// - Grants +20 comeback bonus if away >= 4h.
    /// - Hard cap of 8 hours max under all conditions.
    public func calculateOfflineGains(now: Date = Date()) -> (gold: Int, comebackBonus: Int, effectiveHours: Double) {
        let elapsedSeconds = max(0.0, now.timeIntervalSince(lastCollectedTime))
        let elapsedHours = elapsedSeconds / 3600.0

        let fedElapsedHours = max(0.0, now.timeIntervalSince(lastFedTime)) / 3600.0
        let productionAllowedHours: Double
        if fedElapsedHours >= 4.0 {
            let hoursUntilHungry = max(0.0, 4.0 - (lastCollectedTime.timeIntervalSince(lastFedTime) / 3600.0))
            productionAllowedHours = min(hoursUntilHungry, elapsedHours)
        } else {
            productionAllowedHours = min(elapsedHours, 4.0 - fedElapsedHours + elapsedHours)
        }

        let effectiveHours = min(8.0, max(0.0, min(elapsedHours, productionAllowedHours)))
        let gph = totalGPH()
        let generated = Int(floor(accumulatedBank + effectiveHours * gph))

        let comebackBonus = (fedElapsedHours >= 4.0 && !hasClaimedComebackBonus) ? 20 : 0
        return (gold: generated, comebackBonus: comebackBonus, effectiveHours: effectiveHours)
    }

    /// Feed action: restarts 4-hour cycle and returns whether fish were hungry
    public mutating func feed(now: Date = Date()) -> Bool {
        let wasHungry = isHungry(at: now)
        let gains = calculateOfflineGains(now: now)
        accumulatedBank = Double(gains.gold)
        lastCollectedTime = now
        lastFedTime = now
        hasClaimedComebackBonus = false
        return wasHungry
    }

    /// Harvest action: claims gold, resets bank and updates lastCollectedTime
    public mutating func harvest(now: Date = Date()) -> Int {
        let gains = calculateOfflineGains(now: now)
        let total = gains.gold + gains.comebackBonus
        accumulatedBank = 0.0
        lastCollectedTime = now
        if gains.comebackBonus > 0 {
            hasClaimedComebackBonus = true
        }
        return total
    }
}
