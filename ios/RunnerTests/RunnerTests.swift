import Flutter
import UIKit
import XCTest

@testable import Runner

class RunnerTests: XCTestCase {

  func testExample() {
    // If you add code to the Runner application, consider adding tests here.
    // See https://developer.apple.com/documentation/xctest for more information about using XCTest.
  }

}

/// Records the calls the lifecycle makes. `started` flips on `start`, like the
/// real player's appController.
private final class FakeArPlayer: ArPlayer {
  var calls: [String] = []
  var isStarted = false

  func start() {
    calls.append("start")
    isStarted = true
  }
  func setPaused(_ paused: Bool) { calls.append(paused ? "pause" : "resume") }
  func show() { calls.append("show") }
  func hide() { calls.append("hide") }
}

class ArPlayerLifecycleTests: XCTestCase {

  func testFirstEnterConfiguresThenStartsAndShows() {
    let player = FakeArPlayer()
    ArPlayerLifecycle.enter(player) { player.calls.append("configure") }
    XCTAssertEqual(player.calls, ["configure", "start", "show"])
  }

  func testReEnterResumesBeforeConfigureAndDoesNotRestart() {
    let player = FakeArPlayer()
    ArPlayerLifecycle.enter(player) {}
    ArPlayerLifecycle.exit(player)
    player.calls = []

    ArPlayerLifecycle.enter(player) { player.calls.append("configure") }
    XCTAssertEqual(player.calls, ["resume", "configure", "show"])
  }

  func testReEnterConfiguresTheSameRequestAgain() {
    let player = FakeArPlayer()
    var seen: [String] = []
    ArPlayerLifecycle.enter(player) { seen.append("room-a") }
    ArPlayerLifecycle.exit(player)
    ArPlayerLifecycle.enter(player) { seen.append("room-a") }
    XCTAssertEqual(seen, ["room-a", "room-a"])
    XCTAssertEqual(player.calls.filter { $0 == "start" }.count, 1)
  }

  func testExitPausesAndHidesWithoutUnloading() {
    let player = FakeArPlayer()
    ArPlayerLifecycle.enter(player) {}
    player.calls = []

    ArPlayerLifecycle.exit(player)
    XCTAssertEqual(player.calls, ["pause", "hide"])
    XCTAssertTrue(player.isStarted)
  }

  func testRepeatedEntriesStartTheProcessPlayerOnce() {
    let player = FakeArPlayer()
    for _ in 0..<3 {
      ArPlayerLifecycle.enter(player) {}
      ArPlayerLifecycle.exit(player)
    }
    XCTAssertEqual(player.calls.filter { $0 == "start" }.count, 1)
  }
}
