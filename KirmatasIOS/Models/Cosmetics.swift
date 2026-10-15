import SwiftUI
import Foundation

// MARK: - Rarity
public enum Rarity: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case common
    case rare
    case epic
    case legendary

    public var id: String { rawValue }
    public var labelKey: String { rawValue }

    public var defaultLabel: String {
        switch self {
        case .common: return "Yaygın"
        case .rare: return "Nadir"
        case .epic: return "Destansı"
        case .legendary: return "Efsanevi"
        }
    }

    public var localizedLabel: String {
        I18n.name(defaultLabel)
    }

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

    public var primaryColor: Color {
        switch self {
        case .common: return Color(hex: 0xFF90A4AE)
        case .rare: return Color(hex: 0xFF40C4FF)
        case .epic: return Color(hex: 0xFFE040FB)
        case .legendary: return Color(hex: 0xFFFFD54F)
        }
    }

    public var darkColor: Color {
        switch self {
        case .common: return Color(hex: 0xFF37474F)
        case .rare: return Color(hex: 0xFF0277BD)
        case .epic: return Color(hex: 0xFF7B1FA2)
        case .legendary: return Color(hex: 0xFFFF8F00)
        }
    }
}

// MARK: - Crate Drop Type
public enum CrateDropType: String, CaseIterable, Codable, Sendable {
    case fish
    case ball
    case paddle
    case trail
}

// MARK: - Crate Item
public struct CrateItem: Identifiable, Hashable, Sendable {
    public let id: String
    public let nameKey: String
    public let defaultName: String
    public let cost: Int
    public let tier: Rarity
    public let primaryColor: Color
    public let weights: [Rarity: Double]

    public var name: String {
        let tr = I18n.tr(nameKey)
        return tr != nameKey ? tr : I18n.name(defaultName)
    }

    public init(
        id: String,
        nameKey: String? = nil,
        defaultName: String,
        cost: Int,
        tier: Rarity,
        primaryColor: Color,
        weights: [Rarity: Double]
    ) {
        self.id = id
        self.nameKey = nameKey ?? "crate_\(id)"
        self.defaultName = defaultName
        self.cost = cost
        self.tier = tier
        self.primaryColor = primaryColor
        self.weights = weights
    }

    /// Roll rarity taking player luck upgrade level (0...3) into account
    public func rollRarity(luckLevel: Int) -> Rarity {
        var adjusted = weights
        let luck = max(0, luckLevel)
        if let leg = adjusted[.legendary] {
            adjusted[.legendary] = leg * (1.0 + Double(luck) * 0.35)
        }
        if let ep = adjusted[.epic] {
            adjusted[.epic] = ep * (1.0 + Double(luck) * 0.25)
        }

        let total = adjusted.values.reduce(0.0, +)
        guard total > 0 else { return .common }

        var roll = Double.random(in: 0.0..<total)
        for r in [Rarity.legendary, .epic, .rare, .common] {
            if let w = adjusted[r] {
                if roll < w { return r }
                roll -= w
            }
        }
        return .common
    }

    public static let wood = CrateItem(
        id: "wood",
        nameKey: "crate_wood",
        defaultName: "Ahşap Sandık",
        cost: 900,
        tier: .common,
        primaryColor: Color(hex: 0xFF8D6E63),
        weights: [.common: 70.0, .rare: 25.0, .epic: 5.0, .legendary: 0.0]
    )

    public static let coral = CrateItem(
        id: "coral",
        nameKey: "crate_coral",
        defaultName: "Mercan Sandığı",
        cost: 1800,
        tier: .rare,
        primaryColor: Color(hex: 0xFF00BCD4),
        weights: [.common: 42.0, .rare: 38.0, .epic: 17.0, .legendary: 3.0]
    )

