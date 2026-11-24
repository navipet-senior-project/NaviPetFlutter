# NaviPet Flutter

NaviPet is a campus companion for CSU Long Beach. The current functional slice
includes:

- Supabase email/password authentication, six-digit email verification,
  account creation, password reset, anonymous guest sessions, persisted
  sessions, and profile data.
- A native Mapbox map with live device location.
- Mapbox destination autocomplete and walking directions.
- A 2D Pet section with Elbee Home, Pack, Shop, and Quests. Home shows the
  signed-in user's saved classes and verified point balance (shown as gems);
  Quests uses the existing server-verified claim flow, Shop uses the existing
  purchase RPC, and Pack only equips owned outfits. Pet level and message are
  derived locally; classes, inventory, and rewards are not mocked. A campus
  check-in is not proof of class attendance.
- A route line, destination marker, ETA/distance preview, maneuver guidance,
  spoken instructions, arrival detection, and basic off-route recalculation.
- During an active outdoor walk, builds with outdoor AR enabled hand the
  destination and selected walking route to an ARCore Geospatial session.
  Without the opt-in, the control explains that outdoor AR is unavailable and
  leaves the route active on the map. Unity's shared HUD integration is
  coordinated separately; end-to-end behavior is unverified. See
  [docs/outdoor-ar-geospatial.md](docs/outdoor-ar-geospatial.md).
