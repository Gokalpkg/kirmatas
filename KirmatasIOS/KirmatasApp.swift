import SwiftUI

@main
struct KirmatasApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            SplashScreenView()
                .preferredColorScheme(.dark)
                .onAppear {
                    if scenePhase == .active {
                        AdManager.shared.start()
                    }
                }
                .onChange(of: scenePhase) { phase in
                    if phase == .active {
                        AdManager.shared.start()
                    }
                }
        }
    }
}
