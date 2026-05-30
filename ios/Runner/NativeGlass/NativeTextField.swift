import Flutter
import UIKit

final class NativeTextFieldFactory: NSObject, FlutterPlatformViewFactory {
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
    NativeTextFieldPlatformView(
      frame: frame,
      viewId: viewId,
      arguments: args,
      messenger: messenger
    )
  }
}

final class NativeTextFieldPlatformView: NSObject, FlutterPlatformView, UITextFieldDelegate, UITextViewDelegate {
  static let viewType = "techpie/native_text_field"

  private let rootView: UIView
  private let label = UILabel()
  private let textField = UITextField()
  private let textView = UITextView()
  private let textViewPlaceholderLabel = UILabel()
  private let inputContainer = UIView()
  private let stack = UIStackView()
  private let channel: FlutterMethodChannel

  private var multiline = false
  private var text = ""
  private var activeInputView: UIView?
  private var activeInputConstraints: [NSLayoutConstraint] = []

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

    label.font = .preferredFont(forTextStyle: .body)
    label.adjustsFontForContentSizeCategory = true
    label.setContentHuggingPriority(.required, for: .horizontal)
    label.widthAnchor.constraint(greaterThanOrEqualToConstant: 84).isActive = true

    textField.delegate = self
    textField.borderStyle = .roundedRect
    textField.clearButtonMode = .whileEditing
    textField.autocapitalizationType = .none
    textField.autocorrectionType = .no

    textView.delegate = self
    textView.font = .preferredFont(forTextStyle: .body)
    textView.adjustsFontForContentSizeCategory = true
    textView.autocapitalizationType = .none
    textView.autocorrectionType = .no
    textView.isScrollEnabled = true
    textView.textContainerInset = UIEdgeInsets(top: 8, left: 6, bottom: 8, right: 6)
    applyTextViewBorderStyle()

    textViewPlaceholderLabel.font = .preferredFont(forTextStyle: .body)
    textViewPlaceholderLabel.adjustsFontForContentSizeCategory = true
    textViewPlaceholderLabel.textColor = .placeholderText
    textViewPlaceholderLabel.translatesAutoresizingMaskIntoConstraints = false
    textView.addSubview(textViewPlaceholderLabel)

    NSLayoutConstraint.activate([
      textViewPlaceholderLabel.leadingAnchor.constraint(equalTo: textView.leadingAnchor, constant: 11),
      textViewPlaceholderLabel.trailingAnchor.constraint(lessThanOrEqualTo: textView.trailingAnchor, constant: -11),
      textViewPlaceholderLabel.topAnchor.constraint(equalTo: textView.topAnchor, constant: 8)
    ])

    inputContainer.setContentHuggingPriority(.defaultLow, for: .horizontal)
    inputContainer.setContentCompressionResistancePriority(.required, for: .horizontal)

    stack.addArrangedSubview(label)
    stack.addArrangedSubview(inputContainer)
    stack.axis = .horizontal
    stack.alignment = .fill
    stack.spacing = 12
    stack.translatesAutoresizingMaskIntoConstraints = false

    rootView.addSubview(stack)
    NSLayoutConstraint.activate([
      stack.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
      stack.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
      stack.topAnchor.constraint(equalTo: rootView.topAnchor),
      stack.bottomAnchor.constraint(equalTo: rootView.bottomAnchor)
    ])
  }

  private func applyConfiguration(_ params: [String: Any]) {
    text = params["text"] as? String ?? text
    let labelText = params["label"] as? String ?? ""
    let placeholderText = params["placeholder"] as? String ?? labelText
    label.text = labelText
    textField.placeholder = placeholderText
    textViewPlaceholderLabel.text = placeholderText

    let maxLines = params["maxLines"] as? Int ?? 1
    multiline = maxLines > 1
    label.isHidden = shouldHideLeadingLabel(multiline: multiline)
    installInputView(multiline ? textView : textField)

    textField.text = text
    textView.text = text
    updateTextViewPlaceholderVisibility()
    textField.isSecureTextEntry = params["obscureText"] as? Bool ?? false
    textField.isEnabled = params["enabled"] as? Bool ?? true
    textView.isEditable = params["enabled"] as? Bool ?? true

    let keyboardType = params["keyboardType"] as? String ?? "text"
    textField.keyboardType = uiKeyboardType(keyboardType)
    textView.keyboardType = uiKeyboardType(keyboardType)

    let returnKeyType = uiReturnKeyType(params["textInputAction"] as? String)
    textField.returnKeyType = returnKeyType
    textView.returnKeyType = returnKeyType
  }

  private func installInputView(_ nextInputView: UIView) {
    guard activeInputView !== nextInputView else {
      return
    }

    NSLayoutConstraint.deactivate(activeInputConstraints)
    activeInputConstraints.removeAll()
    activeInputView?.removeFromSuperview()
    activeInputView = nextInputView

    nextInputView.translatesAutoresizingMaskIntoConstraints = false
    inputContainer.addSubview(nextInputView)

    activeInputConstraints = [
      nextInputView.leadingAnchor.constraint(equalTo: inputContainer.leadingAnchor),
      nextInputView.trailingAnchor.constraint(equalTo: inputContainer.trailingAnchor),
      nextInputView.topAnchor.constraint(equalTo: inputContainer.topAnchor),
      nextInputView.bottomAnchor.constraint(equalTo: inputContainer.bottomAnchor)
    ]
    NSLayoutConstraint.activate(activeInputConstraints)
  }

  private func applyTextViewBorderStyle() {
    textView.backgroundColor = .secondarySystemBackground
    textView.layer.borderWidth = 1
    textView.layer.cornerRadius = 10
    textView.layer.borderColor = UIColor.separator.cgColor
  }

  private func shouldHideLeadingLabel(multiline: Bool) -> Bool {
    if multiline {
      return true
    }

    if #available(iOS 26.0, *) {
      return true
    }

    return false
  }

  private func handle(call: FlutterMethodCall, result: FlutterResult) {
    switch call.method {
    case "updateText":
      guard let params = call.arguments as? [String: Any] else {
        result(nil)
        return
      }
      let nextText = params["text"] as? String ?? ""
      if text != nextText {
        text = nextText
        textField.text = nextText
        textView.text = nextText
        updateTextViewPlaceholderVisibility()
      }
      result(nil)
    case "updateConfiguration":
      applyConfiguration(call.arguments as? [String: Any] ?? [:])
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func emitChanged(_ nextText: String) {
    text = nextText
    channel.invokeMethod("onChanged", arguments: ["text": nextText])
  }

  func textFieldDidChangeSelection(_ textField: UITextField) {
    emitChanged(textField.text ?? "")
  }

  func textViewDidChange(_ textView: UITextView) {
    updateTextViewPlaceholderVisibility()
    emitChanged(textView.text ?? "")
  }

  private func updateTextViewPlaceholderVisibility() {
    textViewPlaceholderLabel.isHidden = !(textView.text ?? "").isEmpty
  }

  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    textField.resignFirstResponder()
    channel.invokeMethod("onSubmitted", arguments: ["text": textField.text ?? ""])
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
