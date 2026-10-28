# Indoor AR Door Verifier (VEC floors 1–2, Android) — Design

**Date:** 2026-10-28
**Status:** Approved in brainstorming, pending written-spec review
**Repos:** NaviPetUnity (AR runtime), NaviPetFlutter (launch screen + Android host), NavipetBackend (no change)
**Issues:** .github#42 (MultiSet feasibility), #46 (launch and return), #47 (localize and guide), #49 (end-to-end walkthrough)
**Builds on:** the indoor AR flow design (`docs/superpowers/specs/2026-10-19-indoor-ar-flow-design.md` on branch `docs/indoor-ar-flow-spec`) and the transport spike (PR #43, merged)

## Goal

Prove that MultiSet localization and the 17 VEC door poses stored in Supabase agree on a real phone in the real building, before any NavMesh routing is built.

A student picks a VEC floor 1–2 room, opens fullscreen AR, is localized in MultiSet MapSet `MSET_XTBY7AM7ZK77`, and sees one pin at that room's stored door pose. At the door they tap "I'm here". The app records the horizontal distance between the phone and the pin and returns to Flutter with the result.

This is the indoor AR flow design's v1 without the NavMesh path.

## Scope

In scope:
- VEC floors 1 and 2, one door per launch.
- Android only, ARCore devices.
- MultiSet SDK installed fresh in NaviPetUnity, cloud localization against the MapSet.
- Door pin, horizontal distance, "I'm here" measurement, result back to Flutter.
- Flutter `IndoorArLaunchScreen` behind the `/ar` route, replacing the static mockup.
- Fix for the PR #43 gap: a result lost when `MainActivity` is recreated while Unity runs.

Out of scope:
- NavMesh bake and path line (#16, and the routing part of #47).
- Crossing floors (#48). A wrong-floor banner is in scope; routing is not.
- Backend-minted MultiSet tokens.
- iOS, floors 3–5.
- The "Continue Indoors (AR)" entry button itself: PR #44 (Kura-Yami) adds it.

## Facts that shaped the design

- Supabase `vec_destination_points` holds 17 active doors, all `map_code = MSET_XTBY7AM7ZK77`, `frame = multiset-mapset`, `map_version = 1`, each linked to a `campus_destinations` row:
  - Floor 1 (y ≈ −1.8 m): VEC119, 120, 121, 124, 127, 128, 132, 134, 136.
  - Floor 2 (y = 2.33 m): VEC201, 202, 215, 217, 218, 220, 224, 227.
- These are Jomar's v2 export: positions relative to the `Floor 1 2` map root (`MAP_YXEW0CKO9CX8`), which is the MapSet's locked origin. Jomar's merge of the other maps moved only `3 4` and `Floor 5`, so it does not affect floors 1–2.
- `NaviPetUnity/Assets/IndoorNavigation/Data/vec_floors1and2.json` is the v1 export, relative to `IndoorMapOrigin`. It is never used at runtime.
- NavipetBackend already returns the door pose on `/places/:placeId` (`findIndoorDoorPoint`, `src/plugins/supabase.ts`).
- NaviPetUnity has no MultiSet SDK, config or scene in any commit. The SDK installs from `https://github.com/MultiSet-AI/multiset-unity-sdk.git`; credentials live in `Assets/Samples/MultiSet-SDK/<version>/Sample Scenes/Resources/MultiSetConfig.asset`; `MapLocalizationManager` supports a MapSet mode and a runtime map code.
- Unity editor `6000.3.26f1` with Android build support is installed; the Unity CLI is at `~/.unity/bin/unity`.
- PR #44 pushes `/ar` with no destination id.

## Decisions

| Topic | Decision | Main reason |
|---|---|---|
| Verification before routing | Door pins first, NavMesh later | A frame error found now costs one pin; found later it hides inside path bugs |
| Door data source | Backend `/places/:placeId` pose, passed through bridge contract v1 | Tests the data path that ships; no contract change |
| Doors per launch | One | Contract v1 unchanged; this is the real #46 flow |
| Unity setup | Fresh MultiSet SDK install, not Jomar's local scene | The Supabase poses are already in the MapSet frame |
| "I'm here" | Always enabled | A verifier must record misses; a 2 m gate hides the frame error it hunts |
| Credentials | Entered by hand in Unity on the build machine; config asset gitignored first | All repos are public |

## Architecture

```
Flutter /ar?destinationId=…  → IndoorArLaunchScreen
  └─ GET /places/:placeId → indoor pose
  └─ IndoorArLauncher.launch(IndoorArRequest v1)
       └─ MainActivity IndoorArChannel → UnityHostActivity (":unity")
            └─ IndoorArSession: Validate → Init → Auth → Localizing → Pinned
       ← IndoorArResult (arrived + checkDistanceM, …)  → result sheet
```

### NaviPetUnity — branch `feat/indoor-ar-door-verifier`, off `feat/indoor-ar-transport-spike`

1. `.gitignore`: add `Assets/Samples/MultiSet-SDK/**/Resources/MultiSetConfig.asset` and its `.meta`. Commit this before the SDK is imported.
2. Add the MultiSet SDK to `Packages/manifest.json` by git URL, pinned to a release tag.
3. `IndoorArSession`: reads the launch request, runs the state machine below, writes the result.
4. `DoorPin`: the existing `DoorMarker` prefab, placed as a child of the SDK's `Map Space` at `position`, rotated to `headingDeg`.
5. HUD: localization status, horizontal distance, floor label, wrong-floor banner, "I'm here" button, Exit button.
6. AAR rebuilt with `tools/build-indoor-ar-aar.sh` into NaviPetFlutter `android/unity-ar/` (gitignored).

### NaviPetFlutter — branch `feat/indoor-ar-launch`, off `main` after PR #44 merges

1. `/ar` route reads `destinationId` from the query and builds `IndoorArLaunchScreen`, replacing `ArNavigationScreen`.
2. PR #44's AR button is changed to push `/ar?destinationId=<id>`.
3. `IndoorArLaunchScreen` loads the place, checks camera permission, builds `IndoorArRequest`, launches, and shows the result sheet.
4. `/dev/indoor-ar-spike` gets a VEC room picker, so the device check can run without walking the outdoor route.
5. `IndoorArChannel` (Kotlin) keeps a result that arrives with no pending call; a new `pendingResult` method returns it once. Flutter calls `pendingResult` when the launch screen resumes.
6. `MAP_MISMATCH` added to the known error codes in `indoor_ar_contract.dart`.

### NavipetBackend

No change. Confirm the `/places/:placeId` `indoor` fields map one to one onto `IndoorArRequest` (`doorKey`, `floor`, `position`, `headingDeg`, `mapCode`, `frame`).

### Frame rule

Unchanged from the indoor AR flow design: every pose is in the MultiSet MapSet frame (left-handed, +Y up, metres, origin at the `Floor 1 2` map root). Nobody converts.

## Runtime flow

### Flutter `IndoorArLaunchScreen`

1. Load the place. No `indoor` object: "Indoor AR isn't available for this room". Network failure: error with Retry.
2. Camera permission. Denied: explanation, AR not opened. Permanently denied: "Open settings".
3. Launch and await the result.
4. Result sheet:
   - `arrived`: "Pin was X.X m from you".
   - `localizationFailed`: "Couldn't find your position" with Retry.
   - `cancelled`: back to the screen, no sheet.
   - `unavailable`: "AR not included in this build".
   - `error`: one message per `errorCode` (`ARCORE_UNSUPPORTED`, `MULTISET_AUTH`, `NETWORK`, `UNITY_EXITED`, `BAD_REQUEST`, `MAP_MISMATCH`, `BAD_RESULT`).
5. `debugPrint` every result: status, `checkDistanceM`, `confidence`, `localizationQueries`, `durationMs`.

### Unity `IndoorArSession`

| State | Behaviour | Exit |
|---|---|---|
| Validate | `frame` is `multiset-mapset` and `mapCode` equals the build's MapSet code | Otherwise `error MAP_MISMATCH` |
| Init | ARCore support check | Unsupported: `error ARCORE_UNSUPPORTED` |
| Auth | MultiSet authentication | Failure: `error MULTISET_AUTH`; offline: `error NETWORK` |
| Localizing | Coaching text "Point at walls, doors and signs"; each query increments `localizationQueries` | 30 s timeout: one retry; second timeout: `localizationFailed` |
| Pinned | Pin, horizontal distance, floor label. Camera height more than 2 m from the door's floor: banner "VEC 119 is on floor 1", pin stays | Tracking lost: hide pin, banner "Re-finding your position", back to Localizing. "I'm here": `arrived` |

- Exit button or Android back in any state: `cancelled`.
- `checkDistanceM` is the horizontal (XZ) distance from the camera to the door point at the tap.
- Re-localization happens only after tracking loss, never on a timer.
- 30 s, 2 m and one retry are starting values, tuned during the device check.

## Security

- MultiSet Client ID and Client Secret are never committed and never pasted into chat or a terminal.
- `MultiSetConfig.asset` is gitignored before the SDK is imported; a secret scan of the NaviPetUnity diff runs before every push.
- The AAR and APK contain the secret: they go to team test devices only, never to a GitHub release.

## Testing

### Automated (no AR hardware)

| Repo | Test |
|---|---|
| NaviPetUnity EditMode | Validate: wrong `frame` or `mapCode` gives `MAP_MISMATCH` |
| NaviPetUnity EditMode | State machine with a fake localizer: timeout → retry → `localizationFailed`; tracking lost → Localizing; Exit → `cancelled`; "I'm here" → `arrived` with distance |
| NaviPetUnity EditMode | Horizontal distance ignores Y |
| NaviPetUnity EditMode | Mesh check: for each of the 17 door poses (fixture copied from Supabase), a downward raycast onto `building scans/floor 1 + 2.glb` placed at the map root hits a floor surface within 0.5 m below the point |
| NaviPetFlutter unit | `MAP_MISMATCH` decodes; an unknown `errorCode` still decodes to `error` |
| NaviPetFlutter widget | `IndoorArLaunchScreen` with `FakeIndoorArLauncher`: no indoor data, permission denied, permanently denied, place load failure, each result status |
| NaviPetFlutter JVM | `IndoorArChannel` keeps a result with no pending call; `pendingResult` returns it once |
| NaviPetFlutter CI | Android build without `android/unity-ar/` passes |

The mesh check proves the export and the GLB import agree. It does not prove the live MultiSet frame; only the device check does.

### Manual device check

- One ARCore Android phone, APK built with the AAR and the tester's credentials.
- Doors on opposite wings: VEC119 and VEC128 (floor 1), VEC201 and VEC227 (floor 2).
- Three runs per door, launched from `/dev/indoor-ar-spike`, standing at the door when tapping "I'm here".
- Pass: median `checkDistanceM` ≤ 1 m for each door.
- Record per run: `checkDistanceM`, `confidence`, `localizationQueries`, `durationMs`, device model, Android version.
- Failure cases, once each: camera permission denied, network off, localization failure (camera covered), cancel mid-session.
- Reading failures: the same offset at every door means a frame or origin error; pins mirrored across the corridor mean a handedness error; random scatter means localization quality.
- Evidence (run table plus a screenshot or video) goes on #42, #47 and #49.

## Open questions

1. How many MultiSet API requests does one localization use, and is the free tier per month or total? Measured by `localizationQueries` on the first run.
2. Which ARCore Android device runs the check?
3. Which MultiSet SDK version and localization manager did Jomar use? Asked of Jomar; the fresh install matches them where possible.

## Build order

1. NaviPetUnity: gitignore, SDK import, credentials entered by hand, mesh check test.
2. NaviPetUnity: `IndoorArSession`, `DoorPin`, HUD, EditMode tests; AAR build.
3. NaviPetFlutter (after PR #44 merges): contract code, `IndoorArChannel` pending result, launch screen, room picker, tests.
4. Device check in VEC; evidence on #42, #47, #49.