    public static let abyss = CrateItem(
        id: "abyss",
        nameKey: "crate_abyss",
        defaultName: "Derinlik Sandığı",
        cost: 3200,
        tier: .legendary,
        primaryColor: Color(hex: 0xFF7C4DFF),
        weights: [.common: 12.0, .rare: 38.0, .epic: 38.0, .legendary: 12.0]
    )

    public static let allCrates: [CrateItem] = [.wood, .coral, .abyss]
}

// MARK: - 12 Ball Skins
public struct BallSkinItem: Identifiable, Hashable, Sendable {
    public let id: String
    public let nameKey: String
    public let defaultName: String
    public let cost: Int
    public let rarity: Rarity
    public let mainColor: Color
    public let glowColor: Color
    public let darkColor: Color
    public let hasAura: Bool
    public let isRainbow: Bool

    public var name: String {
        let tr = I18n.tr(nameKey)
        return tr != nameKey ? tr : I18n.name(defaultName)
    }

    public init(
        id: String,
        nameKey: String? = nil,
        defaultName: String,
        cost: Int,
        rarity: Rarity,
        mainColor: Color,
        glowColor: Color,
        darkColor: Color,
        hasAura: Bool = false,
        isRainbow: Bool = false
    ) {
        self.id = id
        self.nameKey = nameKey ?? "ball_\(id)"
        self.defaultName = defaultName
        self.cost = cost
        self.rarity = rarity
        self.mainColor = mainColor
        self.glowColor = glowColor
        self.darkColor = darkColor
        self.hasAura = hasAura
        self.isRainbow = isRainbow
    }

    /// Dynamic ROYGBIV spectrum calculation for Rainbow Ball
    public func currentMainColor(time: Double) -> Color {
        guard isRainbow else { return mainColor }
        let hue = (time * 120.0).truncatingRemainder(dividingBy: 360.0) / 360.0
        return Color(hue: hue < 0 ? hue + 1.0 : hue, saturation: 0.9, brightness: 1.0)
    }

    public func currentGlowColor(time: Double) -> Color {
        guard isRainbow else { return glowColor }
        let hue = (time * 120.0 + 40.0).truncatingRemainder(dividingBy: 360.0) / 360.0
        return Color(hue: hue < 0 ? hue + 1.0 : hue, saturation: 0.8, brightness: 1.0)
    }

