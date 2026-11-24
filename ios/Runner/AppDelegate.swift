import CoreMotion
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let messenger = engineBridge.applicationRegistrar.messenger()
    IndoorArChannel.register(messenger: messenger)
    FlutterEventChannel(name: "navipet/floor_pressure", binaryMessenger: messenger)
      .setStreamHandler(FloorPressureStream())
  }
}

private final class FloorPressureStream: NSObject, FlutterStreamHandler {
  private var altimeter: CMAltimeter?

  func onListen(withArguments arguments: Any?, eventSink sink: @escaping FlutterEventSink)
    -> FlutterError?
  {
    guard CMAltimeter.isRelativeAltitudeAvailable() else {
      sink(FlutterError(code: "NO_SENSOR", message: nil, details: nil))
      return nil
    }
    let authorization = CMAltimeter.authorizationStatus()
    if authorization == .denied || authorization == .restricted {
      sink(FlutterError(code: "PERMISSION_DENIED", message: "Motion access denied", details: nil))
      return nil
    }
    let altimeter = CMAltimeter()
    self.altimeter = altimeter
    altimeter.startRelativeAltitudeUpdates(to: .main) { [weak self, weak altimeter] data, error in
      guard let altimeter, self?.altimeter === altimeter else { return }
      if let error {
        sink(FlutterError(code: "UNAVAILABLE", message: error.localizedDescription, details: nil))
        return
      }
      guard let data else { return }
      let uptime = ProcessInfo.processInfo.systemUptime
      let wallTime = Date().timeIntervalSince1970
      let capturedAt = wallTime - (uptime - data.timestamp)
      sink([data.pressure.doubleValue * 10, Int64(capturedAt * 1_000_000)] as [Any])
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    altimeter?.stopRelativeAltitudeUpdates()
    altimeter = nil
    return nil
  }
}
