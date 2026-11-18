import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    // The engine lifecycle tests create and register their own FlutterEngine.
    // Registering the plugin on the implicit engine as well would install a
    // second volume observer and replace Mute.shared.notify.
    if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
      return
    }
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
