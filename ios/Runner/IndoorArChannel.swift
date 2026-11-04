import Flutter
import UIKit

#if UNITY_AR_ENABLED
import UnityFramework
#endif

/// Starts the embedded Unity AR player for one request and answers the Dart
/// call with the result JSON once Unity finishes. Always replies with a result
/// string, never a platform error.
///
/// Unity is linked only when ios/unity-ar/UnityAr.xcconfig defines
/// UNITY_AR_ENABLED; otherwise every launch answers `unavailable`.
///
/// The request JSON (bridge contract v2) may carry a short-lived `arToken`.
/// Never log the request.
final class IndoorArChannel {
  static let name = "navipet/indoor_ar"

  static func register(messenger: FlutterBinaryMessenger) {
    let host = IndoorArChannel()
    FlutterMethodChannel(name: name, binaryMessenger: messenger)
      .setMethodCallHandler { call, result in host.handle(call, result) }
  }

  private func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    guard call.method == "launch" else {
      result(FlutterMethodNotImplemented)
      return
    }
    #if UNITY_AR_ENABLED
    guard let request = call.arguments as? String,
      !request.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      pending == nil
    else {
      result(IndoorArResults.error(IndoorArResults.badRequest, durationMs: 0))
      return
    }
    launchUnity(request: request, result: result)
    #else
    result(IndoorArResults.unavailable())
    #endif
  }

  #if UNITY_AR_ENABLED
  private var pending: FlutterResult?
  private var startedAt = Date()
  private var flutterWindow: UIWindow?
  private var unity: UnityFramework?
  private lazy var listener = UnityListener(
    onUnload: { [weak self] in self?.finish("") }
  )

  private func launchUnity(request: String, result: @escaping FlutterResult) {
    guard let ufw = loadUnity(), let host = NSClassFromString("IndoorArHost") as? NSObject.Type
    else {
      result(IndoorArResults.unavailable())
      return
    }
    pending = result
    startedAt = Date()
    flutterWindow = UIApplication.shared.connectedScenes
      .compactMap { ($0 as? UIWindowScene)?.keyWindow }.first

    // IndoorArHost lives in UnityFramework; call it by name so the build
    // does not depend on the export exposing its header.
    host.perform(NSSelectorFromString("setRequest:"), with: request)
    let handler: @convention(block) (NSString) -> Void = { [weak self] json in
      self?.finish(json as String)
    }
    host.perform(
      NSSelectorFromString("setResultHandler:"), with: unsafeBitCast(handler, to: AnyObject.self))

    ufw.register(listener)
    if ufw.appController() == nil {
      ufw.setDataBundleId("com.unity3d.framework")
      ufw.runEmbedded(withArgc: CommandLine.argc, argv: CommandLine.unsafeArgv, appLaunchOpts: nil)
    }
    ufw.showUnityWindow()
  }

  private func loadUnity() -> UnityFramework? {
    if let unity { return unity }
    let path = Bundle.main.bundlePath + "/Frameworks/UnityFramework.framework"
    guard let bundle = Bundle(path: path), bundle.isLoaded || bundle.load(),
      let ufw = (bundle.principalClass as? UnityFramework.Type)?.getInstance()
    else { return nil }
    unity = ufw
    return ufw
  }

  /// Answers the pending call once, then hands the screen back to Flutter.
  private func finish(_ json: String) {
    guard let result = pending else { return }
    pending = nil
    unity?.unregisterFrameworkListener(listener)
    unity?.unloadApplication()
    flutterWindow?.makeKeyAndVisible()
    flutterWindow = nil
    result(json.isEmpty ? exitedResult() : json)
  }

  private func exitedResult() -> String {
    IndoorArResults.error(
      IndoorArResults.unityExited, durationMs: Int(Date().timeIntervalSince(startedAt) * 1000))
  }
  #endif
}

#if UNITY_AR_ENABLED
private final class UnityListener: NSObject, UnityFrameworkListener {
  private let onUnload: () -> Void
  init(onUnload: @escaping () -> Void) { self.onUnload = onUnload }
  func unityDidUnload(_ notification: Notification!) { onUnload() }
  func unityDidQuit(_ notification: Notification!) { onUnload() }
}
#endif
