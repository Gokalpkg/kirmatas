import SwiftUI

public enum ShopTab: String, CaseIterable, Identifiable {
    case crates = "crates"
    case balls = "balls"
    case paddles = "paddles"
    case trails = "trails"
    case bricks = "bricks"
    case backgrounds = "backgrounds"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .crates: return I18n.pick("SANDIK", "CRATES")
        case .balls: return I18n.pick("TOP", "BALLS")
        case .paddles: return I18n.pick("RAKET", "PADDLES")
        case .trails: return I18n.pick("İZ", "TRAILS")
        case .bricks: return I18n.pick("TUĞLA", "BRICKS")
        case .backgrounds: return I18n.pick("TEMA", "THEMES")
        }
    }

    public var sfIcon: String {
        switch self {
        case .crates: return "cube.box.fill"
        case .balls: return "circle.fill"
        case .paddles: return "capsule.portrait.fill"
        case .trails: return "sparkles"
        case .bricks: return "square.grid.2x2.fill"
        case .backgrounds: return "mountain.2.fill"
        }
    }
}

public struct ShopView: View {
    @ObservedObject private var save = SaveManager.shared
    @Environment(\.presentationMode) private var presentationMode

    @State private var selectedTab: ShopTab = .crates
    @State private var openedCrateResult: CrateDropResult?
    @State private var isOpeningCrate: Bool = false
    @State private var crateBeingOpened: CrateItem?
    @State private var showInsufficientGoldToast: Bool = false

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    public init() {}

