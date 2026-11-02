import Cocoa
import FlutterMacOS

/// Registering the plugin is enough: it patches the engine at registration.
public final class MacosEditActionsPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    EditActionsPatch.shared.installForFlutter()
    let channel = FlutterMethodChannel(name: "macos_edit_actions", binaryMessenger: registrar.messenger)
    registrar.addMethodCallDelegate(MacosEditActionsPlugin(), channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let patch = EditActionsPatch.shared
    switch call.method {
    case "status":
      result(patch.status)
    case "setEnabled":
      guard let enabled = (call.arguments as? [String: Any])?["enabled"] as? Bool else {
        result(FlutterError(code: "INVALID_ARGUMENTS", message: "Expected enabled boolean.", details: nil))
        return
      }
      patch.enabled = enabled
      result(patch.status)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
