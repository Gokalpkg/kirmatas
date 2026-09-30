import SwiftUI

struct MainMenuView: View {
    @ObservedObject private var save = SaveManager.shared
    @State private var activeGame: GameController?
    @State private var showSettings = false
    @State private var rewardToastText: String?

    var body: some View {
        if let controller = activeGame {
            GameContainerView(
                controller: controller,
                onExitToMenu: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        activeGame = nil
                    }
                }
            )
            .transition(.opacity)
        } else {
            ZStack {
                CosmicMenuBackground()
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    // Top Header Bar
                    HStack {
                        Button {
                            AudioManager.shared.playSfx(.click)
                            showSettings = true
                        } label: {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.white.opacity(0.85))
                                .frame(width: 44, height: 44)
                                .background(Color.black.opacity(0.35))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                                )
                        }

                        Spacer()

                        HStack(spacing: 6) {
                            Image(systemName: "bitcoinsign.circle.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(Color(hex: 0xFFFFD54F))
                            Text("\(save.gold)")
                                .font(.system(size: 15, weight: .black, design: .rounded))
                                .foregroundStyle(Color(hex: 0xFFFFD54F))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color(hex: 0xFF101320).opacity(0.75))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color(hex: 0xFFFFD54F).opacity(0.35), lineWidth: 1)
                        )
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 8)

                    // Brand Title
                    Text("KIRMATAS")
                        .font(.system(size: 42, weight: .black, design: .rounded))
                        .tracking(3.0)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(hex: 0xFFFFF6D8),
                                    Color(hex: 0xFFF5D27A),
                                    Color(hex: 0xFFE8A23A)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: Color(hex: 0xFFE88C28).opacity(0.45), radius: 16, x: 0, y: 4)
                        .padding(.top, 4)

                    // Main Modes ScrollView
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 14) {
                            // Hero Classic Card
                            classicHeroCard

                            // 2x2 Arcade Matrix
                            HStack(spacing: 12) {
                                arcadeMiniCard(
                                    mode: .zen,
                                    title: I18n.tr("zen"),
                                    desc: I18n.tr("zen_desc"),
                                    systemIcon: "leaf.fill",
                                    color1: Color(hex: 0xFF00B4D8),
                                    color2: Color(hex: 0xFF0077B6)
                                ) {
                                    launchGame(.zen)
                                }

                                arcadeMiniCard(
                                    mode: .descend,
                                    title: I18n.tr("descend"),
                                    desc: I18n.tr("descend_desc"),
                                    systemIcon: "chevron.down.dotted.2",
                                    color1: Color(hex: 0xFF9D4EDD),
                                    color2: Color(hex: 0xFFC77DFF)
                                ) {
                                    launchGame(.descend)
                                }
                            }

                            HStack(spacing: 12) {
                                dailyMiniCard

                                arcadeMiniCard(
                                    mode: .shapes,
                                    title: I18n.tr("shapes"),
                                    desc: I18n.tr("shapes_desc"),
                                    systemIcon: "paintbrush.pointed.fill",
                                    color1: Color(hex: 0xFFD4A373),
                                    color2: Color(hex: 0xFFA98467)
                                ) {
                                    launchGame(.shapes)
                                }
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.bottom, 24)
                    }
                }

                if let toast = rewardToastText {
                    VStack {
                        Spacer()
                        Text(toast)
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundStyle(Color.black)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color(hex: 0xFFFFD54F))
                            .clipShape(Capsule())
                            .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: 4)
                            .padding(.bottom, 32)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsSheetView()
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private var classicHeroCard: some View {
        let best = save.getHighScore(.classic)
        return Button {
            launchGame(.classic)
        } label: {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(I18n.tr("classic_desc"))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.26))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    Text(I18n.tr("classic").uppercased())
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .tracking(1.0)
                        .foregroundStyle(.white)

                    if best > 0 {
                        Text("\(I18n.tr("high_score")): \(best)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }

                Spacer()

                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 58, height: 58)
                        .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)

                    Image(systemName: "play.fill")
                        .font(.system(size: 26, weight: .black))
                        .foregroundStyle(Color(hex: 0xFFFF5722))
                        .offset(x: 2)
                }
            }
            .padding(20)
            .background(
                LinearGradient(
                    colors: [
                        Color(hex: 0xFFFF5722),
                        Color(hex: 0xFFFF9800),
                        Color(hex: 0xFFFFB74D)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: Color(hex: 0xFFFF5722).opacity(0.4), radius: 16, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }

    private func arcadeMiniCard(
        mode: GameMode,
        title: String,
        desc: String,
        systemIcon: String,
        color1: Color,
        color2: Color,
        action: @escaping () -> Void
    ) -> some View {
        let best = save.getHighScore(mode)
        return Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.26))
                            .frame(width: 36, height: 36)
                        Image(systemName: systemIcon)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                    }

                    Spacer()

                    if best > 0 {
                        Text("\(best)")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.black.opacity(0.26))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }

                Spacer()

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(desc)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(1)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .background(
                LinearGradient(
                    colors: [color1.opacity(0.92), color2.opacity(0.92)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: color1.opacity(0.28), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }

    private var dailyMiniCard: some View {
        let canClaim = save.canClaimDaily()
        return Button {
            launchGame(.daily)
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.18))
                            .frame(width: 36, height: 36)
                        Image(systemName: "calendar")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color(hex: 0xFF2A1800))
                    }

                    Spacer()

                    if canClaim {
                        Button {
                            let reward = save.claimDailyReward()
                            AudioManager.shared.playSfx(.powerupBuff)
                            withAnimation {
                                rewardToastText = "+\(reward) \(I18n.tr("coins"))!"
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                withAnimation {
                                    rewardToastText = nil
                                }
                            }
                        } label: {
                            Text(I18n.tr("claim").uppercased())
                                .font(.system(size: 10, weight: .black, design: .rounded))
                                .foregroundStyle(Color(hex: 0xFFFFD54F))
                                .padding(.horizontal, 9)
                                .padding(.vertical, 4)
                                .background(Color(hex: 0xFF2A1800))
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Color(hex: 0xFF2A1800))
                    }
                }

                Spacer()

                VStack(alignment: .leading, spacing: 2) {
                    Text(I18n.tr("daily"))
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(Color(hex: 0xFF2A1800))
                        .lineLimit(1)

                    Text(canClaim ? I18n.tr("today_ready") : I18n.tr("today_done"))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(hex: 0xFF2A1800).opacity(0.8))
                        .lineLimit(1)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .background(
                LinearGradient(
                    colors: [Color(hex: 0xFFF5D27A), Color(hex: 0xFFFF9A4A)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color(hex: 0xFFFF9A4A).opacity(0.28), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }

    private func launchGame(_ mode: GameMode) {
        AudioManager.shared.playSfx(.click)
        let controller = GameController()
        controller.startNewGame(mode: mode)
        withAnimation(.easeInOut(duration: 0.25)) {
            activeGame = controller
        }
    }
}

struct SettingsSheetView: View {
    @ObservedObject private var save = SaveManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color(hex: 0xFF101320).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text(I18n.tr("settings").uppercased())
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Text(I18n.tr("close"))
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundStyle(Color(hex: 0xFFFFD54F))
                    }
                }

                // Language
                VStack(alignment: .leading, spacing: 8) {
                    Text(I18n.tr("language"))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(hex: 0xFFFFD54F))

                    HStack(spacing: 8) {
                        ForEach(I18n.supportedLanguages) { lang in
                            let selected = save.language == lang.code
                            Button {
                                save.setLanguage(lang.code)
                                AudioManager.shared.playSfx(.click)
                            } label: {
                                Text(lang.nativeLabel)
                                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                                    .foregroundStyle(selected ? Color(hex: 0xFFFFD54F) : .white.opacity(0.7))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(selected ? Color(hex: 0xFFFFD54F).opacity(0.2) : Color.white.opacity(0.05))
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(selected ? Color(hex: 0xFFFFD54F) : Color.white.opacity(0.12), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Sound Effects Toggle
                Toggle(isOn: Binding(
                    get: { save.sfxEnabled },
                    set: { save.setSfx($0) }
                )) {
                    Text(I18n.tr("sfx"))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .tint(Color(hex: 0xFFFFD54F))

                // Haptic Intensity
                VStack(alignment: .leading, spacing: 8) {
                    Text(I18n.tr("vibration_intensity"))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.75))

                    HStack(spacing: 6) {
                        ForEach(HapticIntensity.allCases) { h in
                            let selected = save.hapticIntensity == h
                            Button {
                                save.setHapticIntensity(h)
                                AudioManager.shared.triggerTestHaptic(h)
                            } label: {
                                Text(h.label)
                                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                                    .foregroundStyle(selected ? Color(hex: 0xFFFFD54F) : .white.opacity(0.65))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 9)
                                    .background(selected ? Color(hex: 0xFFFFD54F).opacity(0.2) : Color.clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(selected ? Color(hex: 0xFFFFD54F) : Color.white.opacity(0.12), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Game Speed
                VStack(alignment: .leading, spacing: 8) {
                    Text(I18n.tr("speed"))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.75))

                    HStack(spacing: 8) {
                        ForEach(SpeedSetting.allCases) { s in
                            let selected = save.speed == s
                            Button {
                                save.setSpeed(s)
                                AudioManager.shared.playSfx(.click)
                            } label: {
                                Text(s.label)
                                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                                    .foregroundStyle(selected ? Color(hex: 0xFFFFD54F) : .white.opacity(0.65))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 9)
                                    .background(selected ? Color(hex: 0xFFFFD54F).opacity(0.2) : Color.clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(selected ? Color(hex: 0xFFFFD54F) : Color.white.opacity(0.12), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Spacer()
            }
            .padding(24)
        }
    }
}

struct CosmicMenuBackground: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                let rect = CGRect(origin: .zero, size: size)
                context.fill(
                    Path(rect),
                    with: .radialGradient(
                        Gradient(colors: [
                            Color(hex: 0xFF14243B),
                            Color(hex: 0xFF0A1222),
                            Color(hex: 0xFF050811)
                        ]),
                        center: CGPoint(x: size.width * 0.5, y: size.height * 0.25),
                        startRadius: 10,
                        endRadius: max(size.width, size.height) * 0.9
                    )
                )

                for i in 0..<35 {
                    let speed = 12.0 + Double(i % 4) * 5.0
                    let sway = sin(t * 1.4 + Double(i)) * 8.0
                    let baseW = max(Int(size.width), 1)
                    let x = Double((i * 89 + 15) % baseW) + sway
                    let y = size.height - ((Double(i * 149) + t * speed).truncatingRemainder(dividingBy: max(size.height, 1)))
                    let alpha = min(max(0.2 + Double(i % 3) * 0.18 + 0.12 * sin(t * 2.0 + Double(i)), 0.1), 0.75)
                    let radius = (i % 4 == 0) ? 2.4 : 1.3
                    let c = (i % 2 == 0) ? Color(hex: 0xFF38BDF8) : Color(hex: 0xFFFFD54F)
                    let circleRect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
                    context.fill(Path(ellipseIn: circleRect), with: .color(c.opacity(alpha)))
                }
            }
        }
    }
}