    public var body: some View {
        ZStack {
            // Background
            RadialGradient(
                gradient: Gradient(colors: [
                    Color(hex: 0xFF161F30),
                    Color(hex: 0xFF0B0F19),
                    Color(hex: 0xFF04060A)
                ]),
                center: .top,
                startRadius: 50,
                endRadius: 750
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top Header
                headerView
                    .padding(.horizontal, 18)
                    .padding(.top, 10)
                    .padding(.bottom, 12)

                // Tab Selector
                tabSelectorBar
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)

                // Main Content Body
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        switch selectedTab {
                        case .crates:
                            cratesSection
                        case .balls:
                            ballsSection
                        case .paddles:
                            paddlesSection
                        case .trails:
                            trailsSection
                        case .bricks:
                            bricksSection
                        case .backgrounds:
                            backgroundsSection
                        }

                        // Upgrades & Boosts Footer Section
                        upgradesAndBoostsSection
                            .padding(.top, 10)
                            .padding(.bottom, 36)
                    }
                    .padding(.horizontal, 18)
                }
            }

            // Toast for insufficient gold
            if showInsufficientGoldToast {
                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(Color(hex: 0xFFFF5252))
                        Text(I18n.pick("Yetersiz Altın!", "Not Enough Gold!"))
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color(hex: 0xFF1C131D).opacity(0.95))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color(hex: 0xFFFF5252).opacity(0.6), lineWidth: 1.5))
                    .shadow(color: Color(hex: 0xFFFF5252).opacity(0.35), radius: 14, y: 4)
                    .padding(.bottom, 28)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Crate Opening Modal
            if let result = openedCrateResult, let crate = crateBeingOpened {
                CrateOpeningOverlay(
                    crate: crate,
                    result: result,
                    onDismiss: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            openedCrateResult = nil
                            crateBeingOpened = nil
                            isOpeningCrate = false
                        }
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
    }

    // MARK: - Header
    private var headerView: some View {
        HStack(spacing: 12) {
            Button {
                AudioManager.shared.playSfx(.click)
                presentationMode.wrappedValue.dismiss()
            } label: {
                Image(systemName: "chevron.backward")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }

            Text(I18n.pick("MARKET", "SHOP"))
                .font(.system(size: 26, weight: .black, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, Color(hex: 0xFFECEFF1)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            Spacer()

            // Gold Balance Capsule
            HStack(spacing: 6) {
                PixelCoin(size: 18)
                Text("\(save.gold)")
                    .font(.system(size: 17, weight: .black, design: .monospaced))
                    .foregroundStyle(Color(hex: 0xFFFFD54F))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Color(hex: 0xFF101320).opacity(0.85))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color(hex: 0xFFFFD54F).opacity(0.4), lineWidth: 1.2))
        }
    }

    // MARK: - Tab Selector Bar
    private var tabSelectorBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ShopTab.allCases) { tab in
                    let isSelected = selectedTab == tab
                    Button {
                        AudioManager.shared.playSfx(.click)
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedTab = tab
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: tab.sfIcon)
                                .font(.system(size: 12, weight: .bold))
                            Text(tab.title)
                                .font(.system(size: 12, weight: .black, design: .rounded))
                        }
                        .foregroundStyle(isSelected ? Color.black : Color.white.opacity(0.8))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            isSelected ?
                                LinearGradient(
                                    colors: [Color(hex: 0xFFFFD54F), Color(hex: 0xFFFFB300)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ) :
                                LinearGradient(
                                    colors: [Color.white.opacity(0.08), Color.white.opacity(0.04)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                        )
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(isSelected ? Color(hex: 0xFFFFD54F) : Color.white.opacity(0.12), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: - 1. Crates Tab
    private var cratesSection: some View {
        VStack(spacing: 16) {
            ForEach(CrateItem.allCrates) { crate in
                CrateCardView(
                    crate: crate,
                    canAfford: save.gold >= crate.cost,
                    onOpen: {
                        triggerCrateOpen(crate)
                    }
                )
            }
        }
    }

    private func triggerCrateOpen(_ crate: CrateItem) {
        guard save.gold >= crate.cost else {
            AudioManager.shared.playSfx(.hitWall)
            showNoMoneyToast()
            return
        }

        AudioManager.shared.playSfx(.click)
        if let drop = save.openCrate(tier: crate) {
            crateBeingOpened = crate
            openedCrateResult = drop
            isOpeningCrate = true
            AudioManager.shared.playSfx(.victory)
        }
    }

    // MARK: - 2. Balls Tab
    private var ballsSection: some View {
        LazyVGrid(columns: columns, spacing: 14) {
            ForEach(BallSkinItem.allSkins) { skin in
                let isEquipped = save.equippedBallSkin == skin.id
                let isUnlocked = save.isUnlocked(cosmeticId: skin.id)

                CosmeticCardView(
                    title: skin.name,
                    rarity: skin.rarity,
                    cost: skin.cost,
                    isEquipped: isEquipped,
                    isUnlocked: isUnlocked,
                    preview: {
                        BallPreviewWidget(skin: skin)
                    },
                    onEquip: {
                        AudioManager.shared.playSfx(.click)
                        save.equipBallSkin(skin.id)
                    },
                    onBuy: {
                        attemptBuy(cost: skin.cost, id: skin.id)
                    }
                )
            }
        }
    }

    // MARK: - 3. Paddles Tab
    private var paddlesSection: some View {
        LazyVGrid(columns: columns, spacing: 14) {
            ForEach(PaddleSkinItem.allSkins) { paddle in
                let isEquipped = save.equippedPaddleSkin == paddle.id
                let isUnlocked = save.isUnlocked(cosmeticId: paddle.id)

                CosmeticCardView(
                    title: paddle.name,
                    rarity: paddle.rarity,
                    cost: paddle.cost,
                    isEquipped: isEquipped,
                    isUnlocked: isUnlocked,
                    preview: {
                        PaddlePreviewWidget(paddle: paddle)
                    },
                    onEquip: {
                        AudioManager.shared.playSfx(.click)
                        save.equipPaddle(id: paddle.id)
                    },
                    onBuy: {
                        attemptBuy(cost: paddle.cost, id: paddle.id)
                    }
                )
            }
        }
    }

    // MARK: - 4. Trails Tab
    private var trailsSection: some View {
        LazyVGrid(columns: columns, spacing: 14) {
            ForEach(TrailSkinItem.allTrails) { trail in
                let isEquipped = save.equippedTrail == trail.id
                let isUnlocked = save.isUnlocked(cosmeticId: trail.id)

                CosmeticCardView(
                    title: trail.name,
                    rarity: trail.rarity,
                    cost: trail.cost,
                    isEquipped: isEquipped,
                    isUnlocked: isUnlocked,
                    preview: {
                        TrailPreviewWidget(trail: trail)
                    },
                    onEquip: {
                        AudioManager.shared.playSfx(.click)
                        save.equipTrail(trail.id)
                    },
                    onBuy: {
                        attemptBuy(cost: trail.cost, id: trail.id)
                    }
                )
            }
        }
    }

    // MARK: - 5. Bricks Tab
    private var bricksSection: some View {
        LazyVGrid(columns: columns, spacing: 14) {
            ForEach(BrickSkinItem.allBricks) { brick in
                let isEquipped = save.equippedBrickTheme == brick.id
                let isUnlocked = save.isUnlocked(cosmeticId: brick.id)

                CosmeticCardView(
                    title: brick.name,
                    rarity: brick.rarity,
                    cost: brick.cost,
                    isEquipped: isEquipped,
                    isUnlocked: isUnlocked,
                    preview: {
                        BrickPreviewWidget(brick: brick)
                    },
                    onEquip: {
                        AudioManager.shared.playSfx(.click)
                        save.equipBrickTheme(brick.id)
                    },
                    onBuy: {
                        attemptBuy(cost: brick.cost, id: brick.id)
                    }
                )
            }
        }
    }

    // MARK: - 6. Backgrounds Tab
    private var backgroundsSection: some View {
        LazyVGrid(columns: columns, spacing: 14) {
            ForEach(BackgroundThemeItem.allThemes) { theme in
                let isEquipped = save.equippedBackground == theme.id
                let isUnlocked = save.isUnlocked(cosmeticId: theme.id)

                CosmeticCardView(
                    title: theme.name,
                    rarity: theme.tier,
                    cost: theme.cost,
                    isEquipped: isEquipped,
                    isUnlocked: isUnlocked,
                    preview: {
                        BackgroundPreviewWidget(theme: theme)
                    },
                    onEquip: {
                        AudioManager.shared.playSfx(.click)
                        save.equipBackground(theme.id)
                    },
                    onBuy: {
                        attemptBuy(cost: theme.cost, id: theme.id)
                    }
                )
            }
        }
    }

    // MARK: - Upgrades & Boosts Footer
    private var upgradesAndBoostsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(I18n.pick("GÜÇLENDİRMELER & YÜKSELTMELER", "BOOSTS & UPGRADES"))
                .font(.system(size: 14, weight: .black, design: .rounded))
                .tracking(1.0)
                .foregroundStyle(Color(hex: 0xFFFFD54F))

            // Upgrades (Battery, Magnet, Luck)
            VStack(spacing: 12) {
                ForEach(UpgradeDefItem.allUpgrades) { upg in
                    let currentLvl = save.upgrades[upg.id] ?? 0
                    let nextCost = upg.costForNextLevel(currentLevel: currentLvl)
                    let isMax = upg.isMaxLevel(currentLevel: currentLvl)

                    HStack(spacing: 14) {
                        Image(systemName: upg.sfSymbol)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Color(hex: 0xFF40C4FF))
                            .frame(width: 44, height: 44)
                            .background(Color(hex: 0xFF40C4FF).opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(upg.name)
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)

                            Text(I18n.pick("Seviye", "Level") + " \(currentLvl)/\(upg.maxLevel)")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.6))
                        }

                        Spacer()

                        if isMax {
                            Text(I18n.pick("MAKS", "MAX"))
                                .font(.system(size: 13, weight: .black, design: .rounded))
                                .foregroundStyle(Color(hex: 0xFF00E676))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color(hex: 0xFF00E676).opacity(0.15))
                                .clipShape(Capsule())
                        } else if let cost = nextCost {
                            Button {
                                if save.buyUpgrade(upg.id) {
                                    AudioManager.shared.playSfx(.powerupBuff)
                                } else {
                                    showNoMoneyToast()
                                }
                            } label: {
                                HStack(spacing: 5) {
                                    Text("\(cost)")
                                        .font(.system(size: 13, weight: .black, design: .monospaced))
                                    PixelCoin(size: 13)
                                }
                                .foregroundStyle(.black)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color(hex: 0xFFFFD54F))
                                .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                }
            }

            // Consumable Boosts (Life, Wide, Multi)
            HStack(spacing: 12) {
                ForEach(BoostItemDef.allBoosts) { bst in
                    let stock = save.boostStocks[bst.id] ?? 0
                    VStack(spacing: 8) {
                        Image(systemName: bst.sfSymbol)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(Color(hex: 0xFFFF80AB))

                        Text(bst.name)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        Text(I18n.pick("Stok", "Stock") + ": \(stock)/\(bst.maxStock)")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))

                        Button {
                            if save.buyBoost(bst.id) {
                                AudioManager.shared.playSfx(.powerupBuff)
                            } else {
                                showNoMoneyToast()
                            }
                        } label: {
                            HStack(spacing: 3) {
                                Text("\(bst.cost)")
                                    .font(.system(size: 11, weight: .black, design: .monospaced))
                                PixelCoin(size: 11)
                            }
                            .foregroundStyle(stock >= bst.maxStock ? .white.opacity(0.4) : .black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(stock >= bst.maxStock ? Color.white.opacity(0.1) : Color(hex: 0xFFFFD54F))
                            .clipShape(Capsule())
                        }
                        .disabled(stock >= bst.maxStock)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity)
                    .background(Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                }
            }
        }
    }

    // MARK: - Purchase Logic
    private func attemptBuy(cost: Int, id: String) {
        if save.spendGold(cost) {
            save.unlock(cosmeticId: id)
            save.equip(cosmeticId: id)
            AudioManager.shared.playSfx(.powerupBuff)
        } else {
            AudioManager.shared.playSfx(.hitWall)
            showNoMoneyToast()
        }
    }

    private func showNoMoneyToast() {
        showInsufficientGoldToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            showInsufficientGoldToast = false
        }
    }
}

