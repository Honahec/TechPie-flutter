import Flutter
import UIKit

final class NativeGlassPresenterPlugin: NSObject, FlutterPlugin {
  private static let channelName = "techpie/native_glass_presenter"
  private let channel: FlutterMethodChannel

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: registrar.messenger()
    )
    let instance = NativeGlassPresenterPlugin(channel: channel)
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  init(channel: FlutterMethodChannel) {
    self.channel = channel
    super.init()
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
    case "presentLoginSheet":
      let arguments = call.arguments as? [String: Any] ?? [:]
      presentLoginSheet(arguments: arguments, result: result)
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

    for (index, actionData) in rawActions.enumerated() {
      guard let label = actionData["label"] as? String, !label.isEmpty else {
        continue
      }

      let isDestructive = actionData["isDestructive"] as? Bool ?? false
      let isDefault = actionData["isDefault"] as? Bool ?? false
      let style: UIAlertAction.Style = isDestructive ? .destructive : .default

      let action = UIAlertAction(title: label, style: style) { _ in
        complete(index)
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

  private func presentLoginSheet(
    arguments: [String: Any],
    result: @escaping FlutterResult
  ) {
    guard #available(iOS 26.0, *) else {
      result(
        FlutterError(
          code: "unsupported",
          message: "Native login sheet requires iOS 26.",
          details: nil
        )
      )
      return
    }

    guard let presenter = topViewController() else {
      result(
        FlutterError(
          code: "no_presenter",
          message: "Unable to find a presenter for login sheet.",
          details: nil
        )
      )
      return
    }

    let copy = NativeLoginSheetCopy(
      pageTitle: arguments["pageTitle"] as? String ?? "登录",
      brandName: arguments["brandName"] as? String ?? "TechPie",
      subtitle: arguments["subtitle"] as? String ?? "登录以访问校园服务"
    )

    var didComplete = false
    func complete() {
      guard !didComplete else { return }
      didComplete = true
      result(nil)
    }

    let controller = NativeLoginSheetViewController(
      copy: copy,
      channel: channel,
      onDismiss: complete
    )
    controller.modalPresentationStyle = .pageSheet

    if let sheet = controller.sheetPresentationController {
      sheet.detents = [.medium(), .large()]
      sheet.selectedDetentIdentifier = .medium
      sheet.prefersGrabberVisible = false
      sheet.prefersScrollingExpandsWhenScrolledToEdge = false
    }

    presenter.present(controller, animated: true)
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

private struct NativeLoginSheetCopy {
  let pageTitle: String
  let brandName: String
  let subtitle: String
}

@available(iOS 26.0, *)
private final class NativeLoginSheetViewController: UIViewController, UITextFieldDelegate {
  private let copy: NativeLoginSheetCopy
  private let channel: FlutterMethodChannel
  private let onDismiss: () -> Void

  private let titleLabel = UILabel()
  private let subtitleLabel = UILabel()
  private let segmentedControl = UISegmentedControl(items: ["短信", "统一认证"])
  private let feedbackLabel = UILabel()
  private let smsStack = UIStackView()
  private let egateStack = UIStackView()
  private let phoneField = UITextField()
  private let codeField = UITextField()
  private let usernameField = UITextField()
  private let passwordField = UITextField()
  private let sendCodeButton = UIButton(type: .system)
  private let smsLoginButton = UIButton(type: .system)
  private let egateLoginButton = UIButton(type: .system)

  private var didNotifyDismiss = false
  private var cooldown = 0
  private var cooldownTimer: Timer?

  init(
    copy: NativeLoginSheetCopy,
    channel: FlutterMethodChannel,
    onDismiss: @escaping () -> Void
  ) {
    self.copy = copy
    self.channel = channel
    self.onDismiss = onDismiss
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  deinit {
    cooldownTimer?.invalidate()
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    view.backgroundColor = .systemBackground
    isModalInPresentation = false
    buildViewHierarchy()
    configureContent()
    updateSelectedMode()
  }

  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)

    if isBeingDismissed || presentingViewController == nil {
      notifyDismiss()
    }
  }

  private func notifyDismiss() {
    guard !didNotifyDismiss else { return }
    didNotifyDismiss = true
    cooldownTimer?.invalidate()
    onDismiss()
  }

  private func buildViewHierarchy() {
    let rootStack = UIStackView()
    rootStack.axis = .vertical
    rootStack.spacing = 18
    rootStack.translatesAutoresizingMaskIntoConstraints = false
    rootStack.isLayoutMarginsRelativeArrangement = true
    rootStack.directionalLayoutMargins = NSDirectionalEdgeInsets(
      top: 22,
      leading: 22,
      bottom: 24,
      trailing: 22
    )

    let headerStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
    headerStack.axis = .vertical
    headerStack.spacing = 4

    feedbackLabel.numberOfLines = 0
    feedbackLabel.isHidden = true

    rootStack.addArrangedSubview(headerStack)
    rootStack.addArrangedSubview(segmentedControl)
    rootStack.addArrangedSubview(smsStack)
    rootStack.addArrangedSubview(egateStack)
    rootStack.addArrangedSubview(feedbackLabel)

    view.addSubview(rootStack)

    NSLayoutConstraint.activate([
      rootStack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
      rootStack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
      rootStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
      rootStack.bottomAnchor.constraint(lessThanOrEqualTo: view.keyboardLayoutGuide.topAnchor)
    ])
  }

  private func configureContent() {
    titleLabel.text = copy.brandName
    titleLabel.font = .preferredFont(forTextStyle: .title2)
    titleLabel.adjustsFontForContentSizeCategory = true

    subtitleLabel.text = copy.subtitle
    subtitleLabel.font = .preferredFont(forTextStyle: .subheadline)
    subtitleLabel.textColor = .secondaryLabel
    subtitleLabel.adjustsFontForContentSizeCategory = true

    segmentedControl.selectedSegmentIndex = 0
    segmentedControl.addTarget(
      self,
      action: #selector(handleModeChanged),
      for: .valueChanged
    )

    configureTextField(
      phoneField,
      placeholder: "手机号码",
      keyboardType: .phonePad,
      textContentType: .telephoneNumber,
      returnKeyType: .next
    )
    configureTextField(
      codeField,
      placeholder: "验证码",
      keyboardType: .numberPad,
      textContentType: .oneTimeCode,
      returnKeyType: .done
    )
    configureTextField(
      usernameField,
      placeholder: "学号",
      keyboardType: .default,
      textContentType: .username,
      returnKeyType: .next
    )
    configureTextField(
      passwordField,
      placeholder: "密码",
      keyboardType: .default,
      textContentType: .password,
      returnKeyType: .done
    )
    passwordField.isSecureTextEntry = true

    configureButton(sendCodeButton, title: "发送验证码", prominent: false)
    configureButton(smsLoginButton, title: copy.pageTitle, prominent: true)
    configureButton(egateLoginButton, title: copy.pageTitle, prominent: true)

    sendCodeButton.addTarget(self, action: #selector(handleSendCode), for: .touchUpInside)
    smsLoginButton.addTarget(self, action: #selector(handleSmsLogin), for: .touchUpInside)
    egateLoginButton.addTarget(self, action: #selector(handleEgateLogin), for: .touchUpInside)

    smsStack.axis = .vertical
    smsStack.spacing = 12
    smsStack.addArrangedSubview(phoneField)
    smsStack.addArrangedSubview(makeHorizontalStack([codeField, sendCodeButton]))
    smsStack.addArrangedSubview(smsLoginButton)

    egateStack.axis = .vertical
    egateStack.spacing = 12
    egateStack.addArrangedSubview(usernameField)
    egateStack.addArrangedSubview(passwordField)
    egateStack.addArrangedSubview(egateLoginButton)

    feedbackLabel.font = .preferredFont(forTextStyle: .footnote)
    feedbackLabel.adjustsFontForContentSizeCategory = true
    feedbackLabel.textColor = .systemRed
  }

  private func configureTextField(
    _ textField: UITextField,
    placeholder: String,
    keyboardType: UIKeyboardType,
    textContentType: UITextContentType?,
    returnKeyType: UIReturnKeyType
  ) {
    textField.placeholder = placeholder
    textField.keyboardType = keyboardType
    textField.textContentType = textContentType
    textField.returnKeyType = returnKeyType
    textField.borderStyle = .roundedRect
    textField.clearButtonMode = .whileEditing
    textField.delegate = self
    textField.heightAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true
  }

  private func configureButton(
    _ button: UIButton,
    title: String,
    prominent: Bool
  ) {
    var configuration: UIButton.Configuration = prominent ? .prominentGlass() : .glass()
    configuration.title = title
    configuration.cornerStyle = .capsule
    button.configuration = configuration
    button.heightAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true
  }

  private func makeHorizontalStack(_ views: [UIView]) -> UIStackView {
    let stack = UIStackView(arrangedSubviews: views)
    stack.axis = .horizontal
    stack.spacing = 10
    stack.alignment = .fill
    stack.distribution = .fill
    return stack
  }

  @objc
  private func handleModeChanged() {
    clearFeedback()
    updateSelectedMode()
  }

  private func updateSelectedMode() {
    let useSms = segmentedControl.selectedSegmentIndex == 0
    smsStack.isHidden = !useSms
    egateStack.isHidden = useSms
  }

  @objc
  private func handleSendCode() {
    let phone = trimmedText(phoneField)
    guard !phone.isEmpty else {
      showFeedback("请输入手机号码")
      return
    }

    setLoading(sendCodeButton, true)
    channel.invokeMethod(
      "nativeLoginSheet.sendSms",
      arguments: ["phone": phone]
    ) { [weak self] response in
      DispatchQueue.main.async {
        guard let self else { return }
        self.setLoading(self.sendCodeButton, false)
        self.handleResponse(response) {
          self.startCooldown()
        }
      }
    }
  }

  @objc
  private func handleSmsLogin() {
    let phone = trimmedText(phoneField)
    let code = trimmedText(codeField)
    guard !phone.isEmpty, !code.isEmpty else {
      showFeedback("请输入手机号码和验证码")
      return
    }

    setLoading(smsLoginButton, true)
    channel.invokeMethod(
      "nativeLoginSheet.smsLogin",
      arguments: ["phone": phone, "code": code]
    ) { [weak self] response in
      DispatchQueue.main.async {
        guard let self else { return }
        self.setLoading(self.smsLoginButton, false)
        self.handleResponse(response) {
          self.dismiss(animated: true)
        }
      }
    }
  }

  @objc
  private func handleEgateLogin() {
    let username = trimmedText(usernameField)
    let password = trimmedText(passwordField)
    guard !username.isEmpty, !password.isEmpty else {
      showFeedback("请输入学号和密码")
      return
    }

    setLoading(egateLoginButton, true)
    channel.invokeMethod(
      "nativeLoginSheet.egateLogin",
      arguments: ["username": username, "password": password]
    ) { [weak self] response in
      DispatchQueue.main.async {
        guard let self else { return }
        self.setLoading(self.egateLoginButton, false)
        self.handleResponse(response) {
          self.dismiss(animated: true)
        }
      }
    }
  }

  private func handleResponse(_ response: Any?, success: () -> Void) {
    guard let payload = response as? [String: Any] else {
      showFeedback("操作失败，请稍后重试")
      return
    }

    if payload["ok"] as? Bool == true {
      clearFeedback()
      success()
      return
    }

    showFeedback(payload["message"] as? String ?? "操作失败，请稍后重试")
  }

  private func setLoading(_ button: UIButton, _ loading: Bool) {
    button.isEnabled = !loading
  }

  private func trimmedText(_ textField: UITextField) -> String {
    (textField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func showFeedback(_ message: String) {
    feedbackLabel.text = message
    feedbackLabel.isHidden = false
  }

  private func clearFeedback() {
    feedbackLabel.text = nil
    feedbackLabel.isHidden = true
  }

  private func startCooldown() {
    cooldown = 60
    updateSendButtonTitle()
    cooldownTimer?.invalidate()
    cooldownTimer = Timer.scheduledTimer(
      withTimeInterval: 1,
      repeats: true
    ) { [weak self] timer in
      guard let self else {
        timer.invalidate()
        return
      }

      self.cooldown -= 1
      if self.cooldown <= 0 {
        timer.invalidate()
        self.cooldown = 0
      }
      self.updateSendButtonTitle()
    }
  }

  private func updateSendButtonTitle() {
    var configuration = sendCodeButton.configuration ?? .glass()
    configuration.title = cooldown > 0 ? "\(cooldown)s" : "发送验证码"
    sendCodeButton.configuration = configuration
    sendCodeButton.isEnabled = cooldown == 0
  }

  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    switch textField {
    case phoneField:
      codeField.becomeFirstResponder()
    case usernameField:
      passwordField.becomeFirstResponder()
    case codeField:
      textField.resignFirstResponder()
      handleSmsLogin()
    case passwordField:
      textField.resignFirstResponder()
      handleEgateLogin()
    default:
      textField.resignFirstResponder()
    }
    return true
  }
}
