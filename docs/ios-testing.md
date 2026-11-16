# iPhone testing

Indoor AR needs a prebuilt, gitignored `UnityFramework` (see "Indoor AR"
below). Without it the app builds and the `navipet/indoor_ar` channel answers
`unavailable`. The rest of
NaviPet can be tested on an iPhone 14 Plus (iOS 16 or later); the app's
minimum target is iOS 15. No distribution account is needed.

1. Install Flutter, Xcode, and the iOS platform in Xcode Settings. Run
   `xcodebuild -runFirstLaunch` if Xcode requests first-run setup.
2. From the repository root, copy `.env.example` to `.env` and fill in the
   Mapbox public token, Supabase and backend values as described in the README.
   Do not commit `.env`.
3. Run `flutter pub get`, then `open ios/Runner.xcworkspace`.
4. In Xcode Settings > Accounts, add your Apple ID. Connect and unlock your
   iPhone, tap Trust when prompted, and enable Developer Mode in Settings >
   Privacy & Security if requested. Restart and confirm Developer Mode on the
   phone if prompted.
5. In Xcode select the Runner project, Runner target, and Signing &
   Capabilities. Enable automatic signing and choose your Personal Team. If
   the bundle identifier is unavailable, change **Bundle Identifier** on the
   Runner target to your own unique value in Xcode. This changes the local
   project file: discard that change before committing. Keep your team and
   signing settings local; do not commit them.
6. Select your iPhone as the run destination and press Run. If iOS refuses to
   open the app, open Settings > General > VPN & Device Management, select your
   developer account and trust it, then launch again. Follow any additional
   verification prompt on the phone. Allow location access for navigation.

A free Personal Team can sign development builds for the owner's devices;
provisioning profiles expire after seven days and must be renewed through Xcode. To check compilation
without signing, run `flutter build ios --no-codesign`. To build for a simulator,
run `flutter build ios --simulator`.

## Indoor AR

The Runner has the iOS counterpart of Android's `IndoorArChannel`: the same
`navipet/indoor_ar` channel and `launch` call, the same request JSON
(schemaVersion 1 or 2, optional `arToken`; schemaVersion 2 localization requests
use `mode: localize` and omit door pose fields) and the same result JSON
(`status`, `errorCode`). Host-built outcomes are `unavailable`, `BAD_REQUEST`,
`BUSY` (a launch is already in flight) and `UNITY_EXITED`. It hands the request to `IndoorArHost` inside
`UnityFramework` and returns the string Unity delivers.

It is off by default. To turn it on:

1. In NaviPetUnity (branch `fm/unity-ios-ar`, Unity **6000.3.26f1** with iOS
   Build Support) follow `docs/ios-export.md` to export the Xcode project and
   build `UnityFramework.framework` for a generic iOS device (arm64).
2. Copy the framework to `ios/unity-ar/UnityFramework.framework` and
   `ios/UnityAr.xcconfig.template` to `ios/unity-ar/UnityAr.xcconfig`. The
   directory is gitignored. The xcconfig defines `UNITY_AR_ENABLED`, links
   the framework and adds its search path; the Runner's "Embed Unity AR" build
   phase copies and signs it into the app when present.
3. Copy the export's `Data` folder (`Builds/IndoorArIos/Data`, from the same
   export the framework was built from) to
   `ios/unity-ar/UnityFramework.framework/Data`. The export keeps `Data` in
   its `Unity-iPhone` app target, so building the `UnityFramework` scheme
   leaves it out, while the Runner tells Unity to read its data from the
   framework. Without `Data/Managed/Metadata/global-metadata.dat` Unity exits
   the whole app on the first AR launch, so the "Embed Unity AR" phase fails
   the build when that file is missing.
4. Build and run as above. Camera access is requested through
   `NSCameraUsageDescription`. Delete `ios/unity-ar/UnityAr.xcconfig` to go
   back to AR unavailable.

The export may contain MultiSet credentials: share the framework privately and
never commit it.

This code path builds and signs against a real `UnityFramework`, but an AR
session has not been proven on a device. Re-entering AR after Unity unloads
(`runEmbedded` again) in particular needs checking on the phone.
