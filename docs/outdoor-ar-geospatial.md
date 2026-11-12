# Outdoor AR with ARCore Geospatial

During an active outdoor walk the map shows an outdoor AR control. Mapbox
stays the default outdoor navigation and indoor AR stays on MultiSet; outdoor
AR is an optional camera view opened on top of the walk.

This is the Flutter half. The Unity outdoor scene from
[NaviPetUnity#19](https://github.com/navipet-senior-project/NaviPetUnity/pull/19)
is a prototype that the exported library does not include yet, so **no build
can run outdoor AR end to end today**. Nothing here has been tested on a phone,
on campus, or against the ARCore API. No coverage, accuracy or route quality
is claimed.

## Turning it on

Outdoor AR is off unless the app is built with:

```sh
flutter run --dart-define=NAVIPET_OUTDOOR_AR=true
```

Set the flag only when the private Unity library (see
[Unity AR without installing Unity](../README.md#unity-ar-without-installing-unity))
includes the outdoor scene. Without the flag the control says outdoor AR is
unavailable and opens nothing, which is the behaviour of every current build.

## What the app does

1. Shows Google's required ARCore notice with its "Learn more" and privacy
   policy links. "Not now" returns to the map.
2. Asks for camera access. Location access is already held by the walk.
3. Sends one request over the existing `navipet/indoor_ar` channel. The same
   native host runs indoor and outdoor AR, so only one AR session exists at a
   time and no Kotlin or Swift changed.
4. Returns to the map when Unity finishes. The route, the destination and the
   navigation state are never touched.

Each of these keeps the walk on the map and explains why in a dialog: no Unity
library, a Unity library without the outdoor scene (it answers `BAD_REQUEST`),
camera access refused, or a session that fails.

## Bridge contract

Request (JSON string, `lib/data/outdoor_ar_contract.dart`):

```json
{
  "schemaVersion": 2,
  "mode": "outdoor",
  "destination": {"name": "Horn Center", "latitude": 33.78, "longitude": -118.11},
  "dataUseAccepted": true
}
```

`destination` is the WGS84 point the walking route ends at. No MultiSet token
and no Google credential is sent.

Result: the indoor result envelope, unchanged (`status`, `localizationQueries`,
`durationMs`, optional `errorCode`). Outdoor sessions report
`localizationQueries: 0`. `cancelled` and `arrived` return silently; anything
else shows the unavailable dialog.

## What Unity still has to provide

- Export the outdoor scene in the Android AAR and the iOS `UnityFramework`.
- Start it for `mode: "outdoor"`, and deliver a result through the existing
  bridge.
- Skip its own consent screen when `dataUseAccepted` is true.
- Request precise location itself; Geospatial does not work with approximate
  location.
- Carry the Google Play services dependencies and ProGuard rules that ARCore
  Extensions needs in `maven-deps.txt` and the AAR's consumer rules.
- ARCore Extensions on iOS, which the prototype did not set up.

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