    public static let allSkins: [BallSkinItem] = [
        BallSkinItem(
            id: "classic",
            defaultName: "Klasik Beyaz",
            cost: 0,
            rarity: .common,
            mainColor: .white,
            glowColor: Color(hex: 0xCCFFFFFF),
            darkColor: Color(hex: 0xFF90A4AE),
            hasAura: false
        ),
        BallSkinItem(
            id: "pembe",
            defaultName: "Neon Pembe",
            cost: 1500,
            rarity: .rare,
            mainColor: Color(hex: 0xFFFF7EB3),
            glowColor: Color(hex: 0xFFAA147B),
            darkColor: Color(hex: 0xFFAD1457),
            hasAura: true
        ),
        BallSkinItem(
            id: "plazma",
            defaultName: "Plazma Mavi",
            cost: 1800,
            rarity: .rare,
            mainColor: Color(hex: 0xFF40C4FF),
            glowColor: Color(hex: 0xE640C4FF),
            darkColor: Color(hex: 0xFF01579B),
            hasAura: true
        ),
        BallSkinItem(
            id: "zumrut",
            defaultName: "Zümrüt Yeşil",
            cost: 2000,
            rarity: .rare,
            mainColor: Color(hex: 0xFF69F0AE),
            glowColor: Color(hex: 0xE669F0AE),
            darkColor: Color(hex: 0xFF1B5E20),
            hasAura: false
        ),
        BallSkinItem(
            id: "golge",
            defaultName: "Gölge Mor",
            cost: 2400,
            rarity: .epic,
            mainColor: Color(hex: 0xFFB388FF),
            glowColor: Color(hex: 0xE6B388FF),
            darkColor: Color(hex: 0xFF311B92),
            hasAura: false
        ),
        BallSkinItem(
            id: "ates",
            defaultName: "Ateş Topu",
            cost: 2800,
            rarity: .epic,
            mainColor: Color(hex: 0xFFFF6D00),
            glowColor: Color(hex: 0xE6FF6D00),
            darkColor: Color(hex: 0xFFBF360C),
            hasAura: true
        ),
        BallSkinItem(
            id: "isilti",
            defaultName: "Yıldız Işıltısı",
            cost: 3200,
            rarity: .legendary,
            mainColor: Color(hex: 0xFFFFD54F),
            glowColor: Color(hex: 0xE6FFD54F),
            darkColor: Color(hex: 0xFFF57F17),
            hasAura: true
        ),
        BallSkinItem(
            id: "altin",
            defaultName: "Saf Altın",
            cost: 4500,
            rarity: .legendary,
            mainColor: Color(hex: 0xFFFFEA00),
            glowColor: Color(hex: 0xFFFFD600),
            darkColor: Color(hex: 0xFFFF8F00),
            hasAura: true
        ),
        BallSkinItem(
            id: "rainbow",
            defaultName: "Gökkuşağı",
            cost: 5000,
            rarity: .legendary,
            mainColor: Color(hex: 0xFFFF007F),
            glowColor: Color(hex: 0xFF00E5FF),
            darkColor: Color(hex: 0xFF311B92),
            hasAura: true,
            isRainbow: true
        ),
        BallSkinItem(
            id: "neonpink",
            defaultName: "Siber Fuşya",
            cost: 2600,
            rarity: .epic,
            mainColor: Color(hex: 0xFFFF2BD6),
            glowColor: Color(hex: 0xFF880E4F),
            darkColor: Color(hex: 0xFF880E4F),
            hasAura: true
        ),
        BallSkinItem(
            id: "neoncyan",
            defaultName: "Siber Turkuaz",
            cost: 2600,
            rarity: .epic,
            mainColor: Color(hex: 0xFF18FFFF),
            glowColor: Color(hex: 0xFF006064),
            darkColor: Color(hex: 0xFF006064),
            hasAura: true
        ),
        BallSkinItem(
            id: "ghost",
            defaultName: "Hayalet Küre",
            cost: 3000,
            rarity: .epic,
            mainColor: Color(hex: 0xFFE0F7FA),
            glowColor: Color(hex: 0xFF4DD0E1),
            darkColor: Color(hex: 0xFF4DD0E1),
            hasAura: true
        )
    ]
}

// MARK: - 6 Paddle Skins
public struct PaddleSkinItem: Identifiable, Hashable, Sendable {
    public let id: String
    public let nameKey: String
    public let defaultName: String
    public let cost: Int
    public let rarity: Rarity
    public let color1: Color
    public let color2: Color
    public let glowColor: Color

    public var name: String {
        let tr = I18n.tr(nameKey)
        return tr != nameKey ? tr : I18n.name(defaultName)
    }

    public init(
        id: String,
        nameKey: String? = nil,
        defaultName: String,
        cost: Int,
        rarity: Rarity,
        color1: Color,
        color2: Color,
        glowColor: Color
    ) {
        self.id = id
        self.nameKey = nameKey ?? "paddle_\(id)"
        self.defaultName = defaultName
        self.cost = cost
        self.rarity = rarity
        self.color1 = color1
        self.color2 = color2
        self.glowColor = glowColor
    }

