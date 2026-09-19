/// Ways to travel to a campus destination.
///
/// Only the modes in [enabledTravelModes] are offered. The others are declared
/// so that enabling one later is a registry change, not a UI restructure —
/// each needs routing data NaviPet does not have yet.
enum TravelMode {
  walking,
  accessible,
  shuttle,
  cycling;

  String get label => switch (this) {
    TravelMode.walking => 'Walking',
    TravelMode.accessible => 'Accessible route',
    TravelMode.shuttle => 'Shuttle',
    TravelMode.cycling => 'Cycling',
  };

  /// Mapbox Directions profile used to request this mode.
  ///
  /// [TravelMode.accessible] currently maps to the plain Mapbox `walking`
  /// profile, identical to [TravelMode.walking]. That profile makes no
  /// accessibility guarantees — no curb ramps, stairs, or elevators are
  /// accounted for. Do not add [TravelMode.accessible] to
  /// [enabledTravelModes] until real accessible-routing data backs it.
  String get directionsProfile => switch (this) {
    TravelMode.walking || TravelMode.accessible => 'walking',
    TravelMode.shuttle => 'driving',
    TravelMode.cycling => 'cycling',
  };
}

const List<TravelMode> enabledTravelModes = [TravelMode.walking];
