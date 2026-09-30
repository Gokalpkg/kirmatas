import SwiftUI

struct GameContainerView: View {
    @ObservedObject var controller: GameController
    let onExitToMenu: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

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
