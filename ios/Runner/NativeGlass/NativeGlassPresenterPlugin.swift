import Flutter
import SwiftUI
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
      alert.addAction(
        UIAlertAction(title: "OK", style: .default) { _ in
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

    let controller = NativeLoginSheetHostingController(
      copy: copy,
      channel: channel,
      onDismiss: complete
    )
    controller.modalPresentationStyle = .pageSheet

    if let sheet = controller.sheetPresentationController {
      sheet.detents = [.large()]
      sheet.selectedDetentIdentifier = .large
      sheet.prefersGrabberVisible = false
      sheet.prefersScrollingExpandsWhenScrolledToEdge = false
    }

    presenter.present(controller, animated: true)
  }

  private func topViewController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .filter { $0.activationState == .foregroundActive }

    let keyWindow =
      scenes
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
private final class NativeLoginSheetHostingController: UIHostingController<NativeLoginSheetView> {
  private let model: NativeLoginSheetModel
  private let onDismiss: () -> Void
  private var didNotifyDismiss = false

  init(
    copy: NativeLoginSheetCopy,
    channel: FlutterMethodChannel,
    onDismiss: @escaping () -> Void
  ) {
    let model = NativeLoginSheetModel(copy: copy, channel: channel)
    self.model = model
    self.onDismiss = onDismiss
    super.init(rootView: NativeLoginSheetView(model: model))
    model.dismiss = { [weak self] in
      self?.dismiss(animated: true)
    }
  }

  @MainActor
  required dynamic init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  deinit {
    model.invalidate()
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    isModalInPresentation = false
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
    model.invalidate()
    onDismiss()
  }
}

@available(iOS 26.0, *)
private enum NativeLoginMode: String, CaseIterable {
  case sms
  case egate
}

@available(iOS 26.0, *)
private final class NativeLoginSheetModel: ObservableObject {
  private let copy: NativeLoginSheetCopy
  private let channel: FlutterMethodChannel
  var dismiss: (() -> Void)?

  @Published var mode: NativeLoginMode = .sms {
    didSet {
      feedback = nil
    }
  }
  @Published var phone = ""
  @Published var code = ""
  @Published var username = ""
  @Published var password = ""
  @Published var feedback: String?
  @Published var isSendingCode = false
  @Published var isSmsLoggingIn = false
  @Published var isEgateLoggingIn = false
  @Published var cooldown = 0

  private var cooldownTimer: Timer?

  init(
    copy: NativeLoginSheetCopy,
    channel: FlutterMethodChannel
  ) {
    self.copy = copy
    self.channel = channel
  }

  func invalidate() {
    cooldownTimer?.invalidate()
    cooldownTimer = nil
  }

  var title: String {
    copy.brandName
  }

  var subtitle: String {
    copy.subtitle
  }

  var loginButtonTitle: String {
    copy.pageTitle
  }

  var sendCodeTitle: String {
    cooldown > 0 ? "\(cooldown)s" : "发送验证码"
  }

  var canSendCode: Bool {
    !isSendingCode && cooldown == 0
  }

  func sendSms() {
    let phone = trimmed(phone)
    guard !phone.isEmpty else {
      feedback = "请输入手机号码"
      return
    }

    isSendingCode = true
    channel.invokeMethod(
      "nativeLoginSheet.sendSms",
      arguments: ["phone": phone]
    ) { [weak self] response in
      DispatchQueue.main.async {
        guard let self else { return }
        self.isSendingCode = false
        self.handleResponse(response) {
          self.startCooldown()
        }
      }
    }
  }

  func smsLogin() {
    let phone = trimmed(phone)
    let code = trimmed(code)
    guard !phone.isEmpty, !code.isEmpty else {
      feedback = "请输入手机号码和验证码"
      return
    }

    isSmsLoggingIn = true
    channel.invokeMethod(
      "nativeLoginSheet.smsLogin",
      arguments: ["phone": phone, "code": code]
    ) { [weak self] response in
      DispatchQueue.main.async {
        guard let self else { return }
        self.isSmsLoggingIn = false
        self.handleResponse(response) {
          self.dismiss?()
        }
      }
    }
  }

  func egateLogin() {
    let username = trimmed(username)
    let password = trimmed(password)
    guard !username.isEmpty, !password.isEmpty else {
      feedback = "请输入学号和密码"
      return
    }

    isEgateLoggingIn = true
    channel.invokeMethod(
      "nativeLoginSheet.egateLogin",
      arguments: ["username": username, "password": password]
    ) { [weak self] response in
      DispatchQueue.main.async {
        guard let self else { return }
        self.isEgateLoggingIn = false
        self.handleResponse(response) {
          self.dismiss?()
        }
      }
    }
  }

  private func handleResponse(_ response: Any?, success: () -> Void) {
    guard let payload = response as? [String: Any] else {
      feedback = "操作失败，请稍后重试"
      return
    }

    if payload["ok"] as? Bool == true {
      feedback = nil
      success()
      return
    }

    feedback = payload["message"] as? String ?? "操作失败，请稍后重试"
  }

  private func trimmed(_ text: String) -> String {
    text.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func startCooldown() {
    cooldown = 60
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
    }
  }
}

@available(iOS 26.0, *)
private struct NativeLoginSheetView: View {
  @ObservedObject var model: NativeLoginSheetModel
  @FocusState private var focusedField: Field?

  private enum Field: Hashable {
    case phone
    case code
    case username
    case password
  }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          Picker("登录方式", selection: $model.mode) {
            Text("短信").tag(NativeLoginMode.sms)
            Text("统一认证").tag(NativeLoginMode.egate)
          }
        } footer: {
          Text(model.subtitle)
        }

        switch model.mode {
        case .sms:
          smsFields
          smsAction
        case .egate:
          egateFields
          egateAction
        }

        if let feedback = model.feedback {
          Section {
            Text(feedback)
              .foregroundStyle(.red)
          }
        }
      }
      .navigationTitle(model.title)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            model.dismiss?()
          } label: {
            Image(systemName: "xmark")
          }
          .accessibilityLabel("关闭")
        }
      }
    }
  }

  private var smsFields: some View {
    Section {
      TextField("手机号码", text: $model.phone)
        .keyboardType(.phonePad)
        .textContentType(.telephoneNumber)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .focused($focusedField, equals: .phone)

      HStack {
        TextField("验证码", text: $model.code)
          .keyboardType(.numberPad)
          .textContentType(.oneTimeCode)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()
          .focused($focusedField, equals: .code)

        Button(model.sendCodeTitle) {
          model.sendSms()
        }
        .disabled(!model.canSendCode)
      }
    }
  }

  private var smsAction: some View {
    Section {
      Button {
        model.smsLogin()
      } label: {
        loginButtonLabel(isLoading: model.isSmsLoggingIn)
      }
      .disabled(model.isSmsLoggingIn)
    }
  }

  private var egateFields: some View {
    Section {
      TextField("学号", text: $model.username)
        .textContentType(.username)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .submitLabel(.next)
        .focused($focusedField, equals: .username)
        .onSubmit {
          focusedField = .password
        }

      SecureField("密码", text: $model.password)
        .textContentType(.password)
        .submitLabel(.done)
        .focused($focusedField, equals: .password)
        .onSubmit {
          model.egateLogin()
        }
    }
  }

  private var egateAction: some View {
    Section {
      Button {
        model.egateLogin()
      } label: {
        loginButtonLabel(isLoading: model.isEgateLoggingIn)
      }
      .disabled(model.isEgateLoggingIn)
    }
  }

  private func loginButtonLabel(isLoading: Bool) -> some View {
    HStack {
      Spacer()
      if isLoading {
        ProgressView()
      }
      Text(model.loginButtonTitle)
      Spacer()
    }
  }
}