// MARK: - Component: CrateCardView
private struct CrateCardView: View {
    let crate: CrateItem
    let canAfford: Bool
    let onOpen: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            // Crate Box Icon with Tier Styling
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [crate.primaryColor.opacity(0.4), crate.primaryColor.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 76, height: 76)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(crate.primaryColor.opacity(0.8), lineWidth: 1.5)
                    )

                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(crate.primaryColor)
                    .shadow(color: crate.primaryColor.opacity(0.6), radius: 8)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(crate.name)
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                // Rarity probability chips
                HStack(spacing: 6) {
                    if let leg = crate.weights[.legendary], leg > 0 {
                        Text(I18n.isEnglish ? "\(Int(leg))% Legendary" : "%\(Int(leg)) Efsanevi")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(hex: 0xFFFFD54F))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color(hex: 0xFFFFD54F).opacity(0.15))
                            .clipShape(Capsule())
                    }
                    if let epic = crate.weights[.epic], epic > 0 {
                        Text(I18n.isEnglish ? "\(Int(epic))% Epic" : "%\(Int(epic)) Destansı")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(hex: 0xFFE040FB))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color(hex: 0xFFE040FB).opacity(0.15))
                            .clipShape(Capsule())
                    }
                }

                Text(I18n.pick("Balık, Top, Raket veya İz içerir", "Contains a Fish, Ball, Paddle or Trail"))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
            }

            Spacer()

            Button {
                onOpen()
            } label: {
                VStack(spacing: 3) {
                    Text(I18n.pick("AÇ", "OPEN"))
                        .font(.system(size: 13, weight: .black, design: .rounded))
                    HStack(spacing: 3) {
                        Text("\(crate.cost)")
                            .font(.system(size: 12, weight: .heavy, design: .monospaced))
                        PixelCoin(size: 12)
                    }
                }
                .foregroundStyle(canAfford ? .black : .white.opacity(0.4))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(canAfford ? Color(hex: 0xFFFFD54F) : Color.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: canAfford ? Color(hex: 0xFFFFD54F).opacity(0.3) : .clear, radius: 8)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.09), lineWidth: 1)
        )
    }
}

