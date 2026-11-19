import CoreMotion
import Flutter
import Foundation

/// Streams CMAltimeter pressure converted from kPa to Pa.
final class IndoorPressureStream: NSObject, FlutterStreamHandler {
  static func register(messenger: FlutterBinaryMessenger) {
    let handler = IndoorPressureStream()
    FlutterEventChannel(name: "navipet/indoor_pressure", binaryMessenger: messenger)
      .setStreamHandler(handler)
  }

  private let altimeter = CMAltimeter()
  private var eventSink: FlutterEventSink?

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    guard CMAltimeter.isRelativeAltitudeAvailable() else { return nil }
    eventSink = events
    altimeter.startRelativeAltitudeUpdates(to: OperationQueue.main) { [weak self] data, error in
      guard let self, error == nil, let pressure = data?.pressure else { return }
      self.eventSink?(pressure.doubleValue * 1000.0)
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    altimeter.stopRelativeAltitudeUpdates()
    eventSink = nil
    return nil
  }
}
