# Building navigation simulator checks

These flows run against a **debug-only mock target**, `tool/navigation_e2e.dart`.
It uses the production MapScreen, navigation controller and Mapbox renderer.
College of Business and Horn Center outlines are OpenStreetMap test data
(relation 6573042 with its courtyard hole, way 35568170), not backend
footprints. The backend still has no footprints for these buildings. Outdoor
points match campus_destinations. Routes, GPS accuracy and search responses
are fixtures and do not establish campus entrance coverage.
No backend account or credentials are needed. The native map uses the existing
public Mapbox token from `.env`; do not print or copy `.env` into evidence.

Build and install (substitute your simulator UUID):

```sh
flutter build ios --simulator --debug --target=tool/navigation_e2e.dart
xcrun simctl install <UUID> build/ios/iphonesimulator/Runner.app
```

Run each flow separately with Maestro 2.12.0. Keep artifacts outside the repo:

```sh
maestro test --udid <UUID> --test-output-dir /tmp/navipet-outside .maestro/navigation_outside.yaml
maestro test --udid <UUID> --test-output-dir /tmp/navipet-inside .maestro/navigation_inside.yaml
maestro test --udid <UUID> --test-output-dir /tmp/navipet-uncertain .maestro/navigation_uncertain.yaml
```

- Outside: real Horn Center outdoor point to the College of Business outdoor
  point; OSM footprint, preview, and walking guidance; exactly one route request.
- Inside: two fresh accurate readings inside the OSM ring, clear of the
  courtyard; existing arrived state and Return to map; zero route requests and
  no separate already-here UI. The outdoor pin is too close to the courtyard
  hole for a 5 m fix to count as inside.
- Uncertain: 80 m GPS accuracy at the outdoor pin; refresh/continue choice
  without false arrival; explicit continuation requests the walking route.
- Destinations without a footprint skip the presence check at Start Route and use
  the marker-radius / route-end arrival fallback. These flows do not cover that path;
  see `test/destination_presence_flow_test.dart` and `test/arrival_radius_test.dart`.

The debug header exposes controller status and route-request count as observable
assertions. Screenshots and recordings are saved by Maestro in the specified
artifact directory. Build production normally with `lib/main.dart`.
