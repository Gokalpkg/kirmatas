import SwiftUI

struct GameContainerView: View {
    let controller: GameController
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
                    AdManager.shared.checkAndShowInterstitial(level: controller.stats.level) {
                        controller.startNewGame(mode: controller.currentMode)
                    }
                },
                onMainMenu: {
                    AdManager.shared.checkAndShowInterstitial(level: controller.stats.level) {
                        onExitToMenu()
                    }
                }
            )
            #if os(iOS)
            SystemGesturesDeferrer()
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)
            #endif
        }
        #if os(iOS)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .defersSystemGestures(on: .all)
        #endif
    }
}

#if os(iOS)
import UIKit

/// Native UIKit helper to guarantee iOS defers screen-edge system gestures (such as the Home Bar
/// multitasking app switcher) and hides the Home Indicator so bottom drag controls never switch apps or tabs.
struct SystemGesturesDeferrer: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> SystemGesturesViewController {
        SystemGesturesViewController()
    }

    func updateUIViewController(_ uiViewController: SystemGesturesViewController, context: Context) {
        uiViewController.setNeedsUpdateOfScreenEdgesDeferringSystemGestures()
        uiViewController.setNeedsUpdateOfHomeIndicatorAutoHidden()
    }
}

final class SystemGesturesViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        setNeedsUpdateOfScreenEdgesDeferringSystemGestures()
        setNeedsUpdateOfHomeIndicatorAutoHidden()
    }

    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge {
        return [.bottom, .all]
    }

    override var prefersHomeIndicatorAutoHidden: Bool {
        return true
    }

    override var childForScreenEdgesDeferringSystemGestures: UIViewController? {
        return nil
    }

    override var childForHomeIndicatorAutoHidden: UIViewController? {
        return nil
    }
}
#endif
