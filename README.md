# NaviPet Flutter

NaviPet is a campus companion for CSU Long Beach. The current functional slice
includes:

- Supabase email/password authentication, account creation, password reset,
  anonymous guest sessions, persisted sessions, and profile data.
- A native Mapbox map with live device location.
- Mapbox destination autocomplete and walking directions.
- A route line, destination marker, ETA/distance preview, maneuver guidance,
  spoken instructions, arrival detection, and basic off-route recalculation.
- Existing Pet, Checklist, Account, and prototype AR screens. The 3D/Multiset
  integration is intentionally deferred and is not exposed from the map.

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
BACKEND_BASE_URL=
```

Use only Supabase's publishable/anon client key. Never place a Supabase
`service_role` or secret key in the app.

`BACKEND_BASE_URL` points at the Fastify API in
[`Ben2104/NavipetBackend`](https://github.com/navipet-senior-project/NavipetBackend) 
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
5. Decide whether new users must confirm their email. NaviPet handles both
   configurations: with confirmation enabled it asks users to check their email;
   without it they enter the app immediately.
6. If email confirmation is enabled, open **Authentication > URL Configuration**
   and add `navipet://auth-callback` to **Redirect URLs**. The confirmation
   email links back to that scheme; without it registered on this list, tapping
   the link will not complete sign-in on the device (see
   [`register_screen.dart`](lib/screens/register_screen.dart)).
7. Copy the Project URL and publishable key from Supabase's **Connect** panel into
   `.env`.

Supabase Auth owns passwords and sessions. `profiles` stores app-facing account
data, `classes` stores each user's schedule and locations, and
`task_completions` stores daily progress. Owner-only policies protect each row.

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

To test the email-confirmation deep link on the emulator without an email
client configured on it, trigger the link directly:

```bash
adb shell am start -W -a android.intent.action.VIEW -d "navipet://auth-callback"
```

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
   - Choose your Apple development team.
   - If Xcode reports that the bundle identifier is unavailable, replace it with
     a unique value such as `com.yourname.navipet`.
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
flutter analyze
flutter test
flutter build apk --debug
```

The debug APK is written to:

```text
build\app\outputs\flutter-apk\app-debug.apk
```

## Troubleshooting

| Symptom | Fix |
|---|---|
| Supabase setup notice on sign-in | Add `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` to `.env`, then fully restart the app. |
| Guest sign-in fails | Enable anonymous sign-ins in Supabase Authentication settings. |
| New account cannot sign in immediately | Check the inbox and confirm the account, or disable Confirm email in Supabase for development. |
| "Backend not configured" error on sign-up | Add `BACKEND_BASE_URL` to `.env` and restart the app. |
| Confirmation email link does not open NaviPet | Add `navipet://auth-callback` to Supabase **Authentication > URL Configuration > Redirect URLs**. |
| Map is blank or destination search fails | Verify `MAPBOX_PUBLIC_TOKEN` is a valid `pk.*` token. |
| Android Mapbox dependency returns 401 | Verify the global `MAPBOX_DOWNLOADS_TOKEN` starts with `sk.` and has `DOWNLOADS:READ`. |
| Current location is unavailable | Enable precise location for NaviPet and turn on the phone's Location Services. |
| Route is not found | Walking directions require a Mapbox-routable origin and destination; try a nearby street entrance. |
| `cmdline-tools` is missing | Install Android SDK Command-line Tools in Android Studio, then run `flutter doctor --android-licenses`. |
| No Android emulators are listed | Open Android Studio's Device Manager, create a virtual device, start it, then run `flutter devices`. |
| No iPhones or simulators are listed | Open Xcode, install an iOS runtime in **Xcode > Settings > Platforms**, then run `open -a Simulator` and `flutter devices`. |
| Xcode reports a signing error | Select a development team under **Runner > Signing & Capabilities** and use a unique bundle identifier. |
| iOS reports resource-fork/Finder metadata errors | Move the repository out of an iCloud-synced Desktop or Documents folder, then run `flutter clean` and try again. |

The Kotlin Gradle Plugin warning currently emitted by Mapbox/Flutter TTS is a
forward-compatibility warning from those plugins; the Android build succeeds on
the pinned Flutter/Mapbox versions in this repository.

## Collaborators
- [@thejomar](https://github.com/thejomar)
- [@Ben2104](https://github.com/Ben2104)
