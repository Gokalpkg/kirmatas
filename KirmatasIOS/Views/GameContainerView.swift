import SwiftUI

struct GameContainerView: View {
    @ObservedObject var controller: GameController
    let onExitToMenu: () -> Void

    var body: some View {
        ZStack {
            // Deep space cosmic background
            RadialGradient(
                colors: [
                    Color(hex: 0xFF141624),
                    Color(hex: 0xFF0A0C16),
                    Color(hex: 0xFF020308)
                ],
                center: .bottom,
                startRadius: 50,
                endRadius: 800
            )
            .ignoresSafeArea()

            GameCanvasView(controller: controller)
                .ignoresSafeArea()

            HudOverlayView(
                controller: controller,
                onPause: {
                    controller.pause()
                }
            )

            PauseGameOverOverlayView(
                controller: controller,
                onResume: {
                    controller.resume()
                },
                onRestart: {
                    controller.startNewGame(mode: controller.currentMode)
                },
                onMainMenu: onExitToMenu
            )
        }
        #if os(iOS)
        .statusBarHidden(true)
        #endif
    }
}
