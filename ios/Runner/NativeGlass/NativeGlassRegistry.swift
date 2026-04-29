import Flutter
import UIKit

enum NativeGlassRegistry {
  static func registerAll(with registrar: FlutterPluginRegistrar) {
    let messenger = registrar.messenger()

    registrar.register(
      NativeGlassTabBarFactory(messenger: messenger),
      withId: NativeGlassTabBarPlatformView.viewType
    )
    registrar.register(
      NativeGlassFloatingButtonFactory(messenger: messenger),
      withId: NativeGlassFloatingButtonPlatformView.viewType
    )
  }
}
