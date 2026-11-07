/// A floor hint only. The caller must still ask the user to confirm the floor.
enum FloorPriorConfidence { confirmed, tracked }

class FloorSuggestion {
  const FloorSuggestion({this.floor, this.confidence, this.isStale = false});

  final int? floor;
  final FloorPriorConfidence? confidence;
  final bool isStale;
}

/// In-memory route state. Create a new instance when the active route changes;
/// never persist it across app restarts.
class FloorPrior {
  String? _route;
  int? _floor;
  FloorPriorConfidence? _confidence;
  bool _stale = false;

  void verifiedEntrance(String route, int floor) => confirmFloor(route, floor);

  /// Call only for a floor explicitly confirmed for the active route.
  void confirmFloor(String route, int floor) {
    _route = route;
    _floor = floor;
    _confidence = FloorPriorConfidence.confirmed;
    _stale = false;
  }

  /// Call only when a stair or elevator transition was actually observed.
  void trackedTransition(String route, int floor) {
    if (_route != route || _floor == null || _stale) return;
    _floor = floor;
    _confidence = FloorPriorConfidence.tracked;
  }

  void trackingLost() => _invalidate();
  void unobservedTransition() => _invalidate();

  void _invalidate() {
    if (_route == null) return;
    _floor = null;
    _confidence = null;
    _stale = true;
  }

  FloorSuggestion suggestionFor(String route) {
    if (_route != route) return const FloorSuggestion();
    return FloorSuggestion(
      floor: _floor,
      confidence: _confidence,
      isStale: _stale,
    );
  }
}
