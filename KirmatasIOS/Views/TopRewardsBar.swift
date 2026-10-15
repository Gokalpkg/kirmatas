import SwiftUI

public struct TopRewardsBar: View {
    @ObservedObject private var save = SaveManager.shared

    var onOpenAquarium: () -> Void
    var onOpenQuests: () -> Void
    var onOpenStreak: () -> Void
    var onOpenShop: () -> Void
    var onOpenSettings: () -> Void

    public init(
        onOpenAquarium: @escaping () -> Void,
        onOpenQuests: @escaping () -> Void,
        onOpenStreak: @escaping () -> Void,
        onOpenShop: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void
    ) {
        self.onOpenAquarium = onOpenAquarium
        self.onOpenQuests = onOpenQuests
        self.onOpenStreak = onOpenStreak
        self.onOpenShop = onOpenShop
        self.onOpenSettings = onOpenSettings
    }

    public var body: some View {
        HStack(spacing: 8) {
            // Settings button
            Button {
                AudioManager.shared.playSfx(.click)
                onOpenSettings()
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 38, height: 38)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }

            // Shop button
            Button {
                AudioManager.shared.playSfx(.click)
                onOpenShop()
            } label: {
                Image(systemName: "cart.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 38, height: 38)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }

            Spacer()

            // Eco-Tank Aquarium Button with Pulse/Badge
            Button {
                AudioManager.shared.playSfx(.click)
                onOpenAquarium()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "fish.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color(hex: 0xFF40C4FF))

                    if save.aquariumIdleGold > 0 {
                        Text("+\(save.aquariumIdleGold)")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundStyle(Color(hex: 0xFFFFD54F))
                    } else if save.isFishHungry {
                        Text(I18n.pick("AÇ", "HUNGRY"))
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .foregroundStyle(Color(hex: 0xFFFF5252))
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color(hex: 0xFF0277BD).opacity(0.35))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(
                            save.aquariumAlertActive ? Color(hex: 0xFFFFD54F) : Color(hex: 0xFF40C4FF).opacity(0.4),
                            lineWidth: 1.2
                        )
                )
            }

            // Daily Quests Button with Progress Indicator
            Button {
                AudioManager.shared.playSfx(.click)
                onOpenQuests()
            } label: {
                let claimableCount = save.dailyQuests.filter { $0.canClaim }.count
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "checklist")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(claimableCount > 0 ? Color(hex: 0xFFFFD54F) : .white.opacity(0.85))
                        .frame(width: 38, height: 38)
                        .background(claimableCount > 0 ? Color(hex: 0xFFFFD54F).opacity(0.2) : Color.white.opacity(0.08))
                        .clipShape(Circle())

                    if claimableCount > 0 {
                        Text("\(claimableCount)")
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .foregroundStyle(.black)
                            .frame(width: 14, height: 14)
                            .background(Color(hex: 0xFFFFD54F))
                            .clipShape(Circle())
                            .offset(x: 2, y: -2)
                    }
                }
            }

            // 7-Day Login Streak Button
            Button {
                AudioManager.shared.playSfx(.click)
                onOpenStreak()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color(hex: 0xFFFF7043))
                    Text("\(save.dailyStreak)" + I18n.pick("G", "D"))
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 7)
                .background(Color(hex: 0xFFD84315).opacity(0.35))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(save.canClaimDailyStreak ? Color(hex: 0xFFFFB74D) : Color.clear, lineWidth: 1.2)
                )
            }

            // Gold Balance Capsule
            HStack(spacing: 4) {
                Text("🪙")
                    .font(.system(size: 14))
                Text("\(save.gold)")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(Color(hex: 0xFFFFD54F))
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(Color(hex: 0xFF101320).opacity(0.85))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color(hex: 0xFFFFD54F).opacity(0.4), lineWidth: 1.2))
        }
    }
}
