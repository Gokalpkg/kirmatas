import SwiftUI

public enum RewardsViewTab: String, CaseIterable, Identifiable {
    case quests = "quests"
    case streak = "streak"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .quests: return I18n.pick("GÜNLÜK GÖREVLER", "DAILY QUESTS")
        case .streak: return I18n.pick("7 GÜNLÜK SERİ", "7-DAY STREAK")
        }
    }
}

public struct RewardsCenterView: View {
    @ObservedObject private var save = SaveManager.shared
    @Environment(\.presentationMode) private var presentationMode

    @State var selectedTab: RewardsViewTab = .quests
    @State private var toastMessage: String?

    public init(initialTab: RewardsViewTab = .quests) {
        _selectedTab = State(initialValue: initialTab)
    }

    public var body: some View {
        ZStack {
            // Dark Gradient Background
            RadialGradient(
                gradient: Gradient(colors: [
                    Color(hex: 0xFF172033),
                    Color(hex: 0xFF0D121F),
                    Color(hex: 0xFF060910)
                ]),
                center: .top,
                startRadius: 50,
                endRadius: 650
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                headerView
                    .padding(.horizontal, 18)
                    .padding(.top, 14)
                    .padding(.bottom, 12)

                // Tab Switcher
                tabSwitcher
                    .padding(.horizontal, 18)
                    .padding(.bottom, 16)

                // Scroll Content
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        if selectedTab == .quests {
                            dailyQuestsList
                        } else {
                            streakCalendarView
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 32)
                }
            }

            // Toast overlay
            if let toast = toastMessage {
                VStack {
                    Spacer()
                    Text(toast)
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(Color.black)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color(hex: 0xFFFFD54F))
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.4), radius: 12, y: 4)
                        .padding(.bottom, 28)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    // MARK: - Header
    private var headerView: some View {
        HStack {
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

            Text(I18n.pick("ÖDÜLLER", "REWARDS"))
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

            HStack(spacing: 5) {
                PixelCoin(size: 16)
                Text("\(save.gold)")
                    .font(.system(size: 16, weight: .black, design: .monospaced))
                    .foregroundStyle(Color(hex: 0xFFFFD54F))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(hex: 0xFF101320).opacity(0.85))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color(hex: 0xFFFFD54F).opacity(0.4), lineWidth: 1.2))
        }
    }

    // MARK: - Tab Switcher
    private var tabSwitcher: some View {
        HStack(spacing: 8) {
            ForEach(RewardsViewTab.allCases) { tab in
                let isSelected = selectedTab == tab
                Button {
                    AudioManager.shared.playSfx(.click)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = tab
                    }
                } label: {
                    Text(tab.title)
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(isSelected ? Color.black : Color.white.opacity(0.75))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
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
                            Capsule().stroke(isSelected ? Color(hex: 0xFFFFD54F) : Color.white.opacity(0.12), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Daily Quests List
    private var dailyQuestsList: some View {
        VStack(spacing: 12) {
            ForEach(save.dailyQuests) { quest in
                HStack(spacing: 14) {
                    // Quest Icon
                    ZStack {
                        Circle()
                            .fill(quest.isCompleted ? Color(hex: 0xFF00E676).opacity(0.2) : Color.white.opacity(0.08))
                            .frame(width: 48, height: 48)

                        Image(systemName: iconForQuest(quest.type))
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(quest.isCompleted ? Color(hex: 0xFF00E676) : Color(hex: 0xFF40C4FF))
                    }

                    // Quest Title & Progress Bar
                    VStack(alignment: .leading, spacing: 6) {
                        Text(quest.localizedTitle(lang: save.language))
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        // Progress Bar
                        GeometryReader { g in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.12))
                                    .frame(height: 7)

                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(hex: 0xFF00E5FF), Color(hex: 0xFF00E676)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: max(0, g.size.width * quest.progressFraction), height: 7)
                            }
                        }
                        .frame(height: 7)

                        Text("\(quest.current) / \(quest.target)")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                    }

                    Spacer()

                    // Action / Reward Button
                    if quest.isClaimed {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(Color(hex: 0xFF00E676))
                    } else if quest.canClaim {
                        Button {
                            let reward = save.claimQuest(id: quest.id)
                            AudioManager.shared.playSfx(.victory)
                            showToast("+\(reward) G " + I18n.pick("Alındı!", "Claimed!"))
                        } label: {
                            VStack(spacing: 2) {
                                Text(I18n.pick("AL", "CLAIM"))
                                    .font(.system(size: 12, weight: .black, design: .rounded))
                                HStack(spacing: 2) {
                                    Text("\(quest.goldReward)")
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    PixelCoin(size: 10)
                                }
                            }
                            .foregroundStyle(.black)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color(hex: 0xFFFFD54F))
                            .clipShape(Capsule())
                            .shadow(color: Color(hex: 0xFFFFD54F).opacity(0.4), radius: 8)
                        }
                        .buttonStyle(.plain)
                    } else {
                        HStack(spacing: 3) {
                            Text("\(quest.goldReward)")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                            PixelCoin(size: 11)
                        }
                        .foregroundStyle(Color(hex: 0xFFFFD54F).opacity(0.85))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Capsule())
                    }
                }
                .padding(14)
                .background(Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(quest.canClaim ? Color(hex: 0xFFFFD54F).opacity(0.6) : Color.white.opacity(0.08), lineWidth: 1)
                )
            }
        }
    }

    // MARK: - 7-Day Login Streak Calendar
    private var streakCalendarView: some View {
        VStack(spacing: 18) {
            // Streak Header Banner
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(I18n.isEnglish ? "Login Streak: \(save.dailyStreak) Days" : "Giriş Serisi: \(save.dailyStreak) Gün")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(Color(hex: 0xFFFF7043))

                    Text(I18n.pick("Her gün girerek 7. gün büyük ikramiyesini kazan!", "Log in every day to win the day 7 jackpot!"))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.65))
                }
                Spacer()

                Image(systemName: "flame.fill")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: 0xFFFF7043), Color(hex: 0xFFFFD54F)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .padding(16)
            .background(Color(hex: 0xFFD84315).opacity(0.18))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color(hex: 0xFFFF7043).opacity(0.4), lineWidth: 1)
            )

            // 7 Days Grid
            let gridLayout = [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ]

            LazyVGrid(columns: gridLayout, spacing: 12) {
                ForEach(QuestCatalog.streakRewards) { item in
                    let isCurrentDay = item.day == save.dailyStreak
                    let isPassed = item.day < save.dailyStreak

                    VStack(spacing: 8) {
                        Text(I18n.isEnglish ? "DAY \(item.day)" : "\(item.day). GÜN")
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .foregroundStyle(isCurrentDay ? Color(hex: 0xFFFFD54F) : .white.opacity(0.6))

                        ZStack {
                            Circle()
                                .fill(isCurrentDay ? Color(hex: 0xFFFFD54F).opacity(0.25) : Color.white.opacity(0.06))
                                .frame(width: 44, height: 44)

                            if item.day == 7 {
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(Color(hex: 0xFFFFD54F))
                            } else if let bonus = item.bonusType {
                                Image(systemName: iconForBonus(bonus))
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(Color(hex: 0xFF40C4FF))
                            } else {
                                PixelCoin(size: 16)
                            }
                        }

                        Text("+\(item.goldReward)")
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundStyle(isCurrentDay ? Color(hex: 0xFFFFD54F) : .white)

                        if let desc = item.localizedBonusDescription(lang: save.language) {
                            Text(desc)
                                .font(.system(size: 8, weight: .bold, design: .rounded))
                                .foregroundStyle(Color(hex: 0xFF80D8FF))
                                .lineLimit(1)
                        }
                    }
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(isCurrentDay ? Color(hex: 0xFFFFD54F).opacity(0.12) : Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(
                                isCurrentDay ? Color(hex: 0xFFFFD54F) : (isPassed ? Color(hex: 0xFF00E676).opacity(0.4) : Color.white.opacity(0.08)),
                                lineWidth: isCurrentDay ? 1.5 : 1
                            )
                    )
                }
            }

            // Big Claim Button
            Button {
                if save.canClaimDailyStreak {
                    let reward = save.claimDailyStreak()
                    AudioManager.shared.playSfx(.victory)
                    showToast("+\(reward) G " + I18n.pick("Günlük Seri Ödülü Alındı!", "Daily Streak Reward Claimed!"))
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: save.canClaimDailyStreak ? "gift.fill" : "checkmark.seal.fill")
                        .font(.system(size: 18, weight: .bold))

                    Text(save.canClaimDailyStreak ? I18n.pick("GÜNLÜK ÖDÜLÜ AL", "CLAIM DAILY REWARD") : I18n.pick("BUGÜN ALINDI", "CLAIMED TODAY"))
                        .font(.system(size: 15, weight: .black, design: .rounded))
                }
                .foregroundStyle(save.canClaimDailyStreak ? Color.black : Color.white.opacity(0.5))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    save.canClaimDailyStreak ?
                        LinearGradient(
                            colors: [Color(hex: 0xFFFFD54F), Color(hex: 0xFFFFB300)],
                            startPoint: .top,
                            endPoint: .bottom
                        ) :
                        LinearGradient(
                            colors: [Color.white.opacity(0.08), Color.white.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                )
                .clipShape(Capsule())
                .shadow(color: save.canClaimDailyStreak ? Color(hex: 0xFFFFD54F).opacity(0.4) : .clear, radius: 12)
            }
            .buttonStyle(.plain)
            .disabled(!save.canClaimDailyStreak)
            .padding(.top, 8)
        }
    }

    private func showToast(_ message: String) {
        toastMessage = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            toastMessage = nil
        }
    }

    private func iconForQuest(_ type: QuestType) -> String {
        switch type {
        case .bricks: return "square.grid.2x2.fill"
        case .fish: return "fish.fill"
        case .matches: return "gamecontroller.fill"
        case .combo: return "bolt.horizontal.fill"
        case .clutch: return "shield.fill"
        }
    }

    private func iconForBonus(_ bonus: StreakBonusType) -> String {
        switch bonus {
        case .welcome: return "gift.fill"
        case .lifeBoost: return "heart.fill"
        case .wideBoost: return "arrow.left.and.right"
        case .jackpot: return "crown.fill"
        }
    }
}
