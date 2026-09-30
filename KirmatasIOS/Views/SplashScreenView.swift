import SwiftUI

struct SplashScreenView: View {
    @State private var isFinished = false
    @State private var scale: CGFloat = 0.82
    @State private var opacity: Double = 0.0
    @State private var pulsePhase: Double = 0.0

    var body: some View {
        if isFinished {
            MainMenuView()
                .transition(.opacity)
        } else {
            ZStack {
                // Cosmic radial vignette background
                RadialGradient(
                    colors: [
                        Color(hex: 0xFF1B182B),
                        Color(hex: 0xFF101222),
                        Color(hex: 0xFF07080F)
                    ],
                    center: UnitPoint(x: 0.5, y: 0.45),
                    startRadius: 20,
                    endRadius: 460
                )
                .ignoresSafeArea()

                // Warm golden core glow behind logo
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hex: 0xFFFFB300).opacity(0.22),
                                Color(hex: 0xFFFF6D00).opacity(0.06),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 10,
                            endRadius: 160
                        )
                    )
                    .frame(width: 320, height: 320)
                    .offset(y: -20)

                VStack(spacing: 24) {
                    Image("kaunos_games")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 260, maxHeight: 260)
                        .shadow(color: Color(hex: 0xFFFFB300).opacity(0.35), radius: 24, x: 0, y: 8)

                    Text("S U N A R")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .tracking(8)
                        .foregroundStyle(Color(hex: 0xFFFFD54F))
                        .opacity(0.75 + 0.25 * sin(pulsePhase))
                }
                .scaleEffect(scale)
                .opacity(opacity)

                VStack {
                    Spacer()
                    Text(I18n.tr("tap_to_skip"))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .tracking(1.0)
                        .foregroundStyle(Color.white.opacity(0.35))
                        .padding(.bottom, 32)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                goToMenu()
            }
            .onAppear {
                withAnimation(.spring(response: 0.85, dampingFraction: 0.7)) {
                    scale = 1.0
                    opacity = 1.0
                }
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    pulsePhase = .pi
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
                    goToMenu()
                }
            }
        }
    }

    private func goToMenu() {
        guard !isFinished else { return }
        withAnimation(.easeInOut(duration: 0.45)) {
            isFinished = true
        }
    }
}
