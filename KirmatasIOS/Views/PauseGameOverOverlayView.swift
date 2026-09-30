import SwiftUI

struct PauseGameOverOverlayView: View {
    @ObservedObject var controller: GameController
    let onResume: () -> Void
    let onRestart: () -> Void
    let onMainMenu: () -> Void

    var body: some View {
        if controller.status == .playing || controller.status == .ready {
            EmptyView()
        } else {
            let isPaused = controller.status == .paused
            let isVictory = controller.status == .victory
            let isGameOver = controller.status == .gameOver
            let stats = controller.stats
            let bestScore = SaveManager.shared.getHighScore(controller.currentMode)
            let isNewRecord = stats.score >= bestScore && stats.score > 0

            let accentColor: Color = isVictory
                ? Color(hex: 0xFFFFD54F)
                : (isGameOver ? Color(hex: 0xFFFF5252) : Color.white)

            ZStack {
                Color(hex: 0xCC05060A)
                    .ignoresSafeArea()

                VStack(spacing: 18) {
                    Text(
                        isPaused
                            ? I18n.tr("paused")
                            : (isVictory ? I18n.tr("victory") : I18n.tr("game_over"))
                    )
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .tracking(1.0)
                    .foregroundStyle(accentColor)

                    if !isPaused {
                        VStack(spacing: 10) {
                            statRow(label: I18n.tr("score"), value: "\(stats.score)", valueColor: .white, fontSize: 18)
                            statRow(label: I18n.tr("high_score"), value: "\(bestScore)", valueColor: Color(hex: 0xFFFFD54F), fontSize: 16)
                            statRow(label: I18n.tr("max_combo"), value: "x\(stats.maxCombo)", valueColor: Color(hex: 0xFF00E5FF), fontSize: 15)
                            statRow(label: I18n.tr("bricks_broken"), value: "\(stats.bricksBroken)", valueColor: .white, fontSize: 15)
                        }
                        .padding(16)
                        .background(Color(hex: 0x66181C2E))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                        if isNewRecord {
                            Text(I18n.tr("new_record"))
                                .font(.system(size: 14, weight: .black, design: .rounded))
                                .tracking(1.0)
                                .foregroundStyle(Color(hex: 0xFFFFD54F))
                        }
                    }

                    VStack(spacing: 10) {
                        if isPaused {
                            Button {
                                AudioManager.shared.playSfx(.click)
                                onResume()
                            } label: {
                                Label(I18n.tr("resume"), systemImage: "play.fill")
                                    .font(.system(size: 15, weight: .black, design: .rounded))
                                    .foregroundStyle(.black)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
                                    .background(Color(hex: 0xFF00E5FF))
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }

                        Button {
                            AudioManager.shared.playSfx(.click)
                            onRestart()
                        } label: {
                            Label(I18n.tr("restart"), systemImage: "arrow.counterclockwise")
                                .font(.system(size: 15, weight: .black, design: .rounded))
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(Color(hex: 0xFFFFD54F))
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)

                        Button {
                            AudioManager.shared.playSfx(.click)
                            onMainMenu()
                        } label: {
                            Label(I18n.tr("main_menu"), systemImage: "house.fill")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.8))
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(Color.white.opacity(0.24), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(24)
                .frame(maxWidth: 320)
                .background(Color(hex: 0xF0101320))
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(accentColor.opacity(isPaused ? 0.25 : 0.85), lineWidth: 1.5)
                )
                .shadow(color: accentColor.opacity(0.3), radius: 28)
                .padding(.horizontal, 24)
            }
        }
    }

    private func statRow(label: String, value: String, valueColor: Color, fontSize: CGFloat) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
            Spacer()
            Text(value)
                .font(.system(size: fontSize, weight: .black, design: .rounded))
                .foregroundStyle(valueColor)
        }
    }
}