    public static let allSkins: [PaddleSkinItem] = [
        PaddleSkinItem(
            id: "pclassic",
            defaultName: "Siber Klasik",
            cost: 0,
            rarity: .common,
            color1: Color(hex: 0xFF40C4FF),
            color2: Color(hex: 0xFF7C4DFF),
            glowColor: Color(hex: 0x6640C4FF)
        ),
        PaddleSkinItem(
            id: "ppink",
            defaultName: "Neon Pembe",
            cost: 1800,
            rarity: .rare,
            color1: Color(hex: 0xFFFF80AB),
            color2: Color(hex: 0xFFC2185B),
            glowColor: Color(hex: 0x80FF80AB)
        ),
        PaddleSkinItem(
            id: "pice",
            defaultName: "Buzul Kristali",
            cost: 2400,
            rarity: .rare,
            color1: Color(hex: 0xFFE0F7FA),
            color2: Color(hex: 0xFF00ACC1),
            glowColor: Color(hex: 0x66B2EBF2)
        ),
        PaddleSkinItem(
            id: "pbat",
            defaultName: "Gece Yarasa",
            cost: 2800,
            rarity: .epic,
            color1: Color(hex: 0xFFFF5252),
            color2: Color(hex: 0xFF212121),
            glowColor: Color(hex: 0x80FF5252)
        ),
        PaddleSkinItem(
            id: "pcyber",
            defaultName: "Siberpunk 2099",
            cost: 3200,
            rarity: .epic,
            color1: Color(hex: 0xFF00E5FF),
            color2: Color(hex: 0xFFD500F9),
            glowColor: Color(hex: 0x9900E5FF)
        ),
        PaddleSkinItem(
            id: "pgold",
            defaultName: "Kraliyet Altını",
            cost: 4200,
            rarity: .legendary,
            color1: Color(hex: 0xFFFFE082),
            color2: Color(hex: 0xFFFF8F00),
            glowColor: Color(hex: 0x99FFD54F)
        )
    ]
}

// MARK: - 6 Trail Skins & TrailStyle Enum
public enum TrailStyle: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case dot
    case spark
    case fire
    case rainbow
    case plasma
    case ghost

    public var id: String { rawValue }
}

public struct TrailSkinItem: Identifiable, Hashable, Sendable {
    public let id: String
    public let nameKey: String
    public let defaultName: String
    public let cost: Int
    public let rarity: Rarity
    public let style: TrailStyle
    public let length: Int

    public var name: String {
        let tr = I18n.tr(nameKey)
        return tr != nameKey ? tr : I18n.name(defaultName)
    }

    public init(
        id: String,
        nameKey: String? = nil,
        defaultName: String,
        cost: Int,
        rarity: Rarity,
        style: TrailStyle,
        length: Int
    ) {
        self.id = id
        self.nameKey = nameKey ?? "trail_\(id)"
        self.defaultName = defaultName
        self.cost = cost
        self.rarity = rarity
        self.style = style
        self.length = length
    }

    public static let allTrails: [TrailSkinItem] = [
        TrailSkinItem(
            id: "t1",
            defaultName: "Kısa İz",
            cost: 0,
            rarity: .common,
            style: .dot,
            length: 6
        ),
        TrailSkinItem(
            id: "t2",
            defaultName: "Neon Kuyruk",
            cost: 1600,
            rarity: .rare,
            style: .dot,
            length: 16
        ),
        TrailSkinItem(
            id: "spark",
            defaultName: "Kıvılcım İzi",
            cost: 2200,
            rarity: .rare,
            style: .spark,
            length: 22
        ),
        TrailSkinItem(
            id: "fire",
            defaultName: "Alev İzi",
            cost: 2800,
            rarity: .epic,
            style: .fire,
            length: 26
        ),
        TrailSkinItem(
            id: "rainbow",
            defaultName: "Gökkuşağı İzi",
            cost: 3400,
            rarity: .epic,
            style: .rainbow,
            length: 28
        ),
        TrailSkinItem(
            id: "plasma",
            defaultName: "Kozmik Plazma",
            cost: 4200,
            rarity: .legendary,
            style: .plasma,
            length: 32
        )
    ]
}

// MARK: - 6 Brick Skins & BrickStyleType Enum
public enum BrickStyleType: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case classic
    case magma
    case ice
    case candy
    case cyber
    case gold

    public var id: String { rawValue }
}

