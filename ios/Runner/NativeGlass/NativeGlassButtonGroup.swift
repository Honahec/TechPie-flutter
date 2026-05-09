import Flutter
import UIKit

final class NativeGlassButtonGroupFactory: NSObject, FlutterPlatformViewFactory {
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
    NativeGlassButtonGroupPlatformView(
      frame: frame,
      viewId: viewId,
      arguments: args,
      messenger: messenger
    )
  }
}

final class NativeGlassButtonGroupPlatformView: NSObject, FlutterPlatformView {
  static let viewType = "techpie/native_glass_button_group"

  private let rootView: UIView
  private let channel: FlutterMethodChannel
  private let backgroundView = UIVisualEffectView(
    effect: UIBlurEffect(style: .systemChromeMaterial)
  )
  private var glassView: UIVisualEffectView?
  private let stackView = UIStackView()

  private var items: [NativeGlassButtonGroupItem] = []
  private var buttons: [UIButton] = []
  private var separators: [UIView] = []

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
    applyItems()
  }

  func view() -> UIView {
    rootView
  }

  private func parseArguments(_ args: Any?) {
    guard let params = args as? [String: Any] else {
      applyDefaultItemsIfNeeded()
      return
    }

    if let rawItems = params["buttons"] as? [[String: Any]] {
      items = rawItems.compactMap(NativeGlassButtonGroupItem.init)
    }

    applyDefaultItemsIfNeeded()
  }

  private func applyDefaultItemsIfNeeded() {
    guard items.isEmpty else {
      return
    }

    items = [
      NativeGlassButtonGroupItem(
        id: "previous",
        sfSymbol: "chevron.left",
        accessibilityLabel: "Previous"
      ),
      NativeGlassButtonGroupItem(
        id: "next",
        sfSymbol: "chevron.right",
        accessibilityLabel: "Next"
      )
    ]
  }

  private func buildViewHierarchy() {
    rootView.backgroundColor = .clear
    rootView.clipsToBounds = false

    stackView.translatesAutoresizingMaskIntoConstraints = false
    stackView.axis = .horizontal
    stackView.spacing = 0
    stackView.distribution = .fillEqually
    stackView.alignment = .fill

    if #available(iOS 26.0, *) {
      let effect = UIGlassEffect(style: .regular)
      effect.isInteractive = true

      let effectView = UIVisualEffectView(effect: effect)
      effectView.translatesAutoresizingMaskIntoConstraints = false
      effectView.clipsToBounds = true
      effectView.layer.cornerRadius = 20

      if #available(iOS 13.0, *) {
        effectView.layer.cornerCurve = .continuous
      }

      glassView = effectView
      rootView.addSubview(effectView)
      effectView.contentView.addSubview(stackView)

      NSLayoutConstraint.activate([
        effectView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
        effectView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
        effectView.topAnchor.constraint(equalTo: rootView.topAnchor),
        effectView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),
        stackView.leadingAnchor.constraint(equalTo: effectView.contentView.leadingAnchor),
        stackView.trailingAnchor.constraint(equalTo: effectView.contentView.trailingAnchor),
        stackView.topAnchor.constraint(equalTo: effectView.contentView.topAnchor),
        stackView.bottomAnchor.constraint(equalTo: effectView.contentView.bottomAnchor)
      ])
      return
    }

    backgroundView.translatesAutoresizingMaskIntoConstraints = false
    backgroundView.clipsToBounds = true
    backgroundView.layer.cornerRadius = 20
    backgroundView.layer.borderWidth = 1
    backgroundView.layer.borderColor = NativeGlassColors.controlBorder.cgColor
    backgroundView.layer.shadowColor = UIColor.black.cgColor
    backgroundView.layer.shadowOpacity = 0.10
    backgroundView.layer.shadowRadius = 12
    backgroundView.layer.shadowOffset = CGSize(width: 0, height: 6)

    if #available(iOS 13.0, *) {
      backgroundView.layer.cornerCurve = .continuous
    }

    rootView.addSubview(backgroundView)
    backgroundView.contentView.addSubview(stackView)

    NSLayoutConstraint.activate([
      backgroundView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
      backgroundView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
      backgroundView.topAnchor.constraint(equalTo: rootView.topAnchor),
      backgroundView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),
      stackView.leadingAnchor.constraint(equalTo: backgroundView.contentView.leadingAnchor),
      stackView.trailingAnchor.constraint(equalTo: backgroundView.contentView.trailingAnchor),
      stackView.topAnchor.constraint(equalTo: backgroundView.contentView.topAnchor),
      stackView.bottomAnchor.constraint(equalTo: backgroundView.contentView.bottomAnchor)
    ])
  }

  private func applyItems() {
    stackView.arrangedSubviews.forEach { view in
      stackView.removeArrangedSubview(view)
      view.removeFromSuperview()
    }
    separators.forEach { $0.removeFromSuperview() }
    separators.removeAll()
    buttons.removeAll()

    for (index, item) in items.enumerated() {
      let button = makeButton(for: item, index: index)
      buttons.append(button)
      stackView.addArrangedSubview(button)
    }

    guard buttons.count > 1 else {
      return
    }

    let hostView: UIView
    if #available(iOS 26.0, *), let glassView {
      hostView = glassView.contentView
    } else {
      hostView = backgroundView.contentView
    }

    for index in 1..<buttons.count {
      let separator = UIView()
      separator.translatesAutoresizingMaskIntoConstraints = false
      separator.backgroundColor = NativeGlassColors.controlSeparator
      hostView.addSubview(separator)
      separators.append(separator)

      NSLayoutConstraint.activate([
        separator.widthAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale),
        separator.topAnchor.constraint(equalTo: hostView.topAnchor, constant: 8),
        separator.bottomAnchor.constraint(equalTo: hostView.bottomAnchor, constant: -8),
        separator.leadingAnchor.constraint(equalTo: buttons[index].leadingAnchor)
      ])
    }
  }

  private func makeButton(for item: NativeGlassButtonGroupItem, index: Int) -> UIButton {
    let button = UIButton(type: .system)
    button.translatesAutoresizingMaskIntoConstraints = false
    button.tag = index
    button.tintColor = NativeGlassColors.floatingButtonForeground
    button.backgroundColor = .clear
    button.accessibilityLabel = item.accessibilityLabel ?? item.id
    button.accessibilityTraits.insert(.button)
    button.addTarget(self, action: #selector(handleButtonTap(_:)), for: .touchUpInside)

    let image = symbolImage(named: item.sfSymbol)

    if #available(iOS 15.0, *) {
      var configuration = UIButton.Configuration.plain()
      configuration.image = image
      configuration.baseForegroundColor = NativeGlassColors.floatingButtonForeground
      configuration.contentInsets = NSDirectionalEdgeInsets(
        top: 8,
        leading: 12,
        bottom: 8,
        trailing: 12
      )
      button.configuration = configuration
    } else {
      button.setImage(image, for: .normal)
      button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
    }

    return button
  }

  private func symbolImage(named systemName: String) -> UIImage? {
    let configuration = UIImage.SymbolConfiguration(
      pointSize: 16,
      weight: .semibold,
      scale: .medium
    )

    return UIImage(systemName: systemName, withConfiguration: configuration)?
      .withRenderingMode(.alwaysTemplate)
  }

  @objc
  private func handleButtonTap(_ sender: UIButton) {
    guard items.indices.contains(sender.tag) else {
      return
    }

    let feedback = UIImpactFeedbackGenerator(style: .light)
    feedback.impactOccurred(intensity: 0.6)

    channel.invokeMethod("onTap", arguments: ["id": items[sender.tag].id])
  }
}

private struct NativeGlassButtonGroupItem {
  let id: String
  let sfSymbol: String
  let accessibilityLabel: String?

  init(id: String, sfSymbol: String, accessibilityLabel: String?) {
    self.id = id
    self.sfSymbol = sfSymbol
    self.accessibilityLabel = accessibilityLabel
  }

  init?(_ dictionary: [String: Any]) {
    guard
      let id = dictionary["id"] as? String,
      let sfSymbol = dictionary["sfSymbol"] as? String,
      !id.isEmpty,
      !sfSymbol.isEmpty
    else {
      return nil
    }

    self.init(
      id: id,
      sfSymbol: sfSymbol,
      accessibilityLabel: dictionary["accessibilityLabel"] as? String
    )
  }
}
