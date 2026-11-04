import Foundation

/// Bridge contract v2 results the host builds itself, for outcomes Unity never
/// reports. Unity's own result JSON passes through untouched; Dart validates it.
enum IndoorArResults {
  static let badRequest = "BAD_REQUEST"
  static let busy = "BUSY"
  static let unityExited = "UNITY_EXITED"

  static func unavailable() -> String {
    "{\"status\":\"unavailable\",\"localizationQueries\":0,\"durationMs\":0}"
  }

  // code is always one of the constants above, so it needs no escaping.
  static func error(_ code: String, durationMs: Int) -> String {
    "{\"status\":\"error\",\"errorCode\":\"\(code)\",\"localizationQueries\":0,\"durationMs\":\(durationMs)}"
  }
}
