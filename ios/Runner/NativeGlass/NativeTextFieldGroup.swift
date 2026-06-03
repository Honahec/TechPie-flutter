import Flutter
import UIKit

final class NativeTextFieldGroupFactory: NSObject, FlutterPlatformViewFactory {
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
    NativeTextFieldGroupPlatformView(
      frame: frame,
      viewId: viewId,
      arguments: args,
      messenger: messenger
    )
  }
}

final class NativeTextFieldGroupPlatformView: NSObject, FlutterPlatformView, UITextFieldDelegate {
  static let viewType = "techpie/native_text_field_group"

  private let rootView: UIView
  private let containerView = UIView()
  private let stackView = UIStackView()
  private let channel: FlutterMethodChannel

  private var fields: [UITextField] = []
  private var separators: [UIView] = []
  private var itemConfigurations: [[String: Any]] = []

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

    buildViewHierarchy()
    applyConfiguration(args as? [String: Any] ?? [:])

    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call: call, result: result)
    }
  }

  deinit {
    channel.setMethodCallHandler(nil)
  }

  func view() -> UIView {
    rootView
  }

  private func buildViewHierarchy() {
    rootView.backgroundColor = .clear

    containerView.translatesAutoresizingMaskIntoConstraints = false
    containerView.backgroundColor = .secondarySystemBackground
    containerView.layer.cornerRadius = 16
    containerView.layer.cornerCurve = .continuous
    containerView.clipsToBounds = true

    stackView.axis = .vertical
    stackView.alignment = .fill
    stackView.distribution = .fill
    stackView.translatesAutoresizingMaskIntoConstraints = false

    rootView.addSubview(containerView)
    containerView.addSubview(stackView)

    NSLayoutConstraint.activate([
      containerView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
      containerView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
      containerView.topAnchor.constraint(equalTo: rootView.topAnchor),
      containerView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),
      stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
      stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
      stackView.topAnchor.constraint(equalTo: containerView.topAnchor),
      stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
    ])
  }

  private func applyConfiguration(_ params: [String: Any]) {
    itemConfigurations = params["items"] as? [[String: Any]] ?? []
    rebuildFieldsIfNeeded()

    for (index, configuration) in itemConfigurations.enumerated() where index < fields.count {
      apply(configuration: configuration, to: fields[index])
    }
  }

  private func rebuildFieldsIfNeeded() {
    guard fields.count != itemConfigurations.count else {
      return
    }

    for view in stackView.arrangedSubviews {
      stackView.removeArrangedSubview(view)
      view.removeFromSuperview()
    }
    fields.removeAll()
    separators.removeAll()

    for index in itemConfigurations.indices {
      if index > 0 {
        let separatorRow = UIView()
        let separator = UIView()
        separator.backgroundColor = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        separatorRow.addSubview(separator)
        separatorRow.translatesAutoresizingMaskIntoConstraints = false
        separatorRow.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
        NSLayoutConstraint.activate([
          separator.leadingAnchor.constraint(equalTo: separatorRow.leadingAnchor, constant: 16),
          separator.trailingAnchor.constraint(equalTo: separatorRow.trailingAnchor),
          separator.topAnchor.constraint(equalTo: separatorRow.topAnchor),
          separator.bottomAnchor.constraint(equalTo: separatorRow.bottomAnchor),
        ])
        separators.append(separator)
        stackView.addArrangedSubview(separatorRow)
      }

      let field = UITextField()
      field.delegate = self
      field.borderStyle = .none
      field.clearButtonMode = .whileEditing
      field.autocapitalizationType = .none
      field.autocorrectionType = .no
      field.adjustsFontForContentSizeCategory = true
      field.font = .preferredFont(forTextStyle: .body)
      field.tag = index

      let row = UIView()
      row.translatesAutoresizingMaskIntoConstraints = false
      field.translatesAutoresizingMaskIntoConstraints = false
      row.addSubview(field)

      NSLayoutConstraint.activate([
        field.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 16),
        field.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -16),
        field.topAnchor.constraint(equalTo: row.topAnchor),
        field.bottomAnchor.constraint(equalTo: row.bottomAnchor),
        row.heightAnchor.constraint(equalToConstant: 56),
      ])

      fields.append(field)
      stackView.addArrangedSubview(row)
    }
  }

  private func apply(configuration: [String: Any], to field: UITextField) {
    field.text = configuration["text"] as? String ?? ""
    field.placeholder = configuration["placeholder"] as? String
    field.keyboardType = uiKeyboardType(configuration["keyboardType"] as? String ?? "text")
    field.returnKeyType = uiReturnKeyType(configuration["textInputAction"] as? String)
    field.isSecureTextEntry = configuration["obscureText"] as? Bool ?? false
    field.isEnabled = configuration["enabled"] as? Bool ?? true
  }

  private func handle(call: FlutterMethodCall, result: FlutterResult) {
    switch call.method {
    case "updateTexts":
      guard let params = call.arguments as? [String: Any] else {
        result(nil)
        return
      }

      let texts = params["texts"] as? [String] ?? []
      for (index, text) in texts.enumerated() where index < fields.count {
        if fields[index].text != text {
          fields[index].text = text
        }
      }
      result(nil)
    case "updateConfiguration":
      applyConfiguration(call.arguments as? [String: Any] ?? [:])
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func emitChanged(field: UITextField) {
    channel.invokeMethod(
      "onChanged",
      arguments: ["index": field.tag, "text": field.text ?? ""]
    )
  }

  func textFieldDidChangeSelection(_ textField: UITextField) {
    emitChanged(field: textField)
  }

  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    textField.resignFirstResponder()
    channel.invokeMethod(
      "onSubmitted",
      arguments: ["index": textField.tag, "text": textField.text ?? ""]
    )
    return true
  }

  private func uiKeyboardType(_ value: String) -> UIKeyboardType {
    switch value {
    case "emailAddress":
      return .emailAddress
    case "phone":
      return .phonePad
    case "url":
      return .URL
    case "number":
      return .numberPad
    default:
      return .default
    }
  }

  private func uiReturnKeyType(_ value: String?) -> UIReturnKeyType {
    switch value {
    case "done":
      return .done
    case "go":
      return .go
    case "search":
      return .search
    case "send":
      return .send
    default:
      return .next
    }
  }
}