public struct BrickSkinItem: Identifiable, Hashable, Sendable {
    public let id: String
    public let nameKey: String
    public let defaultName: String
    public let cost: Int
    public let rarity: Rarity
    public let style: BrickStyleType
    public let primaryColor: Color
    public let accentColor: Color
    public let descriptionText: String

    public var name: String {
        let tr = I18n.tr(nameKey)
        return tr != nameKey ? tr : I18n.name(defaultName)
    }

    public init(
        id: String,
        nameKey: String? = nil,
        defaultName: String,
        cost: Int,
        rarity: Rarity,
        style: BrickStyleType,
        primaryColor: Color,
        accentColor: Color,
        descriptionText: String
    ) {
        self.id = id
        self.nameKey = nameKey ?? "brick_\(id)"
        self.defaultName = defaultName
        self.cost = cost
        self.rarity = rarity
        self.style = style
        self.primaryColor = primaryColor
        self.accentColor = accentColor
        self.descriptionText = descriptionText
    }

    public static let allBricks: [BrickSkinItem] = [
        BrickSkinItem(
            id: "brick_classic",
            defaultName: "Klasik Kristal",
            cost: 0,
            rarity: .common,
            style: .classic,
            primaryColor: Color(hex: 0xFF4FC3F7),
            accentColor: Color(hex: 0xFF0288D1),
            descriptionText: "Klasik prizmatik kristal tuğla kenarları"
        ),
        BrickSkinItem(
            id: "brick_magma",
            defaultName: "Lav Taşları",
            cost: 1800,
            rarity: .rare,
            style: .magma,
            primaryColor: Color(hex: 0xFFFF5722),
            accentColor: Color(hex: 0xFFBF360C),
            descriptionText: "Obsidyen çerçeve ve erimiş magma çekirdek"
        ),
        BrickSkinItem(
            id: "brick_ice",
            defaultName: "Buz Bloğu",
            cost: 1800,
            rarity: .rare,
            style: .ice,
            primaryColor: Color(hex: 0xFFE0F7FA),
            accentColor: Color(hex: 0xFF00BCD4),
            descriptionText: "Saydam buzul kristalleri ve elmas pırıltısı"
        ),
        BrickSkinItem(
            id: "brick_candy",
            defaultName: "Şeker Neon",
            cost: 2200,
            rarity: .rare,
            style: .candy,
            primaryColor: Color(hex: 0xFFFF4081),
            accentColor: Color(hex: 0xFF7C4DFF),
            descriptionText: "Canlı neon pembe ve mor parlak şeker cilası"
        ),
        BrickSkinItem(
            id: "brick_cyber",
            defaultName: "Siber Devre",
            cost: 2500,
            rarity: .epic,
            style: .cyber,
            primaryColor: Color(hex: 0xFF00E5FF),
            accentColor: Color(hex: 0xFF1DE9B6),
            descriptionText: "Işıldayan enerji hatları ve baskılı devre yolları"
        ),
        BrickSkinItem(
            id: "brick_gold",
            defaultName: "Altın Külçe",
            cost: 3500,
            rarity: .legendary,
            style: .gold,
            primaryColor: Color(hex: 0xFFFFD54F),
            accentColor: Color(hex: 0xFFFF8F00),
            descriptionText: "Yansıtıcı saf altın kaplama ve perçinli köşeler"
        )
    ]
}

// MARK: - 6 Background Themes
public struct BackgroundThemeItem: Identifiable, Hashable, Sendable {
    public let id: String
    public let nameKey: String
    public let descKey: String
    public let defaultName: String
    public let defaultDesc: String
    public let cost: Int
    public let sfSymbol: String
    public let primaryColor: Color
    public let secondaryColor: Color
    public let accentColor: Color

    public var name: String {
        let tr = I18n.tr(nameKey)
        return tr != nameKey ? tr : I18n.name(defaultName)
    }

    public var description: String {
        let tr = I18n.tr(descKey)
        return tr != descKey ? tr : I18n.name(defaultDesc)
    }