// MARK: - Component: CosmeticCardView
private struct CosmeticCardView<Preview: View>: View {
    let title: String
    let rarity: Rarity
    let cost: Int
    let isEquipped: Bool
    let isUnlocked: Bool
    let preview: () -> Preview
    let onEquip: () -> Void
    let onBuy: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            // Top Rarity Indicator
            HStack {
                Text(rarity.localizedLabel.uppercased())
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .foregroundStyle(rarity.primaryColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(rarity.primaryColor.opacity(0.15))
                    .clipShape(Capsule())

                Spacer()

                if isEquipped {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color(hex: 0xFF00E676))
                }
            }

            // Interactive Preview Widget
            preview()
                .frame(height: 72)

            // Item Name
            Text(title)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)

            // Bottom Action Button
            if isEquipped {
                Text(I18n.pick("KUŞANILDI", "EQUIPPED"))
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(Color(hex: 0xFF00E676))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(Color(hex: 0xFF00E676).opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else if isUnlocked {
                Button {
                    onEquip()
                } label: {
                    Text(I18n.pick("KUŞAN", "EQUIP"))
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(Color(hex: 0xFF2979FF))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    onBuy()
                } label: {
                    HStack(spacing: 4) {
                        Text("\(cost)")
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                        PixelCoin(size: 11)
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(Color(hex: 0xFFFFD54F))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isEquipped ? Color(hex: 0xFF00E676).opacity(0.7) : rarity.primaryColor.opacity(0.2), lineWidth: isEquipped ? 1.5 : 1)
        )
    }
}

// MARK: - Preview Widgets
private struct BallPreviewWidget: View {
    let skin: BallSkinItem

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let ballColor = skin.currentMainColor(time: t)
            let glow = skin.currentGlowColor(time: t)

            ZStack {
                Circle()
                    .fill(glow.opacity(0.35))
                    .frame(width: 44, height: 44)
                    .blur(radius: 6)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [ballColor, skin.darkColor],
                            center: .topLeading,
                            startRadius: 2,
                            endRadius: 20
                        )
                    )
                    .frame(width: 32, height: 32)
                    .overlay(
                        Circle().stroke(Color.white.opacity(0.6), lineWidth: 1)
                    )
                    .shadow(color: glow.opacity(0.5), radius: 6)
            }
        }
    }
}

