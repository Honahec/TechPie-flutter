import Flutter
import UIKit

final class NativeGlassFloatingButtonFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    NativeGlassFloatingButtonPlatformView(
      frame: frame,
      viewId: viewId,
      arguments: args,
      messenger: messenger
    )
  }
}

final class NativeGlassFloatingButtonPlatformView: NSObject, FlutterPlatformView {
  static let viewType = "techpie/native_glass_floating_button"

  private let rootView: UIView
  private let channel: FlutterMethodChannel
  private let button = UIButton(type: .system)

  private var sfSymbol = "plus"

  init(
    frame: CGRect,
    viewId: Int64,
    arguments args: Any?,
    messenger: FlutterBinaryMessenger
  ) {
    rootView = UIView(frame: frame)
    channel = FlutterMethodChannel(
      name: "\(Self.viewType)/\(viewId)",
      binaryMessenger: messenger
    )

    super.init()

    parseArguments(args)
    buildViewHierarchy()
    applyButtonAppearance()

    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call: call, result: result)
    }
  }

  func view() -> UIView {
    rootView
  }

  private func parseArguments(_ args: Any?) {
    guard
      let params = args as? [String: Any],
      let rawSymbol = params["sfSymbol"] as? String,
      !rawSymbol.isEmpty
    else {
      return
    }

    sfSymbol = rawSymbol
  }

  private func buildViewHierarchy() {
    rootView.backgroundColor = .clear
    rootView.clipsToBounds = false

    button.translatesAutoresizingMaskIntoConstraints = false
    button.adjustsImageWhenHighlighted = true
    button.tintAdjustmentMode = .normal
    button.clipsToBounds = false
    button.imageView?.contentMode = .center

    button.addTarget(self, action: #selector(handleTap), for: .touchUpInside)
    button.addTarget(
      self,
      action: #selector(handlePressBegan),
      for: [.touchDown, .touchDragEnter]
    )
    button.addTarget(
      self,
      action: #selector(handlePressEnded),
      for: [.touchCancel, .touchDragExit, .touchUpInside, .touchUpOutside]
    )

    rootView.addSubview(button)

    NSLayoutConstraint.activate([
      button.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
      button.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
      button.topAnchor.constraint(equalTo: rootView.topAnchor),
      button.bottomAnchor.constraint(equalTo: rootView.bottomAnchor)
    ])
  }

  private func symbolImage() -> UIImage? {
    let symbolConfiguration = UIImage.SymbolConfiguration(
      pointSize: 22,
      weight: .semibold,
      scale: .medium
    )

    return UIImage(systemName: sfSymbol, withConfiguration: symbolConfiguration)?
      .withRenderingMode(.alwaysTemplate)
  }

  private func applyButtonAppearance() {
    let image = symbolImage()

    if #available(iOS 26.0, *) {
      applyLiquidGlassAppearance(image: image)
    } else if #available(iOS 15.0, *) {
      applyModernFallbackAppearance(image: image)
    } else {
      applyLegacyFallbackAppearance(image: image)
    }
  }

  @available(iOS 26.0, *)
  private func applyLiquidGlassAppearance(image: UIImage?) {
    var configuration = UIButton.Configuration.prominentGlass()
    configuration.image = image
    configuration.cornerStyle = .capsule
    configuration.baseForegroundColor = NativeGlassColors.floatingButtonForeground
    configuration.baseBackgroundColor = NativeGlassColors.barBackground
    configuration.contentInsets = NSDirectionalEdgeInsets(
      top: 18,
      leading: 18,
      bottom: 18,
      trailing: 18
    )

    button.configuration = configuration
    button.tintColor = NativeGlassColors.floatingButtonForeground
    button.backgroundColor = .clear
    button.layer.shadowOpacity = 0
    button.layer.borderWidth = 0
    button.setNeedsUpdateConfiguration()
  }

  @available(iOS 15.0, *)
  private func applyModernFallbackAppearance(image: UIImage?) {
    var configuration = UIButton.Configuration.plain()
    configuration.image = image
    configuration.cornerStyle = .capsule
    configuration.baseForegroundColor = NativeGlassColors.floatingButtonForeground
    configuration.baseBackgroundColor = NativeGlassColors.barBackground
    configuration.contentInsets = NSDirectionalEdgeInsets(
      top: 18,
      leading: 18,
      bottom: 18,
      trailing: 18
    )

    button.configuration = configuration
    button.tintColor = NativeGlassColors.floatingButtonForeground
    button.backgroundColor = NativeGlassColors.barBackground
    button.layer.cornerRadius = 32
    button.layer.cornerCurve = .continuous
    button.layer.shadowColor = UIColor.black.cgColor
    button.layer.shadowOpacity = 0.16
    button.layer.shadowRadius = 18
    button.layer.shadowOffset = CGSize(width: 0, height: 8)
    button.layer.borderWidth = 0
    button.setNeedsUpdateConfiguration()
  }

  private func applyLegacyFallbackAppearance(image: UIImage?) {
    button.setImage(image, for: .normal)
    button.tintColor = NativeGlassColors.floatingButtonForeground
    button.backgroundColor = NativeGlassColors.barBackground
    button.contentEdgeInsets = UIEdgeInsets(
      top: 18,
      left: 18,
      bottom: 18,
      right: 18
    )
    button.layer.cornerRadius = 32
    button.layer.shadowColor = UIColor.black.cgColor
    button.layer.shadowOpacity = 0.16
    button.layer.shadowRadius = 18
    button.layer.shadowOffset = CGSize(width: 0, height: 8)
    button.layer.borderWidth = 0

    if #available(iOS 13.0, *) {
      button.layer.cornerCurve = .continuous
    }
  }

  private func handle(call: FlutterMethodCall, result: FlutterResult) {
    switch call.method {
    case "updateSymbol":
      guard
        let arguments = call.arguments as? [String: Any],
        let symbol = arguments["sfSymbol"] as? String,
        !symbol.isEmpty
      else {
        result(
          FlutterError(
            code: "bad_args",
            message: "Expected an sfSymbol string.",
            details: nil
          )
        )
        return
      }

      sfSymbol = symbol
      applyButtonAppearance()
      result(nil)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  @objc
  private func handleTap() {
    let feedback = UIImpactFeedbackGenerator(style: .light)
    feedback.impactOccurred(intensity: 0.65)

    channel.invokeMethod("onTap", arguments: nil)
  }

  @objc
  private func handlePressBegan() {
    let feedback = UIImpactFeedbackGenerator(style: .soft)
    feedback.impactOccurred(intensity: 0.35)

    if #available(iOS 26.0, *) {
      return
    }

    UIView.animate(
      withDuration: 0.14,
      delay: 0,
      options: [.beginFromCurrentState, .curveEaseOut]
    ) {
      self.button.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
      self.button.alpha = 0.88
    }
  }

  @objc
  private func handlePressEnded() {
    if #available(iOS 26.0, *) {
      return
    }

    UIView.animate(
      withDuration: 0.20,
      delay: 0,
      options: [.beginFromCurrentState, .curveEaseOut]
    ) {
      self.button.transform = .identity
      self.button.alpha = 1.0
    }
  }
}