    public var tier: Rarity {
        cost >= 2000 ? .epic : .rare
    }

    public init(
        id: String,
        nameKey: String? = nil,
        descKey: String? = nil,
        defaultName: String,
        defaultDesc: String,
        cost: Int,
        sfSymbol: String,
        primaryColor: Color,
        secondaryColor: Color,
        accentColor: Color
    ) {
        self.id = id
        self.nameKey = nameKey ?? id
        self.descKey = descKey ?? "\(id)_desc"
        self.defaultName = defaultName
        self.defaultDesc = defaultDesc
        self.cost = cost
        self.sfSymbol = sfSymbol
        self.primaryColor = primaryColor
        self.secondaryColor = secondaryColor
        self.accentColor = accentColor
    }

    public static let allThemes: [BackgroundThemeItem] = [
        BackgroundThemeItem(
            id: "bg_default",
            defaultName: "Kozmik Yıldızlar",
            defaultDesc: "Klasik derin uzay ve yıldız akışı",
            cost: 0,
            sfSymbol: "sparkles",
            primaryColor: Color(hex: 0xFF0D1B2A),
            secondaryColor: Color(hex: 0xFF1B263B),
            accentColor: Color(hex: 0xFF415A77)
        ),
        BackgroundThemeItem(
            id: "bg_nebula",
            defaultName: "Mor Bulutsu",
            defaultDesc: "Işıldayan kozmik yıldız tozu bulutları",
            cost: 2000,
            sfSymbol: "cloud.sun.fill",
            primaryColor: Color(hex: 0xFF1A0B2E),
            secondaryColor: Color(hex: 0xFF2E1065),
            accentColor: Color(hex: 0xFFC084FC)
        ),
        BackgroundThemeItem(
            id: "bg_matrix",
            defaultName: "Siber Izgara",
            defaultDesc: "Neon synthwave ufuk matrisi",
            cost: 2000,
            sfSymbol: "grid",
            primaryColor: Color(hex: 0xFF030712),
            secondaryColor: Color(hex: 0xFF022C22),
            accentColor: Color(hex: 0xFF10B981)
        ),
        BackgroundThemeItem(
            id: "bg_abyss",
            defaultName: "Derin Okyanus",
            defaultDesc: "Biyolüminesan derin deniz akıntısı",
            cost: 2000,
            sfSymbol: "water.waves",
            primaryColor: Color(hex: 0xFF020E1C),
            secondaryColor: Color(hex: 0xFF03254C),
            accentColor: Color(hex: 0xFF00E5FF)
        ),
        BackgroundThemeItem(
            id: "bg_sunset",
            defaultName: "Retro Gün Batımı",
            defaultDesc: "Vaporwave ufku ve sıcak kıvılcımlar",
            cost: 2000,
            sfSymbol: "sunset.fill",
            primaryColor: Color(hex: 0xFF1E0B24),
            secondaryColor: Color(hex: 0xFF3B0764),
            accentColor: Color(hex: 0xFFFF5376)
        ),
        BackgroundThemeItem(
            id: "bg_inferno",
            defaultName: "Güneş Cehennemi",
            defaultDesc: "Volkanik kehribar güneş rüzgarı korları",
            cost: 2000,
            sfSymbol: "flame.fill",
            primaryColor: Color(hex: 0xFF1A0800),
            secondaryColor: Color(hex: 0xFF431407),
            accentColor: Color(hex: 0xFFFF7A00)
        )
    ]
}

// MARK: - 3 Permanent Upgrades & 3 Pre-Match Boosts
public struct UpgradeDefItem: Identifiable, Hashable, Sendable {
    public let id: String
    public let titleKey: String
    public let descKey: String
    public let defaultTitle: String
    public let defaultDesc: String
    public let sfSymbol: String
    public let maxLevel: Int
    public let costs: [Int]

