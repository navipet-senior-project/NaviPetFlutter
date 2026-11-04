# iPhone testing

Indoor AR is unavailable on iOS in this build. The iOS `navipet/indoor_ar`
channel returns `unavailable`, even if a Unity export is present. The rest of
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

## Unity export status

The separate NaviPetUnity project currently targets Unity **6000.3.26f1** and
has Android-only request/result transport and an ARCore loader. It needs an
iOS request/result bridge and ARKit package and loader before an iOS export
can provide indoor AR. Simply adding a `UnityFramework` to this Flutter project
will not enable it. No framework is linked or embedded by the current iOS
build.

Once that Unity work is available, install the matching Unity Editor and its
iOS Build Support module through Unity Hub, open the Unity project, switch the
active build platform to iOS under File > Build Profiles, select the indoor AR
scene and build to a separate output directory. The export contains an Xcode
project and `UnityFramework` target. Integration and verification of that
framework depend on the Unity-side iOS bridge and are not implemented here.
