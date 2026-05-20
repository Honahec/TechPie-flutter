import Flutter
import UIKit

enum NativeGlassRegistry {
  static func registerAll(with registrar: FlutterPluginRegistrar) {
    let messenger = registrar.messenger()
    let platformChannel = FlutterMethodChannel(
      name: "techpie/platform",
      binaryMessenger: messenger
    )

    platformChannel.setMethodCallHandler { call, result in
      switch call.method {
      case "iosMajorVersion":
        let major = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
        result(major)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    registrar.register(
      NativeGlassTabBarFactory(messenger: messenger),
      withId: NativeGlassTabBarPlatformView.viewType
    )
    registrar.register(
      NativeGlassButtonFactory(messenger: messenger),
      withId: NativeGlassButtonPlatformView.viewType
    )
    registrar.register(
      NativeGlassDropdownMenuFactory(messenger: messenger),
      withId: NativeGlassDropdownMenuPlatformView.viewType
    )
    registrar.register(
      NativeGlassSelectFactory(messenger: messenger),
      withId: NativeGlassSelectPlatformView.viewType
    )
    registrar.register(
      NativeGlassSwitchFactory(messenger: messenger),
      withId: NativeGlassSwitchPlatformView.viewType
    )
    registrar.register(
      NativeGlassConfirmationButtonFactory(messenger: messenger),
      withId: NativeGlassConfirmationButtonPlatformView.viewType
    )
    registrar.register(
      NativeNavigationBarFactory(messenger: messenger),
      withId: NativeNavigationBarPlatformView.viewType
    )

    NativeGlassPresenterPlugin.register(with: registrar)
  }
}