    public var title: String {
        let tr = I18n.tr(titleKey)
        return tr != titleKey ? tr : I18n.name(defaultTitle)
    }

    public var name: String { title }

    public var description: String {
        let tr = I18n.tr(descKey)
        return tr != descKey ? tr : I18n.name(defaultDesc)
    }

    public func isMaxLevel(currentLevel: Int) -> Bool {
        currentLevel >= maxLevel
    }

    public func costForNextLevel(currentLevel: Int) -> Int? {
        guard currentLevel >= 0 && currentLevel < maxLevel && currentLevel < costs.count else {
            return nil
        }
        return costs[currentLevel]
    }

    public static let allUpgrades: [UpgradeDefItem] = [
        UpgradeDefItem(
            id: "battery",
            titleKey: "battery_title",
            descKey: "battery_desc",
            defaultTitle: "Kozmik Batarya",
            defaultDesc: "Ulti göstergesi her seviyede %25 daha hızlı dolar.",
            sfSymbol: "bolt.fill",
            maxLevel: 3,
            costs: [900, 1800, 3200]
        ),
        UpgradeDefItem(
            id: "magnet",
            titleKey: "magnet_title",
            descKey: "magnet_desc",
            defaultTitle: "Plazma Mıknatısı",
            defaultDesc: "Düşen güçlendirmeleri 220px mesafeden rakete çeker.",
            sfSymbol: "sensor.radiowaves.forward.fill",
            maxLevel: 3,
            costs: [1100, 2100, 3600]
        ),
        UpgradeDefItem(
            id: "luck",
            titleKey: "luck_title",
            descKey: "luck_desc",
            defaultTitle: "Şans Yıldızı",
            defaultDesc: "Sandıklardan efsanevi eşya ve oyunda pozitif buff çıkma şansını artırır.",
            sfSymbol: "star.fill",
            maxLevel: 3,
            costs: [1400, 2600, 4200]
        )
    ]
}

public struct BoostItemDef: Identifiable, Hashable, Sendable {
    public let id: String
    public let titleKey: String
    public let descKey: String
    public let defaultTitle: String
    public let defaultDesc: String
    public let cost: Int
    public let maxStock: Int
    public let color: Color
    public let sfSymbol: String

    public var title: String {
        let tr = I18n.tr(titleKey)
        return tr != titleKey ? tr : I18n.name(defaultTitle)
    }

    public var name: String { title }

    public var description: String {
        let tr = I18n.tr(descKey)
        return tr != descKey ? tr : I18n.name(defaultDesc)
    }

    public static let allBoosts: [BoostItemDef] = [
        BoostItemDef(
            id: "life",
            titleKey: "life_boost_title",
            descKey: "life_boost_desc",
            defaultTitle: "+1 Ekstra Can",
            defaultDesc: "Maça 1 fazladan can ile başlayın (3 yerine 4 can).",
            cost: 900,
            maxStock: 20,
            color: Color(hex: 0xFFFF5252),
            sfSymbol: "heart.fill"
        ),
        BoostItemDef(
            id: "wide",
            titleKey: "wide_boost_title",
            descKey: "wide_boost_desc",
            defaultTitle: "Geniş Raket",
            defaultDesc: "Maça doğrudan genişletilmiş raket ile başlayın.",
            cost: 1100,
            maxStock: 20,
            color: Color(hex: 0xFF40C4FF),
            sfSymbol: "arrow.left.and.right"
        ),
        BoostItemDef(
            id: "multi",
            titleKey: "multi_boost_title",
            descKey: "multi_boost_desc",
            defaultTitle: "Çoklu Başlangıç",
            defaultDesc: "Maça tek top yerine 3 topla aynı anda başlayın.",
            cost: 1700,
            maxStock: 20,
            color: Color(hex: 0xFFFF9800),
            sfSymbol: "circle.grid.cross.fill"
        )
    ]
}

