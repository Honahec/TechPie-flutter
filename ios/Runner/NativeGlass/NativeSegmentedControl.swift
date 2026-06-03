import Flutter
import UIKit

final class NativeSegmentedControlFactory: NSObject, FlutterPlatformViewFactory {
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
    NativeSegmentedControlPlatformView(
      frame: frame,
      viewId: viewId,
      arguments: args,
      messenger: messenger
    )
  }
}

final class NativeSegmentedControlPlatformView: NSObject, FlutterPlatformView {
  static let viewType = "techpie/native_segmented_control"

  private let rootView: UIView
  private let channel: FlutterMethodChannel
  private let control = UISegmentedControl()

  private var segments: [String] = []
  private var selectedIndex = 0

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

    parseConfiguration(args as? [String: Any] ?? [:])
    buildViewHierarchy()
    applyConfiguration()

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

    control.translatesAutoresizingMaskIntoConstraints = false
    control.addTarget(self, action: #selector(handleValueChanged), for: .valueChanged)

    rootView.addSubview(control)

    NSLayoutConstraint.activate([
      control.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
      control.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
      control.centerYAnchor.constraint(equalTo: rootView.centerYAnchor),
    ])
  }

  private func parseConfiguration(_ params: [String: Any]) {
    segments = params["segments"] as? [String] ?? segments
    selectedIndex = params["value"] as? Int ?? selectedIndex
  }

  private func applyConfiguration() {
    control.removeAllSegments()

    for (index, title) in segments.enumerated() {
      control.insertSegment(withTitle: title, at: index, animated: false)
    }

    if segments.indices.contains(selectedIndex) {
      control.selectedSegmentIndex = selectedIndex
    } else if !segments.isEmpty {
      selectedIndex = 0
      control.selectedSegmentIndex = 0
    } else {
      selectedIndex = UISegmentedControl.noSegment
      control.selectedSegmentIndex = UISegmentedControl.noSegment
    }
  }

  private func handle(call: FlutterMethodCall, result: FlutterResult) {
    switch call.method {
    case "updateConfiguration":
      parseConfiguration(call.arguments as? [String: Any] ?? [:])
      applyConfiguration()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  @objc
  private func handleValueChanged() {
    selectedIndex = control.selectedSegmentIndex
    channel.invokeMethod("onChanged", arguments: ["value": selectedIndex])
  }
}
