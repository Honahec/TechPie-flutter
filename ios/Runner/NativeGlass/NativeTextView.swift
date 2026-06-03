import Flutter
import UIKit

final class NativeTextViewFactory: NSObject, FlutterPlatformViewFactory {
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
    NativeTextViewPlatformView(
      frame: frame,
      viewId: viewId,
      arguments: args,
      messenger: messenger
    )
  }
}

final class NativeTextViewPlatformView: NSObject, FlutterPlatformView, UITextViewDelegate {
  static let viewType = "techpie/native_text_view"

  private let rootView: UIView
  private let textView = UITextView()
  private let textViewPlaceholderLabel = UILabel()
  private let channel: FlutterMethodChannel

  private var text = ""

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
      textViewPlaceholderLabel.leadingAnchor.constraint(
        equalTo: textView.leadingAnchor, constant: 11),
      textViewPlaceholderLabel.trailingAnchor.constraint(
        lessThanOrEqualTo: textView.trailingAnchor, constant: -11),
      textViewPlaceholderLabel.topAnchor.constraint(equalTo: textView.topAnchor, constant: 8),
    ])

    textView.translatesAutoresizingMaskIntoConstraints = false
    rootView.addSubview(textView)

    NSLayoutConstraint.activate([
      textView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
      textView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
      textView.topAnchor.constraint(equalTo: rootView.topAnchor),
      textView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),
    ])
  }

  private func applyConfiguration(_ params: [String: Any]) {
    text = params["text"] as? String ?? text
    let placeholderText = params["placeholder"] as? String ?? ""
    textViewPlaceholderLabel.text = placeholderText

    textView.text = text
    updateTextViewPlaceholderVisibility()
    textView.isEditable = params["enabled"] as? Bool ?? true

    let keyboardType = params["keyboardType"] as? String ?? "text"
    textView.keyboardType = uiKeyboardType(keyboardType)

    let returnKeyType = uiReturnKeyType(params["textInputAction"] as? String)
    textView.returnKeyType = returnKeyType
  }

  private func applyTextViewBorderStyle() {
    textView.backgroundColor = .secondarySystemBackground
    textView.layer.borderWidth = 1
    textView.layer.cornerRadius = 10
    textView.layer.borderColor = UIColor.separator.cgColor
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

  func textViewDidChange(_ textView: UITextView) {
    updateTextViewPlaceholderVisibility()
    emitChanged(textView.text ?? "")
  }

  private func updateTextViewPlaceholderVisibility() {
    textViewPlaceholderLabel.isHidden = !(textView.text ?? "").isEmpty
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