// MARK: - Crate Drop Result
public struct CrateDropResult: Identifiable, Sendable {
    public var id: String { itemIdentifier }
    public let itemIdentifier: String
    public let name: String
    public let rarity: Rarity
    public let type: CrateDropType
    public let isDuplicate: Bool
    public let refundGold: Int

    public init(
        itemIdentifier: String,
        name: String,
        rarity: Rarity,
        type: CrateDropType,
        isDuplicate: Bool,
        refundGold: Int
    ) {
        self.itemIdentifier = itemIdentifier
        self.name = name
        self.rarity = rarity
        self.type = type
        self.isDuplicate = isDuplicate
        self.refundGold = refundGold
    }
}

// MARK: - Cosmetics Registry
public enum Cosmetics {
    public static var allCrates: [CrateItem] { CrateItem.allCrates }
    public static var allBallSkins: [BallSkinItem] { BallSkinItem.allSkins }
    public static var allPaddleSkins: [PaddleSkinItem] { PaddleSkinItem.allSkins }
    public static var allTrailSkins: [TrailSkinItem] { TrailSkinItem.allTrails }
    public static var allBrickSkins: [BrickSkinItem] { BrickSkinItem.allBricks }
    public static var allBackgroundThemes: [BackgroundThemeItem] { BackgroundThemeItem.allThemes }
    public static var allUpgrades: [UpgradeDefItem] { UpgradeDefItem.allUpgrades }
    public static var allBoosts: [BoostItemDef] { BoostItemDef.allBoosts }

    public static func crate(byId id: String) -> CrateItem {
        allCrates.first(where: { $0.id == id }) ?? .wood
    }

    public static func ballSkin(byId id: String) -> BallSkinItem {
        if let found = allBallSkins.first(where: { $0.id == id }) {
            return found
        }
        // Aliases for upstream compatibility
        switch id {
        case "cyber": return ballSkin(byId: "neonpink")
        case "void": return ballSkin(byId: "golge")
        case "supernova": return ballSkin(byId: "altin")
        default: return allBallSkins[0]
        }
    }

    public static func paddleSkin(byId id: String) -> PaddleSkinItem {
        allPaddleSkins.first(where: { $0.id == id }) ?? allPaddleSkins[0]
    }

    public static func trailSkin(byId id: String) -> TrailSkinItem {
        allTrailSkins.first(where: { $0.id == id }) ?? allTrailSkins[0]
    }

    public static func brickSkin(byId id: String) -> BrickSkinItem {
        if let found = allBrickSkins.first(where: { $0.id == id }) {
            return found
        }
        // Aliases
        switch id {
        case "b_classic": return brickSkin(byId: "brick_classic")
        case "b_neon": return brickSkin(byId: "brick_candy")
        case "b_crystal": return brickSkin(byId: "brick_ice")
        case "b_obsidian": return brickSkin(byId: "brick_magma")
        case "b_cyber": return brickSkin(byId: "brick_cyber")
        case "b_gold": return brickSkin(byId: "brick_gold")
        default: return allBrickSkins[0]
        }
    }

    public static func backgroundTheme(byId id: String) -> BackgroundThemeItem {
        allBackgroundThemes.first(where: { $0.id == id }) ?? allBackgroundThemes[0]
    }

    public static func upgrade(byId id: String) -> UpgradeDefItem? {
        allUpgrades.first(where: { $0.id == id })
    }

    public static func boost(byId id: String) -> BoostItemDef? {
        allBoosts.first(where: { $0.id == id })
    }

    public static func duplicateCompensation(for type: CrateDropType) -> Int {
        switch type {
        case .fish: return Int.random(in: 120...280)
        case .ball: return Int.random(in: 120...270)
        case .paddle: return Int.random(in: 150...330)
        case .trail: return Int.random(in: 100...220)
        }
    }

    public static func rainbowHue(gameTime: Double) -> Double {
        (gameTime * 120.0).truncatingRemainder(dividingBy: 360.0)
    }
}
