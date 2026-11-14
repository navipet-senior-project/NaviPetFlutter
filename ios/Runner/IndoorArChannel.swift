import Flutter
import UIKit

#if UNITY_AR_ENABLED
import UnityFramework
#endif

/// The few UnityFramework calls the player lifecycle needs, so the lifecycle
/// can be tested without the framework.
protocol ArPlayer: AnyObject {
  var isStarted: Bool { get }
  func start()
  func setPaused(_ paused: Bool)
  func show()
  func hide()
}

/// Unity is started once per process and then only paused and hidden, never
/// unloaded: re-entering a player that was unloaded left the ARKit session
/// without camera frames on iPhone.
enum ArPlayerLifecycle {
  /// `configure` hands the request and listeners to Unity. A started player is
  /// unpaused first, so IndoorArHost does not try to resume a player that was
  /// never unloaded.
  static func enter(_ player: ArPlayer, configure: () -> Void) {
    if player.isStarted { player.setPaused(false) }
    configure()
    if !player.isStarted { player.start() }
    player.show()
  }

  static func exit(_ player: ArPlayer) {
    player.setPaused(true)
    player.hide()
  }
}

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
    guard pending == nil else {
      result(IndoorArResults.error(IndoorArResults.busy, durationMs: 0))
      return
    }
    guard let request = call.arguments as? String,
      !request.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
  private var unity: UnityArPlayer?
  private lazy var listener = UnityListener(
    onUnload: { [weak self] in self?.finish("") }
  )

  private func launchUnity(request: String, result: @escaping FlutterResult) {
    guard let player = loadUnity(), let host = NSClassFromString("IndoorArHost") as? NSObject.Type
    else {
      result(IndoorArResults.unavailable())
      return
    }
    pending = result
    startedAt = Date()
    flutterWindow = UIApplication.shared.connectedScenes
      .compactMap { ($0 as? UIWindowScene)?.keyWindow }.first

    ArPlayerLifecycle.enter(player) {
      // IndoorArHost lives in UnityFramework; call it by name so the build
      // does not depend on the export exposing its header.
      host.perform(NSSelectorFromString("setRequest:"), with: request)
      let handler: @convention(block) (NSString) -> Void = { [weak self] json in
        self?.finish(json as String)
      }
      host.perform(
        NSSelectorFromString("setResultHandler:"), with: unsafeBitCast(handler, to: AnyObject.self))
      player.framework.register(listener)
    }
  }

  private func loadUnity() -> UnityArPlayer? {
    if let unity { return unity }
    let path = Bundle.main.bundlePath + "/Frameworks/UnityFramework.framework"
    guard let bundle = Bundle(path: path), bundle.isLoaded || bundle.load(),
      let ufw = (bundle.principalClass as? UnityFramework.Type)?.getInstance()
    else { return nil }
    let player = UnityArPlayer(ufw)
    unity = player
    return player
  }

  /// Answers the pending call once, then hands the screen back to Flutter.
  private func finish(_ json: String) {
    guard let result = pending else { return }
    pending = nil
    if let unity {
      unity.framework.unregisterFrameworkListener(listener)
      ArPlayerLifecycle.exit(unity)
    }
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
private final class UnityArPlayer: ArPlayer {
  let framework: UnityFramework
  init(_ framework: UnityFramework) { self.framework = framework }

  var isStarted: Bool { framework.appController() != nil }

  func start() {
    framework.setDataBundleId("com.unity3d.framework")
    framework.runEmbedded(
      withArgc: CommandLine.argc, argv: CommandLine.unsafeArgv, appLaunchOpts: nil)
  }

  func setPaused(_ paused: Bool) { framework.pause(paused) }
  func show() { framework.showUnityWindow() }
  func hide() { framework.appController()?.window?.isHidden = true }
}

private final class UnityListener: NSObject, UnityFrameworkListener {
  private let onUnload: () -> Void
  init(onUnload: @escaping () -> Void) { self.onUnload = onUnload }
  func unityDidUnload(_ notification: Notification!) { onUnload() }
  func unityDidQuit(_ notification: Notification!) { onUnload() }
}
#endif
