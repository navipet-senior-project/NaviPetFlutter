# Outdoor AR with ARCore Geospatial

During an active outdoor walk the map shows an outdoor AR control. Mapbox
stays the default outdoor navigation and indoor AR stays on MultiSet; outdoor
AR is an optional camera view opened on top of the walk.

Flutter sends the active walk's destination and selected route to Unity.
Unity's outdoor scene and shared HUD integration are coordinated separately.
**End-to-end behavior remains unverified.** This Flutter handoff has not been
tested on a phone, on campus, or against the ARCore API. No coverage, accuracy
or route quality is claimed.

## Turning it on

Outdoor AR is off unless the app is built with:

```sh
flutter run --dart-define=NAVIPET_OUTDOOR_AR=true
```

Set the flag only when the app's Unity library includes the coordinated outdoor
scene integration. Without the flag the control says outdoor AR is unavailable
and opens nothing.

## What the app does

1. Shows Google's required ARCore notice with its "Learn more" and privacy
   policy links. "Not now" returns to the map.
2. Asks for camera access. Location access is already held by the walk.
3. Sends one request over the existing `navipet/indoor_ar` channel. The same
   native host runs indoor and outdoor AR, so only one AR session exists at a
   time. On iOS the host keeps Unity started between sessions, pausing and
   hiding it on exit and resuming it on re-entry.
4. Returns to the map when Unity finishes. The route, the destination and the
   navigation state are never touched.

Each failure keeps the walk on the map and explains why in a dialog, including
missing Unity support, camera access refusal, or a failed session.

## Bridge contract

Request (JSON string, `lib/data/outdoor_ar_contract.dart`):

```json
{
  "schemaVersion": 2,
  "mode": "outdoor",
  "destination": {"name": "Horn Center", "latitude": 33.78, "longitude": -118.11},
  "dataUseAccepted": true,
  "route": {"waypoints": [{"latitude": 33.779, "longitude": -118.113}, {"latitude": 33.78, "longitude": -118.11}]}
}
```

`destination` is the WGS84 point the walking route ends at. No MultiSet token
and no Google credential is sent.

`route.waypoints` is the active walk's remaining route geometry, ordered from
the current progress to the destination, WGS84. If remaining geometry is
empty, Flutter sends the selected Mapbox walking route's full coordinates.
Flutter sends this route for the coordinated Unity implementation to render in
the shared indoor/outdoor AR HUD:

- Douglas-Peucker simplification drops points within 2 m of the segment that
  replaces them. First and last points stay. If the result exceeds 1000 points,
  Flutter widens the tolerance until the whole ordered route fits.
- A route with fewer than 2 points, or any NaN or out-of-range coordinate, is
  not sent. `route` is then absent; Unity must not present route-following
  guidance without route geometry.
- Flutter does not reroute for Unity and sends the route once, at launch. The
  walk's own route stays authoritative on the map.

The route is the same location data the walk already holds. It is sent only to
the on-device Unity host, after the ARCore notice is accepted.

Result: the indoor result envelope, unchanged (`status`, `localizationQueries`,
`durationMs`, optional `errorCode`). Outdoor sessions report
`localizationQueries: 0`. `cancelled` and `arrived` return silently; anything
else shows the unavailable dialog.

## Unity integration boundary

The Unity implementation is a separate coordinated change. It must consume
`mode: "outdoor"` and `route.waypoints` in the shared indoor/outdoor AR HUD.
Flutter sends the selected route once at launch and keeps Mapbox navigation
authoritative. End-to-end route guidance remains unverified.

The Unity build also needs to:

- Export the outdoor scene in the Android AAR and the iOS `UnityFramework`.
- Start it for `mode: "outdoor"`, and deliver a result through the existing
  bridge.
- Skip its own consent screen when `dataUseAccepted` is true.
- Avoid claiming route following when `route` is absent. Unity detects no
  obstacles; obstacle avoidance depends on the Mapbox walking route and remains
  unverified.
- Request precise location itself; Geospatial does not work with approximate
  location.
- Carry the Google Play services dependencies and ProGuard rules that ARCore
  Extensions needs in `maven-deps.txt` and the AAR's consumer rules.
- ARCore Extensions support on iOS.

## Google Cloud

The app holds no Google key. Do not add an API key, an OAuth JSON file or a
service account key to this repository.

- **Android** uses Keyless authorisation: an Android OAuth client in the Cloud
  project matched on package name (`com.navipet.navipet`) and the SHA-1 of the
  certificate that signed the APK. Release builds are signed with the debug
  key, so the certificate is each machine's own `~/.android/debug.keystore`.
  A build from a machine whose fingerprint is not registered will not be
  authorised.
- **iOS** needs either an API key or a token signed by a service account on a
  server. Neither exists, so iOS outdoor AR cannot authorise yet.

To check a machine's fingerprint against the Cloud client, without sharing it:

```sh
./android/gradlew -p android :app:signingReport
```

Compare the `SHA1` of the variant you install with the fingerprint on the
OAuth client's page in the Cloud console. Changing the client, or anything
else in the Cloud project, needs the project owner's approval.
