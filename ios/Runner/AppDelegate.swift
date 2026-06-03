import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    guard
      let registrar = self.registrar(
        forPlugin: "TechPieNativeGlassRegistry"
      )
    else {
      assertionFailure("Failed to create registrar for TechPieNativeGlassRegistry")
      return false
    }

    NativeGlassRegistry.registerAll(with: registrar)

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