- Calendar, Pet Shop and Pack, and Account screens.
- Indoor AR for VEC rooms: see [Indoor navigation architecture](#indoor-navigation-architecture).
  It is a separate subsystem from the outdoor Mapbox navigation above.
- Ask Elbee about CSULB buildings and rooms from the map. Elbee returns
  verified places that open existing navigation; schedule access requires
  consent for each request. It can also explain official parking rules. Elbee
  is NaviPet's campus pet, separate from the university parking chatbot.

## Project structure

Detailed file ownership and collaboration guidance is available in
[docs/PROJECT_MAP.md](docs/PROJECT_MAP.md).

```text
FRONTEND
lib/screens/                       Complete Flutter screens
lib/widgets/                       Reusable UI components
lib/theme/                         Visual design tokens
lib/router/                        App navigation and redirects
assets/                            Images and fonts

CLIENT SERVICES + SHARED MODELS
lib/
  main.dart                         App initialization
  data/
    app_config.dart                 Safe runtime configuration checks
    app_state.dart                  Supabase auth, classes, and task state
    course_class.dart               Class schedule and generated-task models
    search_history_store.dart       On-device recent destination history
    user_account.dart               Authenticated profile model
    mapbox_config.dart              Mapbox token and campus defaults
    mapbox_navigation_service.dart  Search Box + Directions API client
    navigation_models.dart          Destination, route, and maneuver models

EXTERNAL BACKEND
Ben2104/NavipetBackend              Fastify API and Supabase schema
Supabase Auth                       Accounts, sessions, and password recovery

PLATFORM + BUILD
android/                            Android native and Gradle configuration
ios/                                iOS native and Xcode configuration
pubspec.yaml                        Dependencies, assets, and app version
test/                               Automated tests
```

## Indoor navigation architecture

Indoor navigation is separate from the Mapbox outdoor walking navigation and
the application overview above. It currently covers the Vivian Engineering
Center (VEC) only. Nothing in this section has been verified on a physical
phone unless a note says so.

### Who owns what

| Layer | Owns | Does not own |
| --- | --- | --- |
| Flutter (`lib/`) | Entry points, the floor question, camera permission, requesting a token, building the request, decoding the result, user-facing messages | Localization, camera pose, indoor routing |
| Native hosts (`android/`, `ios/`) | The `navipet/indoor_ar` method channel, starting Unity, returning its result, the device boot clock | Request contents (passed through as one string) |
| [NaviPetUnity](https://github.com/navipet-senior-project/NaviPetUnity) | AR session, MultiSet localization, sign (OCR) recognition, hallway routing and HUD, [floor veto](#sensor-evidence), and height hints in exports that include [Unity PR 39](https://github.com/navipet-senior-project/NaviPetUnity/pull/39) | Place lookup, tokens |
| [NavipetBackend](https://github.com/navipet-senior-project/NavipetBackend) | Place records with the saved door pose, token minting through `POST /indoor/ar-token`, the MultiSet credentials | Anything on the phone |

### Launching indoor AR

1. **Entry.** These controls pass a place ID through `/ar?destination=<place id>`.
   The launch screen reports indoor AR unavailable if the ID is missing.
   - During active navigation and on **Confirm your location**, **Scan AR**
     requires a covered indoor destination with a place ID, a nonblank
     `indoorDestinationId`, and a footprint, plus a usable, non-approximate fix
     at most 10 s old within 2 m of that footprint.
   - After outdoor arrival, **Scan AR** on the handoff sheet and the **AR**
     map shortcut are shown based on floor coverage regardless of fix age.
   - **Verify location** on the VEC building map opens AR after resolving the
     selected room and floor to exactly one backend place ID through search.
     In this flow, the bundled scan asset (`assets/indoor/vec_floors1and2.json`)
     draws the map. The AR door pose comes from the backend place record.
2. **Place and door pose.** `IndoorArLaunchScreen` loads the place from the
   backend. A valid `indoor` door pose (map code, `multiset-mapset` frame, door
   key, floor, position, heading) becomes a destination request. A missing or
   invalid pose becomes a `mode: localize` request with no door fields, so AR
   scans to find the phone without inventing a destination. Only VEC floors 1 to
   3 (`indoor_floor_coverage.dart`) launch.
3. **Floor question** (optional). See [sensor evidence](#sensor-evidence).
4. **Camera permission.** Flutter checks permission before requesting a token.
   Denying the prompt exits the launch screen. Permanent denial offers Settings.
5. **Token.** Flutter calls `POST /indoor/ar-token` with the user's session
   bearer token. The backend exchanges its own MultiSet credentials and
   returns a short-lived `{token, expiresOn}`. The endpoint is authenticated
   and limited to 5 requests per minute per user. Flutter receives only the
   short-lived token and its expiry. It keeps the token in memory and rejects
   it if one minute or less remains. Never log the token. Private Unity exports
   may contain MultiSet credentials. See
   [Unity AR without installing Unity](#unity-ar-without-installing-unity).
6. **Bridge.** Flutter sends one JSON string over the `navipet/indoor_ar`
   channel. Android starts `UnityHostActivity` (a separate `:unity` process)
   with `startActivityForResult`; iOS hands it to `IndoorArHost` in the embedded
   `UnityFramework`. Android needs the private AAR. iOS needs both the prebuilt
   `UnityFramework` and `ios/unity-ar/UnityAr.xcconfig` to set
   `UNITY_AR_ENABLED`. A build without Unity support returns `unavailable`.
   See [Unity AR without installing Unity](#unity-ar-without-installing-unity).
7. **Result.** Unity returns JSON with a `status` of `arrived`, `cancelled`,
   `localizationFailed`, `unavailable`, or `error`. Every status requires
   nonnegative integers for `localizationQueries` and `durationMs`. An
   `error` also requires a nonempty string `errorCode`. If Unity closes without
   a result, either native host returns `error` / `UNITY_EXITED`. Dart decodes
   malformed results as `error` / `BAD_RESULT`. For a destination result
   marked `arrived`, Flutter confirms arrival when the room sign matches or
   reports the distance if provided. A result with neither is invalid.
   Cancellation exits silently. A localization failure after sending floor
   evidence stays on the launch screen for retry. Other results show a message
   and return to the previous screen, or to the map if there is no prior screen.

### Bridge contract (v2)

Flutter defines the contract in `lib/data/indoor_ar_contract.dart`. Unity
parses it in `IndoorArContract`. Poses pass through in the MultiSet MapSet
frame (metres, +Y up). Both modes send `schemaVersion: 2` and accept optional
floor evidence. A destination request carries `room`, `doorKey`, `floor`,
`position`, `headingDeg`, `mapCode`, `frame`,
`capabilities: ["signArrival"]`, and `arToken`. A localization request carries
`mode: localize`, `mapCode`, `frame`, `arToken`, and optional `room` and
`floor`. Never log a request.

### Sensor evidence

Unity builds with the floor policy can use this optional evidence to reject
wrong-floor matches. Older exports ignore it. An export that includes
[Unity PR 39](https://github.com/navipet-senior-project/NaviPetUnity/pull/39)
can send a height hint on the first MultiSet request when host evidence meets
the Unity contract.

- **Floor confirmation.** Flutter asks which floor the user is standing on
  before collecting barometer readings. Select **Skip** to proceed without
  collecting readings. After confirming the floor, hold the phone still for
  about 20 s or select **Continue without waiting** to proceed without
  evidence. Phones without a usable barometer can proceed without evidence.
- **What is sent.** Eligible evidence includes `floorEvidenceVersion`,
  `startFloor`, `startFloorAgeS`, and `pressureSinceStart` (`settled`,
  `moved`, `sampleAgeS`). Flutter adds signed `pressureSinceStart.deltaHpa`
  and `requestSentAtBootS` together when `moved` is true, the absolute delta is
  0.30–3 hPa inclusive, and a usable boot-clock stamp is available. If the
  stamp is missing, Flutter still sends the remaining eligible evidence.
  The evidence contains no raw pressure, wall-clock time, or location.
- **Failure handling.** After a localization failure with floor evidence,
  choose **Try again** to confirm the current floor again or **Back to map**
  to exit.
- See the [Flutter floor-evidence guide](docs/indoor-ar-floor-evidence.md)
  for thresholds and clock handling and the
  [Unity floor-evidence contract](https://github.com/navipet-senior-project/NaviPetUnity/blob/0203e2206ba8a39e67e5db8eab3854c50351d2d3/docs/floor-evidence-contract.md)
  for Unity's validation and hint rules.

The debug-only recorder and VEC Wi-Fi survey below are experiments. They do not
feed the AR request.

### Routing

Flutter does no indoor routing: `IndoorArRequest` carries a destination door
pose, not a path. Unity runs A* over a walk grid built from the building scan
and shows a floor ribbon or arrow; if no clear route exists it shows **Route
unavailable**. Current Unity exports can guide users through hallways on VEC
floors 1–3. For floor changes, Unity points to a stair or elevator marker.
Device validation remains open. See
[Unity floor-3 routing](https://github.com/navipet-senior-project/NaviPetUnity/pull/27).

### Not yet verified

- Dart tests cover the bridge contract and launch behavior, including retry
  and exit. Android Kotlin tests cover native result forwarding and fallback
  results. The iOS Runner test target contains a placeholder. AR sessions,
  MultiSet localization, and barometer behavior still need phone testing.
- Android release camera access and the iOS re-entry after Unity unloads need
  device checks (see [docs/indoor-ar-release-camera.md](docs/indoor-ar-release-camera.md)
  and [docs/ios-testing.md](docs/ios-testing.md#indoor-ar)).
- Floor-evidence thresholds come from one iPhone in one building. Android is
  unverified. Whether the height hint helps localization is unknown.
- VEC floors 4 and 5 are outside indoor AR coverage. Step-free routing is
  not supported.
- Flutter has no version handshake with Unity, so it cannot tell which Unity
  build is paired.

## Fastify backend

The Fastify API and Supabase schema live in the public
[`Ben2104/NavipetBackend`](https://github.com/Ben2104/NavipetBackend)
repository. Its README documents server setup, environment boundaries,
authentication, health endpoints, OpenAPI, and verification.

## Prerequisites

- Flutter 3.44 or later
- Android Studio and Android SDK 36 for Android development
- Xcode and an iOS runtime for iOS development
- A Mapbox account
- A Supabase project

Run `flutter doctor` and resolve its required items before continuing.

## Environment configuration

Copy `.env.example` to `.env`. The `.env` file is git-ignored.

```properties
MAPBOX_PUBLIC_TOKEN=pk.your_public_token
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_PUBLISHABLE_KEY=sb_publishable_your_key
BACKEND_BASE_URL=https://navipetbackend.onrender.com
```

Use only Supabase's publishable/anon client key. Never place a Supabase
`service_role` or secret key in the app.

`BACKEND_BASE_URL` points at the hosted Fastify API used for registration,
login, OTP verification, and password recovery. Its interactive API reference
is available at <https://navipetbackend.onrender.com/docs>. The server source is
[`navipet-senior-project/NavipetBackend`](https://github.com/navipet-senior-project/NavipetBackend).

### Mapbox Android download token

Android builds also require a secret Mapbox token with `DOWNLOADS:READ`. Put it
in your user-level Gradle file, not in this repository:

```text
C:\Users\YOUR_NAME\.gradle\gradle.properties
```

```properties
MAPBOX_DOWNLOADS_TOKEN=sk.your_download_token
```

## Supabase setup

1. Create a Supabase project.
2. Open **SQL Editor**, paste
   [`supabase/schema.sql`](https://github.com/Ben2104/NavipetBackend/blob/main/supabase/schema.sql),
   and run it once. This creates the profile, class, and completion tables, the
   new-user trigger, and Row Level Security policies. If you ran an older copy,
   run the entire file again; it is safe to re-run and adds the new tables.
3. In **Authentication > Providers**, keep Email enabled.
4. Enable anonymous sign-ins if **Continue as Guest** should work.
5. Keep email confirmation enabled. After registration, NaviPet prompts for the
   six-digit code sent by Supabase and verifies it through the Fastify API.
6. In the Supabase email template for **Confirm signup**, include the token with
   `{{ .Token }}` so the email contains the six-digit code expected by the app.
7. Copy the Project URL and publishable key from Supabase's **Connect** panel into
   `.env`.

Supabase Auth owns passwords and sessions. `profiles` stores app-facing account
data, `classes` stores each user's schedule and locations, and
`task_completions` stores daily progress. Owner-only policies protect each row.

The points feature also requires [`docs/points_schema.sql`](docs/points_schema.sql)
to be applied to the same Supabase project before this Flutter release. It adds
wallets, a transaction ledger, owned outfits, and atomic RPCs for claims and
purchases. In-person tasks award 10 points once per class per day when the
device is within 150 meters of the saved class location during its scheduled
time (with a 15-minute margin). Online attendance and preparation award 5
points. The app checks nearby classes every 30 seconds while in the foreground;
location permission must already be granted for automatic check-ins. The pet
store prices are defined in the SQL migration so the client cannot set them.

## Authentication flow

NaviPet uses the Fastify authentication endpoints and then hands successful
access/refresh token pairs to Supabase's persisted mobile session manager.

```text
Sign in:        Sign In → Home
Sign up:        Sign Up → OTP Verification → Home
Forgot password: Sign In → Forgot Password → Email Sent
                 → OTP Verification → Reset Password → Home
```

The OTP screen requires all six digits before enabling verification. Incorrect
or expired codes remain on that screen and expose **Resend Code**. A recovery
OTP creates only a pending recovery session; it cannot open Home until
`POST /auth/reset-password` succeeds. Successful password reset adopts that
session automatically, so the user arrives at Home without signing in again.

Direct backend calls used by this flow are `POST /auth/login`,
`POST /auth/register`, `POST /auth/forgot-password`,
`POST /auth/verify-otp`, and `POST /auth/reset-password`. Signup-code resend
uses Supabase's publishable client because the current Fastify API does not
publish a signup-resend endpoint; password-recovery resend repeats
`POST /auth/forgot-password`.

## Run on Android

Make sure `.env` contains the Mapbox and Supabase values described above, and
that the user-level `MAPBOX_DOWNLOADS_TOKEN` from
[Mapbox Android download token](#mapbox-android-download-token) is set — the
Android build fails without it.

### Android Emulator

1. In Android Studio, open **Tools > Device Manager** and create a virtual
   device (a Pixel profile with a recent API level works well) if none exists.
2. Start the emulator, then run from the project root:

   ```bash
   flutter pub get
   flutter devices
   flutter run
   ```

3. If Flutter lists multiple targets, select the emulator explicitly:

   ```bash
   flutter run -d emulator-5554
   ```

The first build can take several minutes while Gradle resolves the native
Mapbox packages. GPS on an emulator is a fixed or manually-set mock location
(**Extended controls > Location**), not live movement — an emulator can test
UI, authentication, search, and a static route preview, but a physical phone
is needed for real turn-by-turn navigation.

To test signup, use an inbox you can access, then enter the six-digit code from
the confirmation email on the app's **Verify your email** screen.

### Physical Android phone

1. Enable Developer options and USB debugging on the phone.
2. Connect it with a data-capable USB cable and approve the debugging prompt.
3. From the project root, run:

```powershell
flutter pub get
flutter devices
flutter run
```

The first build can take several minutes. The app will request location access
when the map opens; precise location is needed for route guidance and rerouting.

### Android terminal commands

With an emulator running or a phone connected, list targets and select the ID
shown by Flutter. `adb devices` shows Android device serials.

```bash
flutter devices
adb devices
flutter run -d <flutter-device-id>
```

Alternatively, build and install the debug APK. Use the serial from `adb devices`
when more than one Android target is connected:

```bash
flutter build apk --debug
adb -s <android-serial> install -r build/app/outputs/flutter-apk/app-debug.apk
adb -s <android-serial> shell am start -n com.navipet.navipet/.MainActivity
adb -s <android-serial> logcat
```

## Run on an iPhone

iPhone builds require **macOS and Xcode**. They cannot be compiled or installed
from Windows. Make sure `.env` contains the Mapbox and Supabase values described
above. The secret `MAPBOX_DOWNLOADS_TOKEN` is only needed for Android; iOS uses
the public Mapbox token from `.env`.

Avoid building the project from an iCloud-synced Desktop or Documents folder.
iCloud metadata can cause iOS code signing to fail. A path such as
`~/Development/NaviPetFlutter` is safer.

### iOS Simulator

1. Install Xcode from the Mac App Store and finish its first-run setup:

   ```bash
   sudo xcodebuild -runFirstLaunch
   ```

2. Open a simulator and run the app from the project root:

   ```bash
   open -a Simulator
   flutter pub get
   flutter devices
   flutter run
   ```

3. If Flutter lists multiple targets, select the simulator explicitly:

   ```bash
   flutter run -d "iPhone 16 Pro"
   ```

The first iOS build can take several minutes while Xcode resolves the native
Mapbox packages. A simulator can test the UI, authentication, search, and route
preview, but a physical iPhone is better for testing live GPS navigation.

### Physical iPhone

1. Connect the unlocked iPhone to the Mac with a data-capable cable.
2. Tap **Trust** if the iPhone asks whether to trust the computer.
3. On iOS 16 or later, enable **Settings > Privacy & Security > Developer Mode**
   if prompted, then restart the iPhone.
4. Open the iOS workspace:

   ```bash
   open ios/Runner.xcworkspace
   ```

5. In Xcode, select **Runner > Signing & Capabilities**:
   - Choose your Apple development team. A free Apple ID (Personal Team) is
     enough for development testing. The committed project uses automatic
     signing and contains no team id. Do not commit a team id.
   - If Xcode reports that the bundle identifier is unavailable, replace it with
     a unique value such as `com.yourname.navipet`. That edit is local: discard
     it before committing.
   - Let Xcode create or update the development signing certificate.
6. Select the connected iPhone once in Xcode and allow any requested device
   preparation to finish.
7. Return to the terminal and run:

   ```bash
   flutter devices
   flutter run -d <iphone-device-id>
   ```

8. Approve the location request when NaviPet opens. Select precise location so
   route guidance and rerouting can use an accurate GPS position.

A free Apple ID can be used for development testing, although its signing has
more restrictions. App Store or TestFlight distribution requires membership in
the Apple Developer Program.

### iOS terminal commands

After completing the signing and device preparation above, list the phone with
Flutter and CoreDevice. Their identifiers can differ.

```bash
flutter devices
xcrun devicectl list devices
flutter run -d <flutter-device-id>
```

To build and install separately, use the CoreDevice identifier and the bundle
identifier configured in Xcode:

```bash
flutter build ios --debug
xcrun devicectl device install app --device <coredevice-id> build/ios/iphoneos/Runner.app
xcrun devicectl device process launch --device <coredevice-id> <bundle-id>
```

For a simulator, choose an available device ID and build its separate app bundle:

```bash
xcrun simctl list devices available
xcrun simctl boot <simulator-id>
flutter build ios --debug --simulator
xcrun simctl install <simulator-id> build/ios/iphonesimulator/Runner.app
xcrun simctl launch <simulator-id> <bundle-id>
```

Skip the boot command if the simulator is already running. The default bundle ID
is `com.navipet.navipet`; use your locally configured ID if you changed it.

## Unity AR without installing Unity

You do not need Unity installed to build or run NaviPet. No prebuilt Unity
library is in this repository, and neither
[NaviPetFlutter](https://github.com/navipet-senior-project/NaviPetFlutter) nor
[NaviPetUnity](https://github.com/navipet-senior-project/NaviPetUnity) publishes
one as a GitHub release. The Android AAR and the iOS `UnityFramework` can hold
MultiSet credentials, so they stay out of git. Ask the project maintainer who gave you
access to this repository (see [Collaborators](#collaborators)) for a private
copy. Do not commit that copy, and do not post it anywhere public.

Without that private copy, follow [Run on Android](#run-on-android) or
[Run on an iPhone](#run-on-an-iphone). Leave `android/unity-ar/` absent. The
rest of the app still builds. Without the library, Scan AR reports that AR is
unavailable on the device.

### Android

Gradle in
`android/app/build.gradle.kts` turns Unity on only when
`android/unity-ar/unityLibrary-release.aar` is a file. `android/.gitignore`
ignores the whole `android/unity-ar/` directory.

1. Get the `android/unity-ar/` directory from the project maintainer who gave you access to this repository, in private. Keep
   every file in it, including `unityLibrary-release.aar`, any other `.aar`
   files, and `maven-deps.txt` when that file is present.
2. Place that directory at `android/unity-ar/` in your checkout. Confirm git
   does not see it (`git check-ignore -v android/unity-ar/unityLibrary-release.aar`
   should name `android/.gitignore`).
3. Use a physical arm64 Android phone running API 26 or newer. With the AAR
   present, the build raises `minSdk` to at least 26 and ships only
   `arm64-v8a`.
4. Build and install with the steps in [Physical Android phone](#physical-android-phone).

### iPhone

1. Get `UnityFramework.framework` from the project maintainer who gave you access to this repository, in private.
2. Copy it to `ios/unity-ar/UnityFramework.framework`. It must contain the
   Unity export's `Data` folder (see `docs/ios-testing.md`); the build fails
   without it.
3. Copy `ios/UnityAr.xcconfig.template` to
   `ios/unity-ar/UnityAr.xcconfig`. That file is what turns the iOS Unity
   bridge on. Deleting `ios/unity-ar/UnityAr.xcconfig` turns it back off.
4. Git ignores `/ios/unity-ar/`. Confirm with
   `git check-ignore -v ios/unity-ar/UnityFramework.framework` before you
   commit anything else. Do not commit the framework.
5. Sign and run with [Physical iPhone](#physical-iphone). Use your free
   Personal Team. Do not commit a team id or a bundle-identifier change.

See [iPhone testing](docs/ios-testing.md#indoor-ar) for setup and validation
status.

## Navigation behavior

Outdoor walking navigation uses Mapbox. The native Maps Flutter SDK handles
rendering and location, the Search Box API finds destinations, and the Directions
API's walking profile supplies route geometry and maneuver instructions.

This is a functional foreground walking-navigation experience. Before treating
it as safety-critical or shipping it broadly, add integration/device tests for
GPS loss, background execution, route deviations, network loss, accessibility,
and battery use. Do not rely on it for emergency navigation.

The three most recent selected destinations are kept only on the phone and can
be cleared from Search. They are not uploaded to Supabase. Class locations are
stored in Supabase so Search can adapt to a user's schedule across devices.

## Wave D floor-pressure measurements

On a barometer-equipped phone, launch a debug build with
`flutter run --dart-define=NAVIPET_DEV_ROUTE=/dev/floor-pressure`. The recorder
is available while signed out and has no production entry. Device behavior has
not yet been verified on campus.

Start recording, enter the floor you are standing on, and select **Confirm
floor**. Select **Start moving between floors** before leaving a floor, then
confirm the new floor after arriving. Each new run also requires a floor
confirmation. Readings without a confirmed floor are omitted. Stop to save a
run, then use **Copy JSON** to export saved runs or **Clear runs** to remove
them. If saving fails, use **Retry save**.

Runs are stored on the device and contain the platform and per-sample floor,
elapsed time, and pressure change in hPa relative to the first reading in that
run. They do not contain absolute pressure, wall-clock time, location, or an
identifier. Compare changes only within a run: handling, HVAC, and weather can
affect pressure. iOS may require Motion & Fitness access; devices without a
barometer cannot record.

## VEC Wi-Fi survey and floor belief

In a debug build, open the VEC indoor map and tap the Wi-Fi icon in the app bar
to open the positioning screen. On Android, survey at each available Unity
landpoint while standing still; repeat captures at each point. Nearby scan
results require Wi-Fi, location permission, and Android Location services.
Scans and the particle filter's last belief stay in local app storage. Android
limits scan frequency, so a scan may need to be retried. iOS does not provide
nearby access-point scans to this app. Its barometer readings are supported;
the existing AR confirmation remains a separate step.

For barometer floor references, start a recording on floor 1, enter floor
numbers consistently, and confirm each floor as you arrive. In the positioning
screen confirm the current starting floor to anchor
relative pressure for that outing. The floor belief can persist without Wi-Fi;
Wi-Fi scans refresh the likely landmark when available. The current bundled
Unity scan provides landmark coordinates for floors 1 and 2 only. Floors 3–5
can have a floor belief from pressure calibration, but do not yet have surveyed
Wi-Fi landpoints or coordinates in this build. These estimates are a prototype
and need on-device VEC survey/validation before being used as navigation truth.

## Verification

```powershell
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
flutter build apk --debug
```

The debug APK is written to:

```text
build\app\outputs\flutter-apk\app-debug.apk
```

### Continuous integration

Pull requests to `main` run two GitHub Actions workflows on Flutter 3.47.0:

- **Pull request / analyze-and-test** runs the format check, `flutter analyze`
  and `flutter test`. If formatting fails, run `dart format .` and commit.
- **Android smoke build / android-debug-build** runs
  `flutter build apk --debug`, but only when a
  pull request changes `android/`, `pubspec.yaml`, `pubspec.lock` or the
  workflow itself; otherwise it passes without building. It needs the
  repository Actions secret `MAPBOX_DOWNLOADS_TOKEN` (the same `sk.*` token
  with `DOWNLOADS:READ` used locally). Pull requests from forks cannot read
  secrets, so this job skips with a warning for them.

CI copies `.env.example` to `.env` because `pubspec.yaml` bundles `.env` as an
asset. No real keys are used in CI.

## Troubleshooting

| Symptom | Fix |
|---|---|
| Supabase setup notice on sign-in | Add `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` to `.env`, then fully restart the app. |
| Guest sign-in fails | Enable anonymous sign-ins in Supabase Authentication settings. |
| New account cannot sign in immediately | Check the inbox and confirm the account, or disable Confirm email in Supabase for development. |
| Verification code is invalid or expired | Tap **Resend Code** on the OTP screen and enter the newest code. |
| Password reset returns to OTP | The recovery token expired; request a new reset code and repeat the recovery flow. |
| "Backend not configured" error on sign-up | Add `BACKEND_BASE_URL` to `.env` and restart the app. |
| Confirmation email has a link but no six-digit code | Update the Supabase **Confirm signup** email template to include `{{ .Token }}`. |
| Map is blank or destination search fails | Verify `MAPBOX_PUBLIC_TOKEN` is a valid `pk.*` token. |
| Android Mapbox dependency returns 401 | Verify the global `MAPBOX_DOWNLOADS_TOKEN` starts with `sk.` and has `DOWNLOADS:READ`. |
| Current location is unavailable | Enable precise location for NaviPet and turn on the phone's Location Services. |
| Route is not found | Walking directions require a Mapbox-routable origin and destination; try a nearby street entrance. |
| `cmdline-tools` is missing | Install Android SDK Command-line Tools in Android Studio, then run `flutter doctor --android-licenses`. |
| No Android emulators are listed | Open Android Studio's Device Manager, create a virtual device, start it, then run `flutter devices`. |
| No iPhones or simulators are listed | Open Xcode, install an iOS runtime in **Xcode > Settings > Platforms**, then run `open -a Simulator` and `flutter devices`. |
| Xcode reports a signing error | Select a development team under **Runner > Signing & Capabilities** and use a unique bundle identifier. Do not commit the team id or that bundle-identifier edit. |
| Android says "AR is not included in this build." | No private `android/unity-ar/unityLibrary-release.aar` is present. The rest of the app still runs. See [Unity AR without installing Unity](#unity-ar-without-installing-unity). |
| iPhone says "AR mode isn't available on this device." | The private framework or its configuration is missing. See [Unity AR without installing Unity](#unity-ar-without-installing-unity). |
| iOS reports resource-fork/Finder metadata errors | Move the repository out of an iCloud-synced Desktop or Documents folder, then run `flutter clean` and try again. |

The Kotlin Gradle Plugin warning currently emitted by Mapbox/Flutter TTS is a
forward-compatibility warning from those plugins; the Android build succeeds on
the pinned Flutter/Mapbox versions in this repository.

## Collaborators

- [@will-chhuor](https://github.com/will-chhuor)
- [@thejomar](https://github.com/thejomar)
- Khoi Do ([@Ben2104](https://github.com/Ben2104))
- Jan Kirvey Montemayor ([@Kura-Yami](https://github.com/Kura-Yami))
- Jake Namoto ([@GlazedKrispy])

## Backend API client

- The Dart client lives in `packages/navipet_api` and is generated from `openapi/navipet-api.json` (the backend's OpenAPI spec).
- Regenerate with `tool/generate_api_client.sh --fetch` to re-download the spec and regenerate. Requires Java and Node.js (`npx`).
- Before generating, `tool/normalize_openapi.jq` collapses TypeBox literal unions (`anyOf` of single-value enums, `anyOf` with `null`) into plain enums and `nullable` fields. It also converts homogeneous coordinate tuples into fixed-length arrays supported by the `dart` generator. The committed spec stays unmodified.
- Never hand-edit generated files. Change the spec or the script instead, then regenerate.
