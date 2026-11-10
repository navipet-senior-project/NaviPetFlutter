# NaviPet Flutter

NaviPet is a campus companion for CSU Long Beach. The current functional slice
includes:

- Supabase email/password authentication, six-digit email verification,
  account creation, password reset, anonymous guest sessions, persisted
  sessions, and profile data.
- A native Mapbox map with live device location.
- Mapbox destination autocomplete and walking directions.
- A route line, destination marker, ETA/distance preview, maneuver guidance,
  spoken instructions, arrival detection, and basic off-route recalculation.
- Existing Pet, Checklist, and Account screens. On Android (and on iOS when a
  prebuilt UnityFramework is present, see `docs/ios-testing.md`), the Scan AR
  button appears during navigation to a place with indoor AR once a fresh
  location fix is at or within 2 m of the building footprint, regardless of GPS
  accuracy. It hides when the fix goes stale (10 s) or is clearly outside. It
  loads the selected place and sends its backend door pose, plus a
  short-lived MultiSet token fetched from the backend (`POST /indoor/ar-token`),
  to Unity. Without a saved door pose, it starts a localization scan without
  inventing a destination. Indoor AR points toward a room; it does not provide
  turn-by-turn indoor routing. The MultiSet secret never ships in the app.
  Unity AR still requires verification on a physical phone.
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
2. Copy it to `ios/unity-ar/UnityFramework.framework`.
3. Copy `ios/UnityAr.xcconfig.template` to
   `ios/unity-ar/UnityAr.xcconfig`. That file is what turns the iOS Unity
   bridge on. Deleting `ios/unity-ar/UnityAr.xcconfig` turns it back off.
4. Git ignores `/ios/unity-ar/`. Confirm with
   `git check-ignore -v ios/unity-ar/UnityFramework.framework` before you
   commit anything else. Do not commit the framework.
5. Sign and run with [Physical iPhone](#physical-iphone). Use your free
   Personal Team. Do not commit a team id or a bundle-identifier change.

That iOS bridge is not yet proven against a real `UnityFramework` on a phone.

## Navigation behavior

The app stays on Mapbox for this phase. It uses the native Maps Flutter SDK for
rendering and location, the Search Box API for destinations, and the Directions
API's walking profile for route geometry and maneuver instructions.

This is a functional foreground walking-navigation experience. Before treating
it as safety-critical or shipping it broadly, add integration/device tests for
GPS loss, background execution, route deviations, network loss, accessibility,
and battery use. Do not rely on it for emergency navigation.

The three most recent selected destinations are kept only on the phone and can
be cleared from Search. They are not uploaded to Supabase. Class locations are
stored in Supabase so Search can adapt to a user's schedule across devices.

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
