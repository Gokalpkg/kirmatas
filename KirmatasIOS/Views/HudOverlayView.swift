import SwiftUI

struct HudOverlayView: View {
    @ObservedObject var controller: GameController
    let onPause: () -> Void

    var body: some View {
        let stats = controller.stats

        ZStack {
            // Top Floating HUD Bar
            VStack {
                HStack(spacing: 8) {
                    // Lives Pill
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color(hex: 0xFFFF5252))
                        Text(controller.currentMode == .zen ? "∞" : "\(stats.lives)")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(hex: 0xFFFF5252).opacity(0.2))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color(hex: 0xFFFF5252).opacity(0.45), lineWidth: 1)
                    )

                    Spacer()

                    // Stage / Mode Center Badge
                    Text(
                        controller.currentMode == .classic
                            ? "\(I18n.tr("level").uppercased()) \(stats.level)"
                            : I18n.tr(controller.currentMode.rawValue).uppercased()
                    )
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .tracking(0.5)
                    .foregroundStyle(Color(hex: 0xFFFFD54F))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: 0xFF2E334D), Color(hex: 0xFF1B1E30)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color(hex: 0xFFFFD54F).opacity(0.35), lineWidth: 1)
                    )

                    Spacer()

                    // Score Counter
                    Text("\(stats.score)")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.18))
                        .clipShape(Capsule())

                    // Pause Button
                    Button {
                        AudioManager.shared.playSfx(.click)
                        onPause()
                    } label: {
                        Image(systemName: "pause.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(Color.white.opacity(0.22))
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 10)
                .frame(height: 48)
                .background(
                    LinearGradient(
                        colors: [Color(hex: 0xEE121524), Color(hex: 0xEE0B0D18)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.45), radius: 12, x: 0, y: 4)
                .padding(.horizontal, 12)
                .padding(.top, 4)

                Spacer()
            }

            // Ready Launch Banner
            if controller.status == .ready {
                VStack(spacing: 4) {
                    Text(I18n.tr("tap_to_launch"))
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .tracking(1.0)
                        .foregroundStyle(Color(hex: 0xFFFFD54F))
                    Text(I18n.tr("drag_hint"))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color(hex: 0xCC090A12))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color(hex: 0xFFFFD54F).opacity(0.45), lineWidth: 1)
                )
                .shadow(color: Color(hex: 0xFFFFD54F).opacity(0.2), radius: 14)
                .allowsHitTesting(false)
            }

            // Bottom Active PowerUp Chips & Ulti Button
            VStack {
                Spacer()
                HStack(alignment: .bottom, spacing: 8) {
                    // Active Powerups
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(controller.activePowerUps) { p in
                                HStack(spacing: 4) {
                                    Image(systemName: p.type.sfSymbol)
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(p.type.color)
                                    Text(String(format: "%.1fs", max(0, p.timeLeft)))
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                        .foregroundStyle(p.type.color)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(p.type.color.opacity(0.2))
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(p.type.color.opacity(0.6), lineWidth: 1)
                                )
                            }
                        }
                    }
                    .allowsHitTesting(false)

                    Spacer(minLength: 4)

                    // Ulti Button
                    let isReady = stats.ultiCharge >= 100.0
                    Button {
                        controller.triggerUlti()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 14, weight: .black))
                                .foregroundStyle(isReady ? .white : Color(hex: 0xFF00E5FF))
                            Text(isReady ? I18n.tr("power_mode") : "\(Int(stats.ultiCharge))%")
                                .font(.system(size: 12, weight: .black, design: .rounded))
                                .foregroundStyle(isReady ? .white : .white.opacity(0.75))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(
                            LinearGradient(
                                colors: isReady
                                    ? [Color(hex: 0xFF00E5FF), Color(hex: 0xFF0091EA)]
                                    : [Color(hex: 0xFF263238), Color(hex: 0xFF1E242B)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(
                                    isReady ? Color(hex: 0xFF00E5FF) : Color.white.opacity(0.15),
                                    lineWidth: isReady ? 2 : 1
                                )
                        )
                        .shadow(color: isReady ? Color(hex: 0xFF00E5FF).opacity(0.45) : .clear, radius: 10)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 8)
            }
        }
    }
}