private struct PaddlePreviewWidget: View {
    let paddle: PaddleSkinItem

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [paddle.color1, paddle.color2],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 90, height: 16)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.white.opacity(0.5), lineWidth: 1)
                )
                .shadow(color: paddle.glowColor, radius: 8)
        }
    }
}

private struct TrailPreviewWidget: View {
    let trail: TrailSkinItem

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<6) { i in
                let scale = 1.0 - (Double(i) * 0.14)
                Circle()
                    .fill(trail.rarity.primaryColor.opacity(scale))
                    .frame(width: 14 * scale, height: 14 * scale)
            }
        }
    }
}

private struct BrickPreviewWidget: View {
    let brick: BrickSkinItem

    var body: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [brick.primaryColor, brick.accentColor],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 74, height: 26)
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color.white.opacity(0.4), lineWidth: 1)
            )
            .shadow(color: brick.primaryColor.opacity(0.4), radius: 6)
    }
}

private struct BackgroundPreviewWidget: View {
    let theme: BackgroundThemeItem

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(hex: 0xFF141724))
                .frame(width: 80, height: 50)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(theme.tier.primaryColor.opacity(0.5), lineWidth: 1)
                )

            Image(systemName: theme.sfSymbol)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(theme.tier.primaryColor)
        }
    }
}

// MARK: - Crate Opening Animation Dialog
public struct CrateOpeningOverlay: View {
    let crate: CrateItem
    let result: CrateDropResult
    let onDismiss: () -> Void

    @State private var scale: CGFloat = 0.4
    @State private var opacity: Double = 0.0

    public var body: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }

            VStack(spacing: 20) {
                // Glow Burst Ring
                ZStack {
                    Circle()
                        .fill(result.rarity.primaryColor.opacity(0.35))
                        .frame(width: 160, height: 160)
                        .blur(radius: 20)

                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [result.rarity.primaryColor.opacity(0.4), result.rarity.darkColor.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 110, height: 110)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(result.rarity.primaryColor, lineWidth: 2)
                        )

                    Image(systemName: iconForDropType(result.type))
                        .font(.system(size: 48, weight: .black))
                        .foregroundStyle(result.rarity.primaryColor)
                        .shadow(color: result.rarity.primaryColor, radius: 12)
                }

                // Rarity Tag
                Text(result.rarity.localizedLabel.uppercased())
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(result.rarity.primaryColor)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
                    .background(result.rarity.primaryColor.opacity(0.18))
                    .clipShape(Capsule())

                // Unlocked Item Name
                Text(result.name)
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                // Duplicate Refund or New Unlock Badge
                if result.isDuplicate {
                    HStack(spacing: 6) {
                        Text(I18n.pick("Zaten Sahipsin! İade:", "Already Owned! Refund:"))
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.75))
                        HStack(spacing: 3) {
                            Text("+\(result.refundGold)")
                                .font(.system(size: 14, weight: .black, design: .monospaced))
                                .foregroundStyle(Color(hex: 0xFFFFD54F))
                            PixelCoin(size: 14)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
                } else {
                    Text(I18n.pick("YENİ KOZMETİK AÇILDI!", "NEW COSMETIC UNLOCKED!"))
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(Color(hex: 0xFF00E676))
                }

                Button {
                    onDismiss()
                } label: {
                    Text(I18n.pick("HARİKA!", "AWESOME!"))
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(.black)
                        .frame(width: 180, height: 48)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: 0xFFFFD54F), Color(hex: 0xFFFFB300)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .clipShape(Capsule())
                        .shadow(color: Color(hex: 0xFFFFD54F).opacity(0.4), radius: 12)
                }
                .buttonStyle(.plain)
                .padding(.top, 10)
            }
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.65)) {
                    scale = 1.0
                    opacity = 1.0
                }
            }
        }
    }

    private func iconForDropType(_ type: CrateDropType) -> String {
        switch type {
        case .ball: return "circle.fill"
        case .paddle: return "capsule.portrait.fill"
        case .trail: return "sparkles"
        case .fish: return "fish.fill"
        }
    }
}
