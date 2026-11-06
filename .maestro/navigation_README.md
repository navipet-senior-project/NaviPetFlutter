# Building navigation simulator checks

These flows run against a **debug-only mock target**, `tool/navigation_e2e.dart`.
It uses the production MapScreen, navigation controller and Mapbox renderer.
All building outlines, routes, GPS accuracy and search responses are synthetic
verification fixtures. They do not establish real campus footprint/entrance coverage.
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

- Outside: mocked Horn Center origin to mocked College of Business target;
  selected footprint, preview, and walking guidance; exactly one route request.
- Inside: two fresh accurate readings; existing arrived state and Return to map;
  zero route requests and no separate already-here UI.
- Uncertain: 80 m GPS accuracy; refresh/continue choice without false arrival;
  explicit continuation requests the walking route.

The debug header exposes controller status and route-request count as observable
assertions. Screenshots and recordings are saved by Maestro in the specified
artifact directory. Build production normally with `lib/main.dart`.
