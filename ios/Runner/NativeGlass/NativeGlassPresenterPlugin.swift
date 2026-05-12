import Flutter
import UIKit

final class NativeGlassPresenterPlugin: NSObject, FlutterPlugin {
  private static let channelName = "techpie/native_glass_presenter"

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: registrar.messenger()
    )
    let instance = NativeGlassPresenterPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "showAlert":
      guard let arguments = call.arguments as? [String: Any] else {
        result(
          FlutterError(
            code: "bad_args",
            message: "Expected a dictionary of alert arguments.",
            details: nil
          )
        )
        return
      }

      showAlert(arguments: arguments, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func showAlert(arguments: [String: Any], result: @escaping FlutterResult) {
    guard
      let title = arguments["title"] as? String,
      let message = arguments["message"] as? String,
      let rawActions = arguments["actions"] as? [[String: Any]],
      let presenter = topViewController()
    else {
      result(
        FlutterError(
          code: "bad_args",
          message: "Missing title, message, actions, or presenter.",
          details: nil
        )
      )
      return
    }

    let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
    var preferredAction: UIAlertAction?
    var didComplete = false

    func complete(_ value: Any?) {
      guard !didComplete else { return }
      didComplete = true
      result(value)
    }

    for actionData in rawActions {
      guard let label = actionData["label"] as? String, !label.isEmpty else {
        continue
      }

      let isDestructive = actionData["isDestructive"] as? Bool ?? false
      let isDefault = actionData["isDefault"] as? Bool ?? false
      let value = actionData["value"]
      let style: UIAlertAction.Style = isDestructive ? .destructive : .default

      let action = UIAlertAction(title: label, style: style) { _ in
        complete(value)
      }

      if isDefault {
        preferredAction = action
      }

      alert.addAction(action)
    }

    if alert.actions.isEmpty {
      alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
        complete(nil)
      })
    }

    if let preferredAction {
      alert.preferredAction = preferredAction
    }

    presenter.present(alert, animated: true)
  }

  private func topViewController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .filter { $0.activationState == .foregroundActive }

    let keyWindow = scenes
      .flatMap(\.windows)
      .first(where: \.isKeyWindow)

    var topController = keyWindow?.rootViewController

    while let presented = topController?.presentedViewController {
      topController = presented
    }

    return topController
  }
}
