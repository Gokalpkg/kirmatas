import Flutter
import UIKit

class MainFlutterViewController: FlutterViewController {
  override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge {
    return [.bottom, .all]
  }

  override var prefersHomeIndicatorAutoHidden: Bool {
    return true
  }
}

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
