import Flutter
import UIKit

final class NativeGlassConfirmationButtonFactory: NSObject, FlutterPlatformViewFactory {
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
    NativeGlassConfirmationButtonPlatformView(
      frame: frame,
      viewId: viewId,
      arguments: args,
      messenger: messenger
    )
  }
}

final class NativeGlassConfirmationButtonPlatformView: NSObject, FlutterPlatformView {
  static let viewType = "techpie/native_glass_confirmation_button"

  private let rootView: UIView
  private let channel: FlutterMethodChannel
  private let backgroundView = UIVisualEffectView(
    effect: UIBlurEffect(style: .systemChromeMaterial)
  )
  private let button = UIButton(type: .system)

  private var label: String?
  private var confirmTitle = "Are you sure?"
  private var confirmLabel = "Confirm"
  private var sfSymbol = "checkmark"
  private var destructive = false

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
    button.addTarget(self, action: #selector(handleTap), for: .touchUpInside)
  }

  deinit {
    channel.setMethodCallHandler(nil)
  }

  func view() -> UIView {
    rootView
  }

  private func parseArguments(_ args: Any?) {
    guard let params = args as? [String: Any] else { return }

    label = params["label"] as? String
    if let rawTitle = params["confirmTitle"] as? String, !rawTitle.isEmpty {
      confirmTitle = rawTitle
    }
    if let rawConfirmLabel = params["confirmLabel"] as? String, !rawConfirmLabel.isEmpty {
      confirmLabel = rawConfirmLabel
    }
    if let rawSymbol = params["sfSymbol"] as? String, !rawSymbol.isEmpty {
      sfSymbol = rawSymbol
    }
    destructive = params["destructive"] as? Bool ?? false
  }

  private func buildViewHierarchy() {
    rootView.backgroundColor = .clear
    rootView.clipsToBounds = false

    button.translatesAutoresizingMaskIntoConstraints = false
    button.accessibilityTraits.insert(.button)
    button.clipsToBounds = false

    if #available(iOS 26.0, *) {
      rootView.addSubview(button)

      NSLayoutConstraint.activate([
        button.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
        button.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
        button.topAnchor.constraint(equalTo: rootView.topAnchor),
        button.bottomAnchor.constraint(equalTo: rootView.bottomAnchor)
      ])
      return
    }

    backgroundView.translatesAutoresizingMaskIntoConstraints = false
    backgroundView.clipsToBounds = true
    backgroundView.layer.cornerRadius = 18
    backgroundView.layer.borderWidth = 1
    backgroundView.layer.borderColor = NativeGlassColors.controlBorder.cgColor
    backgroundView.layer.shadowColor = UIColor.black.cgColor
    backgroundView.layer.shadowOpacity = 0.08
    backgroundView.layer.shadowRadius = 10
    backgroundView.layer.shadowOffset = CGSize(width: 0, height: 6)

    if #available(iOS 13.0, *) {
      backgroundView.layer.cornerCurve = .continuous
    }

    rootView.addSubview(backgroundView)
    backgroundView.contentView.addSubview(button)

    NSLayoutConstraint.activate([
      backgroundView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
      backgroundView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
      backgroundView.topAnchor.constraint(equalTo: rootView.topAnchor),
      backgroundView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),
      button.leadingAnchor.constraint(equalTo: backgroundView.contentView.leadingAnchor),
      button.trailingAnchor.constraint(equalTo: backgroundView.contentView.trailingAnchor),
      button.topAnchor.constraint(equalTo: backgroundView.contentView.topAnchor),
      button.bottomAnchor.constraint(equalTo: backgroundView.contentView.bottomAnchor)
    ])
  }

  private func applyButtonAppearance() {
    if #available(iOS 26.0, *) {
      applyLiquidGlassAppearance()
      return
    }

    let foregroundColor = destructive
      ? NativeGlassColors.destructiveRed
      : NativeGlassColors.floatingButtonForeground
    let image = symbolImage(named: sfSymbol)

    if #available(iOS 15.0, *) {
      var configuration = UIButton.Configuration.plain()
      configuration.image = image
      configuration.title = label
      configuration.baseForegroundColor = foregroundColor
      configuration.contentInsets = NSDirectionalEdgeInsets(
        top: 8,
        leading: 12,
        bottom: 8,
        trailing: 12
      )
      configuration.imagePadding = label == nil || label?.isEmpty == true ? 0 : 6
      configuration.cornerStyle = .capsule
      button.configuration = configuration
    } else {
      button.setImage(image, for: .normal)
      button.setTitle(label, for: .normal)
      button.tintColor = foregroundColor
      button.setTitleColor(foregroundColor, for: .normal)
      button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
      button.titleEdgeInsets = label == nil || label?.isEmpty == true
        ? .zero
        : UIEdgeInsets(top: 0, left: 6, bottom: 0, right: -6)
    }
  }

  @available(iOS 26.0, *)
  private func applyLiquidGlassAppearance() {
    let foregroundColor = destructive
      ? NativeGlassColors.destructiveRed
      : NativeGlassColors.floatingButtonForeground
    let image = symbolImage(named: sfSymbol)

    var configuration: UIButton.Configuration =
      label == nil || label?.isEmpty == true
      ? .clearGlass()
      : .glass()
    configuration.image = image
    configuration.title = label
    configuration.baseForegroundColor = foregroundColor
    configuration.contentInsets = NSDirectionalEdgeInsets(
      top: 8,
      leading: 12,
      bottom: 8,
      trailing: 12
    )
    configuration.imagePadding = label == nil || label?.isEmpty == true ? 0 : 6
    configuration.cornerStyle = .capsule

    button.configuration = configuration
    button.tintColor = foregroundColor
    button.backgroundColor = .clear
    button.layer.shadowOpacity = 0
    button.layer.borderWidth = 0
    button.setNeedsUpdateConfiguration()
  }

  private func symbolImage(named systemName: String) -> UIImage? {
    let configuration = UIImage.SymbolConfiguration(
      pointSize: 14,
      weight: .semibold,
      scale: .medium
    )

    return UIImage(systemName: systemName, withConfiguration: configuration)?
      .withRenderingMode(.alwaysTemplate)
  }

  @objc
  private func handleTap() {
    guard let controller = nearestViewController() else {
      return
    }

    let actionSheet = UIAlertController(
      title: confirmTitle,
      message: nil,
      preferredStyle: .actionSheet
    )

    let confirmStyle: UIAlertAction.Style = destructive ? .destructive : .default
    actionSheet.addAction(
      UIAlertAction(title: confirmLabel, style: confirmStyle) { [weak self] _ in
        let feedback = UIImpactFeedbackGenerator(style: .light)
        feedback.impactOccurred(intensity: 0.55)
        self?.channel.invokeMethod("onConfirmed", arguments: nil)
      }
    )
    actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))

    if let popover = actionSheet.popoverPresentationController {
      if #available(iOS 26.0, *) {
        popover.sourceItem = button
      } else {
        popover.sourceView = rootView
        popover.sourceRect = rootView.bounds
      }
    }

    controller.present(actionSheet, animated: true)
  }

  private func nearestViewController() -> UIViewController? {
    if let nextResponder = sequence(first: rootView.next, next: { $0?.next })
      .first(where: { $0 is UIViewController }) as? UIViewController {
      return nextResponder
    }

    let rootController = rootView.window?.rootViewController
    var topController = rootController

    while let presented = topController?.presentedViewController {
      topController = presented
    }

    return topController
  }
}
