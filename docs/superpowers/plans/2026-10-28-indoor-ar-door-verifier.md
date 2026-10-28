# Indoor AR Door Verifier Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use **superpowers:executing-plans** and execute your assigned tasks **inline, in your own session** (no subagent dispatch). Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **Reporting chain:** workers → `lead-engineer` → `project-manager` → user. Workers report only to `lead-engineer` (`hc send lead-engineer "..."`), and only with completed work, unresolved blockers, or decisions that need input. `lead-engineer` sends `project-manager` one summary per finished part (A, C, D) and every blocker that needs the user. Nobody messages the user or `project-manager` directly except `lead-engineer`.

**Goal:** Prove on a real phone in VEC that MultiSet localization and the 17 Supabase door poses agree: one door pin per launch, "I'm here" records the horizontal distance and returns it to Flutter.

**Architecture:** Flutter `/ar?destinationId=` loads the place from `/places/:placeId`, builds bridge contract v1 `IndoorArRequest` from its `indoor` pose, and launches Unity through `IndoorArChannel`. Unity's pure-C# `IndoorArSession` state machine (Init → Auth → Localizing → Pinned → Done) is driven by `IndoorArRunner`, which wires AR Foundation and a MultiSet adapter behind `IIndoorArLocalizer`. The result JSON goes back unchanged through the existing host.

**Tech Stack:** Unity 6000.3.26f1, AR Foundation/ARCore 6.3.5, MultiSet Unity SDK (git URL), NUnit EditMode tests; Flutter (go_router, provider, permission_handler 12), Kotlin host, JUnit 4.

**Spec:** `docs/superpowers/specs/2026-10-28-indoor-ar-door-verifier-design.md` (commit `0beb353`, branch `docs/indoor-ar-door-verifier-spec`).

## Global Constraints

- MultiSet Client ID / Client Secret: never committed, never pasted into chat, a terminal, a herdr message, or a log. A human enters them in the Unity Inspector.
- `.gitignore` entry for `MultiSetConfig.asset` is committed **before** the SDK is imported.
- The AAR and any APK built from it contain the secret: team test devices only, never a GitHub release or public upload.
- Never print the Supabase service-role key.
- No `git push`, `git reset --hard`, `rm -rf`, migration or deploy without the user's yes, relayed by `lead-engineer` in that same request. Commits on your own feature branch are fine.
- Every pose is in frame `multiset-mapset` (left-handed, +Y up, metres, origin at the `Floor 1 2` map root). Nobody converts coordinates.
- MapSet code for this build: `MSET_XTBY7AM7ZK77`.
- Bridge contract stays v1 (`schemaVersion = 1`), one door per launch.
- Starting values, tuned only during the device check: localize timeout 30 s, one retry, wrong-floor threshold 2 m.
- NaviPetFlutter (`/Users/kaydee/Developer/Navipet/NaviPetFlutter/CLAUDE.md`): run GitNexus `impact` before editing any existing symbol and `detect_changes` before every commit.
- All three repos are public.

## Team assignment

| Part | Worker | Repo / branch | Starts |
|---|---|---|---|
| A — Unity (Tasks A1–A7) | `ar` | `/Users/kaydee/Developer/Navipet/NaviPetUnity`, `feat/indoor-ar-door-verifier` off `feat/indoor-ar-transport-spike` | now |
| B — Backend | none (pane closed) | — | done: verified by PM 2026-10-28 (see Part B) |
| C — Flutter (Tasks C1–C6) | `flutter` | `/Users/kaydee/Developer/Navipet/NaviPetFlutter`, `feat/indoor-ar-launch` off `main` | after PR #44 merges |
| D — Review | `qa` (report-only) | both | after each part finishes |
| E — Device check | humans | — | after A7 and C6 |

No `backend` worker: Part B needs no change. `ar` runs on Codex and `flutter` on Cursor Grok; `qa` (Claude) is a different model family from both, so it reviews every part.

Human gates (the worker stops and sends `lead-engineer` a blocker; the lead relays to `project-manager`): A2 step 4 (credentials), A7 step 5 (AAR to a device), Part E.

## File map

NaviPetUnity (`Assets/IndoorAr/…` unless noted):

| File | Change | Responsibility |
|---|---|---|
| `.gitignore` (repo root) | modify | ignore `MultiSetConfig.asset` |
| `Packages/manifest.json` (repo root) | modify | MultiSet SDK by git URL, pinned to a full commit sha (see Deviations) |
| `Scripts/IndoorArContract.cs` | modify | error-code constants, `CheckMap`, `LocalizationFailed`; frame check leaves `TryParseRequest` |
| `Scripts/IndoorArSession.cs` | create | pure state machine, distance, wrong floor |
| `Scripts/IIndoorArLocalizer.cs` | create | what the runner needs from MultiSet |
| `Scripts/MultiSetLocalizer.cs` | create | SDK adapter implementing `IIndoorArLocalizer` |
| `Scripts/IndoorArRunner.cs` | create | MonoBehaviour: wires session, localizer, AR Foundation, pin, HUD, bridge |
| `Scripts/IndoorArSpike.cs` (+ `.meta`) | delete | replaced by `IndoorArRunner` |
| `Scripts/IndoorAr.Runtime.asmdef` | modify | reference AR Foundation and the MultiSet runtime assembly |
| `Editor/IndoorArSetup.cs` | modify | `BuildScene` adds runner, localizer, SDK objects, pin prefab |
| `Tests/EditMode/IndoorArContractTests.cs` | modify | frame case moves to `CheckMap` tests; new builder tests |
| `Tests/EditMode/IndoorArSessionTests.cs` | create | state machine tests |
| `Tests/EditMode/IndoorArDoorMeshTests.cs` | create | 17-door mesh check |

The scene keeps its path `Assets/IndoorAr/Scenes/IndoorArSpike.unity` so `IndoorArExport.cs` and `tools/build-indoor-ar-aar.sh` stay unchanged.

NaviPetFlutter:

| File | Change | Responsibility |
|---|---|---|
| `lib/data/indoor_ar_contract.dart` | modify | `IndoorArRequest.fromDoorPose` |
| `lib/data/campus_place.dart` | modify | `indoorRequest` parsed from `indoor` |
| `lib/data/indoor_ar_launcher.dart` | modify | `pendingResult()` on the interface, Android impl, fake |
| `android/app/src/main/kotlin/com/navipet/navipet/IndoorArResultSlot.kt` | create | holds an unclaimed result |
| `android/app/src/main/kotlin/com/navipet/navipet/IndoorArChannel.kt` | modify | `pendingResult` method, keep unclaimed result |
| `android/app/src/main/AndroidManifest.xml` | modify | `CAMERA` permission |
| `lib/screens/indoor_ar_launch_screen.dart` | create | load place, permission, launch, result |
| `lib/screens/ar_navigation_screen.dart` | delete | static mockup replaced |
| `lib/router/app_router.dart` | modify | `/ar` builds `IndoorArLaunchScreen` |
| `lib/screens/indoor_ar_spike_screen.dart` | modify | becomes the VEC room picker + recovered result |
| `lib/screens/map_screen.dart` | modify (after #44) | AR button pushes `destinationId`, only for indoor rooms |
| tests | create/modify | listed per task |

---

## Part A — NaviPetUnity (worker: `ar`)

Run EditMode tests (the Unity editor must NOT have this project open; the project lock blocks batch mode):

```bash
UNITY="/Applications/Unity/Hub/Editor/6000.3.26f1/Unity.app/Contents/MacOS/Unity"
"$UNITY" -batchmode -nographics -projectPath /Users/kaydee/Developer/Navipet/NaviPetUnity \
  -runTests -testPlatform EditMode -testFilter "<TestClassName>" \
  -testResults "$TMPDIR/indoor-ar-editmode.xml" -logFile -
```

Pass/fail is in `$TMPDIR/indoor-ar-editmode.xml` (`result="Passed"` / `"Failed"` on each `test-case`).

### Task A1: Branch and gitignore the MultiSet config

**Files:**
- Modify: `/Users/kaydee/Developer/Navipet/NaviPetUnity/.gitignore`

- [ ] **Step 1: Branch**

```bash
cd /Users/kaydee/Developer/Navipet/NaviPetUnity
git status --short   # expect only " M .vscode/settings.json"; leave it unstaged
git switch feat/indoor-ar-transport-spike
git switch -c feat/indoor-ar-door-verifier
```

- [ ] **Step 2: Append to `.gitignore`**

```gitignore

# MultiSet credentials (Client ID / Secret). Never commit: all repos are public.
/[Aa]ssets/Samples/MultiSet-SDK/**/Resources/MultiSetConfig.asset
/[Aa]ssets/Samples/MultiSet-SDK/**/Resources/MultiSetConfig.asset.meta
```

- [ ] **Step 3: Verify the pattern matches before the file exists**

```bash
git check-ignore -v --no-index "Assets/Samples/MultiSet-SDK/1.0.0/Sample Scenes/Resources/MultiSetConfig.asset"
git check-ignore -v --no-index "Assets/Samples/MultiSet-SDK/1.0.0/Sample Scenes/Resources/MultiSetConfig.asset.meta"
```

Expected: both print the `.gitignore` line. No output = pattern wrong; fix before Step 4.

- [ ] **Step 4: Commit**

```bash
git add .gitignore
git commit -m "chore(indoor-ar): ignore the MultiSet credentials asset"
```

### Task A2: Import the MultiSet SDK (human gate for credentials)

**Files:**
- Modify: `Packages/manifest.json`

- [ ] **Step 1: Find the package name and newest tag**

```bash
git ls-remote --tags https://github.com/MultiSet-AI/multiset-unity-sdk.git | tail -5
curl -fsSL https://raw.githubusercontent.com/MultiSet-AI/multiset-unity-sdk/main/package.json | grep -E '"(name|version|unity)"'
```

Record `<name>` and the newest tag `<tag>`. If `package.json` is not at the repo root, read the repo README for the install path and use it in Step 2.

- [ ] **Step 2: Add the dependency**, pinned to the tag, in `Packages/manifest.json` `dependencies`:

```json
"<name>": "https://github.com/MultiSet-AI/multiset-unity-sdk.git#<tag>",
```

- [ ] **Step 3: Resolve packages and import the sample** with the editor open on the project: Package Manager → MultiSet SDK → Samples → Import. Then check:

```bash
git status --short
git check-ignore -v Assets/Samples/MultiSet-SDK/*/"Sample Scenes"/Resources/MultiSetConfig.asset
```

Expected: `MultiSetConfig.asset` does NOT appear in `git status`; `check-ignore` prints the rule. If it appears, stop and fix the ignore rule before anything else.

- [ ] **Step 4: HUMAN GATE — credentials.** Send `lead-engineer`: `BLOCKER A2: MultiSet SDK <name>@<tag> imported. A human must open NaviPetUnity in Unity 6000.3.26f1, select Assets/Samples/MultiSet-SDK/<version>/Sample Scenes/Resources/MultiSetConfig.asset and type the Client ID and Client Secret in the Inspector. Do not paste them anywhere else. Reply "credentials in" when done.` Continue with Tasks A3–A5 while waiting; they do not need credentials.

- [ ] **Step 5: Commit** (manifest, lock file, sample files; never the config asset)

```bash
git add Packages/manifest.json Packages/packages-lock.json Assets/Samples
git status --short | grep -i MultiSetConfig && echo "STOP: config staged" || echo "ok"
git commit -m "build(indoor-ar): add MultiSet Unity SDK <tag>"
```

### Task A3: Contract — error codes, `CheckMap`, `LocalizationFailed`

**Files:**
- Modify: `Assets/IndoorAr/Scripts/IndoorArContract.cs`
- Test: `Assets/IndoorAr/Tests/EditMode/IndoorArContractTests.cs`

**Interfaces:**
- Produces: `IndoorArContract.MapMismatch`, `.ArcoreUnsupported`, `.MultisetAuth`, `.Network` (string constants); `IndoorArContract.CheckMap(IndoorArRequest request, string buildMapCode) : bool`; `IndoorArContract.LocalizationFailed(int localizationQueries, long durationMs) : string`. `TryParseRequest` no longer checks `frame`.

- [ ] **Step 1: Write the failing tests.** In `IndoorArContractTests.cs`, delete this line from `RejectsABadRequest`:

```csharp
    [TestCase("{\"schemaVersion\":1,\"doorKey\":\"VEC119\",\"floor\":\"1\",\"mapCode\":\"M\",\"frame\":\"unity-world\"}")]
```

and add these tests to the class:

```csharp
    [Test]
    public void ParsesAForeignFrameSoTheSessionCanReportMapMismatch()
    {
        var json = Vec119.Replace("multiset-mapset", "unity-world");
        Assert.IsTrue(IndoorArContract.TryParseRequest(json, out var request));
        Assert.AreEqual("unity-world", request.frame);
    }

    [TestCase("multiset-mapset", "MSET_XTBY7AM7ZK77", true)]
    [TestCase("unity-world", "MSET_XTBY7AM7ZK77", false)]
    [TestCase("multiset-mapset", "MSET_OTHER", false)]
    public void ChecksFrameAndMapCode(string frame, string mapCode, bool expected)
    {
        var request = new IndoorArRequest { frame = frame, mapCode = mapCode };
        Assert.AreEqual(expected, IndoorArContract.CheckMap(request, "MSET_XTBY7AM7ZK77"));
    }

    [Test]
    public void BuildsLocalizationFailed()
    {
        Assert.AreEqual(
            "{\"status\":\"localizationFailed\",\"localizationQueries\":4,\"durationMs\":60000}",
            IndoorArContract.LocalizationFailed(4, 60000));
    }

    [Test]
    public void ErrorCodesMatchTheDartContract()
    {
        Assert.AreEqual("MAP_MISMATCH", IndoorArContract.MapMismatch);
        Assert.AreEqual("ARCORE_UNSUPPORTED", IndoorArContract.ArcoreUnsupported);
        Assert.AreEqual("MULTISET_AUTH", IndoorArContract.MultisetAuth);
        Assert.AreEqual("NETWORK", IndoorArContract.Network);
    }
```

- [ ] **Step 2: Run, expect FAIL** (`-testFilter IndoorArContractTests`): compile errors for `CheckMap`, `LocalizationFailed`, the constants.

- [ ] **Step 3: Implement.** In `IndoorArContract.cs`:

Add after `public const string Frame = "multiset-mapset";`:

```csharp
        public const string MapMismatch = "MAP_MISMATCH";
        public const string ArcoreUnsupported = "ARCORE_UNSUPPORTED";
        public const string MultisetAuth = "MULTISET_AUTH";
        public const string Network = "NETWORK";
```

In `TryParseRequest`, change

```csharp
                || string.IsNullOrEmpty(parsed.mapCode)
                || parsed.frame != Frame)
```

to

```csharp
                || string.IsNullOrEmpty(parsed.mapCode))
```

Add after `TryParseRequest`:

```csharp
        /// <summary>
        /// A pose in another frame or map would put the pin in the wrong place, so
        /// the session refuses it as MAP_MISMATCH instead of guessing.
        /// </summary>
        public static bool CheckMap(IndoorArRequest request, string buildMapCode) =>
            request.frame == Frame && request.mapCode == buildMapCode;
```

Add after `Cancelled`:

```csharp
        public static string LocalizationFailed(int localizationQueries, long durationMs) =>
            Build("localizationFailed", null, null, localizationQueries, durationMs);
```

- [ ] **Step 4: Run, expect PASS** (all `IndoorArContractTests`).

- [ ] **Step 5: Commit**

```bash
git add Assets/IndoorAr/Scripts/IndoorArContract.cs Assets/IndoorAr/Tests/EditMode/IndoorArContractTests.cs
git commit -m "feat(indoor-ar): add MAP_MISMATCH check and localizationFailed result"
```

### Task A4: `IndoorArSession` state machine

**Files:**
- Create: `Assets/IndoorAr/Scripts/IndoorArSession.cs`
- Test: `Assets/IndoorAr/Tests/EditMode/IndoorArSessionTests.cs`

**Interfaces:**
- Consumes: A3 (`CheckMap`, `LocalizationFailed`, error-code constants).
- Produces:
  - `enum IndoorArState { Init, Auth, Localizing, Pinned, Done }`
  - `new IndoorArSession(IndoorArRequest request, string buildMapCode)`
  - properties `State`, `Queries`, `ResultJson` (non-null once `Done`), `Request`, `WasPinned`
  - `event System.Action LocalizeRequested`
  - methods `OnArSupport(bool)`, `OnAuthenticated()`, `OnAuthFailed(bool offline)`, `OnQuerySent()`, `OnLocalized()`, `OnTrackingLost()`, `Tick(float dt)`, `ImHere(Vector3 cameraInMap)`, `Cancel()`, `HorizontalDistance(Vector3) : float`, `IsWrongFloor(Vector3) : bool`
  - constants `LocalizeTimeoutS = 30f`, `WrongFloorM = 2f`

- [ ] **Step 1: Write the failing tests** — `IndoorArSessionTests.cs`:

```csharp
using IndoorAr;
using NUnit.Framework;
using UnityEngine;

public class IndoorArSessionTests
{
    const string MapCode = "MSET_XTBY7AM7ZK77";

    static IndoorArRequest Vec119(string frame = "multiset-mapset", string mapCode = MapCode) =>
        new IndoorArRequest
        {
            schemaVersion = 1, room = "119", doorKey = "VEC119", floor = "1",
            position = new IndoorArVector3 { x = -5.7651f, y = -1.8186f, z = 22.6689f },
            headingDeg = 185.36f, mapCode = mapCode, frame = frame,
        };

    static IndoorArSession Localizing(out int localizeRequests)
    {
        var session = new IndoorArSession(Vec119(), MapCode);
        var count = 0;
        session.LocalizeRequested += () => count++;
        session.OnArSupport(true);
        session.OnAuthenticated();
        localizeRequests = count;
        return session;
    }

    [TestCase("unity-world", MapCode)]
    [TestCase("multiset-mapset", "MSET_OTHER")]
    public void WrongFrameOrMapIsMapMismatch(string frame, string mapCode)
    {
        var session = new IndoorArSession(Vec119(frame, mapCode), MapCode);
        Assert.AreEqual(IndoorArState.Done, session.State);
        Assert.AreEqual(
            "{\"status\":\"error\",\"errorCode\":\"MAP_MISMATCH\",\"localizationQueries\":0,\"durationMs\":0}",
            session.ResultJson);
    }

    [Test]
    public void UnsupportedDeviceIsArcoreUnsupported()
    {
        var session = new IndoorArSession(Vec119(), MapCode);
        session.OnArSupport(false);
        StringAssert.Contains("\"errorCode\":\"ARCORE_UNSUPPORTED\"", session.ResultJson);
    }

    [TestCase(false, "MULTISET_AUTH")]
    [TestCase(true, "NETWORK")]
    public void AuthFailureIsReported(bool offline, string code)
    {
        var session = new IndoorArSession(Vec119(), MapCode);
        session.OnArSupport(true);
        Assert.AreEqual(IndoorArState.Auth, session.State);
        session.OnAuthFailed(offline);
        StringAssert.Contains($"\"errorCode\":\"{code}\"", session.ResultJson);
    }

    [Test]
    public void AuthStartsLocalizingAndCountsQueries()
    {
        var session = Localizing(out var requests);
        Assert.AreEqual(IndoorArState.Localizing, session.State);
        Assert.AreEqual(1, requests);
        session.OnQuerySent();
        session.OnQuerySent();
        Assert.AreEqual(2, session.Queries);
    }

    [Test]
    public void TimeoutRetriesOnceThenFails()
    {
        var session = new IndoorArSession(Vec119(), MapCode);
        var requests = 0;
        session.LocalizeRequested += () => requests++;
        session.OnArSupport(true);
        session.OnAuthenticated();
        session.OnQuerySent();

        session.Tick(IndoorArSession.LocalizeTimeoutS);
        Assert.AreEqual(IndoorArState.Localizing, session.State);
        Assert.AreEqual(2, requests);

        session.Tick(IndoorArSession.LocalizeTimeoutS);
        Assert.AreEqual(
            "{\"status\":\"localizationFailed\",\"localizationQueries\":1,\"durationMs\":60000}",
            session.ResultJson);
    }

    [Test]
    public void TrackingLossGoesBackToLocalizingWithAFreshRetry()
    {
        var session = new IndoorArSession(Vec119(), MapCode);
        var requests = 0;
        session.LocalizeRequested += () => requests++;
        session.OnArSupport(true);
        session.OnAuthenticated();
        session.Tick(IndoorArSession.LocalizeTimeoutS); // uses the retry
        session.OnLocalized();
        Assert.AreEqual(IndoorArState.Pinned, session.State);

        session.OnTrackingLost();
        Assert.AreEqual(IndoorArState.Localizing, session.State);
        Assert.IsTrue(session.WasPinned);
        Assert.AreEqual(3, requests);
        session.Tick(IndoorArSession.LocalizeTimeoutS);
        Assert.AreEqual(IndoorArState.Localizing, session.State, "retry budget resets after tracking loss");
    }

    [Test]
    public void ImHereReportsHorizontalDistanceOnlyWhenPinned()
    {
        var session = Localizing(out _);
        var camera = new Vector3(-5.7651f + 3f, 10f, 22.6689f + 4f);
        session.ImHere(camera);
        Assert.AreEqual(IndoorArState.Localizing, session.State, "ignored before the pin shows");

        session.OnLocalized();
        session.Tick(1.5f);
        session.ImHere(camera);
        Assert.AreEqual(
            "{\"status\":\"arrived\",\"checkDistanceM\":5,\"localizationQueries\":0,\"durationMs\":1500}",
            session.ResultJson);
    }

    [Test]
    public void HorizontalDistanceIgnoresHeight()
    {
        var session = new IndoorArSession(Vec119(), MapCode);
        Assert.AreEqual(0f, session.HorizontalDistance(new Vector3(-5.7651f, 50f, 22.6689f)), 1e-4f);
    }

    [TestCase(-0.4f, false)]  // phone held on floor 1
    [TestCase(3.7f, true)]    // phone held on floor 2
    public void WrongFloorUsesTheDoorHeight(float cameraY, bool wrong)
    {
        var session = new IndoorArSession(Vec119(), MapCode);
        Assert.AreEqual(wrong, session.IsWrongFloor(new Vector3(0f, cameraY, 0f)));
    }

    [Test]
    public void CancelWorksInAnyStateAndOnlyOnce()
    {
        var session = Localizing(out _);
        session.Tick(0.25f);
        session.Cancel();
        session.Cancel();
        session.OnLocalized();
        Assert.AreEqual(IndoorArState.Done, session.State);
        Assert.AreEqual(
            "{\"status\":\"cancelled\",\"localizationQueries\":0,\"durationMs\":250}",
            session.ResultJson);
    }
}
```

- [ ] **Step 2: Run, expect FAIL** (`-testFilter IndoorArSessionTests`): `IndoorArSession` does not exist.

- [ ] **Step 3: Implement** — `IndoorArSession.cs`:

```csharp
using System;
using UnityEngine;

namespace IndoorAr
{
    public enum IndoorArState { Init, Auth, Localizing, Pinned, Done }

    /// <summary>
    /// Door verifier state machine. Pure C# so EditMode tests can drive it:
    /// IndoorArRunner feeds it AR, MultiSet and frame-time events and delivers
    /// ResultJson once State is Done.
    /// </summary>
    public sealed class IndoorArSession
    {
        public const float LocalizeTimeoutS = 30f;
        public const float WrongFloorM = 2f;

        float _elapsedS;
        float _localizingS;
        bool _retried;

        public IndoorArSession(IndoorArRequest request, string buildMapCode)
        {
            Request = request;
            if (!IndoorArContract.CheckMap(request, buildMapCode))
                Finish(IndoorArContract.Error(IndoorArContract.MapMismatch, 0, 0));
        }

        /// <summary>Raised when the localizer must start a localization attempt.</summary>
        public event Action LocalizeRequested;

        public IndoorArRequest Request { get; }
        public IndoorArState State { get; private set; } = IndoorArState.Init;
        public int Queries { get; private set; }
        public bool WasPinned { get; private set; }
        public string ResultJson { get; private set; }

        long ElapsedMs => (long)(_elapsedS * 1000f);

        public void OnArSupport(bool supported)
        {
            if (State != IndoorArState.Init) return;
            if (supported) State = IndoorArState.Auth;
            else Finish(IndoorArContract.Error(IndoorArContract.ArcoreUnsupported, Queries, ElapsedMs));
        }

        public void OnAuthenticated()
        {
            if (State == IndoorArState.Auth) StartLocalizing();
        }

        public void OnAuthFailed(bool offline)
        {
            if (State != IndoorArState.Auth) return;
            var code = offline ? IndoorArContract.Network : IndoorArContract.MultisetAuth;
            Finish(IndoorArContract.Error(code, Queries, ElapsedMs));
        }

        public void OnQuerySent()
        {
            if (State == IndoorArState.Localizing) Queries++;
        }

        public void OnLocalized()
        {
            if (State != IndoorArState.Localizing) return;
            State = IndoorArState.Pinned;
            WasPinned = true;
        }

        // Re-localize only after tracking loss, never on a timer.
        public void OnTrackingLost()
        {
            if (State == IndoorArState.Pinned) StartLocalizing();
        }

        public void Tick(float dt)
        {
            if (State == IndoorArState.Done) return;
            _elapsedS += dt;
            if (State != IndoorArState.Localizing) return;
            _localizingS += dt;
            if (_localizingS < LocalizeTimeoutS) return;
            if (_retried)
            {
                Finish(IndoorArContract.LocalizationFailed(Queries, ElapsedMs));
                return;
            }
            _retried = true;
            _localizingS = 0f;
            LocalizeRequested?.Invoke();
        }

        /// <param name="cameraInMap">Camera position in the MapSet frame.</param>
        public void ImHere(Vector3 cameraInMap)
        {
            if (State != IndoorArState.Pinned) return;
            Finish(IndoorArContract.Arrived(HorizontalDistance(cameraInMap), Queries, ElapsedMs));
        }

        public void Cancel()
        {
            if (State != IndoorArState.Done) Finish(IndoorArContract.Cancelled(Queries, ElapsedMs));
        }

        public float HorizontalDistance(Vector3 cameraInMap)
        {
            var door = Request.position;
            return new Vector2(cameraInMap.x - door.x, cameraInMap.z - door.z).magnitude;
        }

        public bool IsWrongFloor(Vector3 cameraInMap) =>
            Mathf.Abs(cameraInMap.y - Request.position.y) > WrongFloorM;

        void StartLocalizing()
        {
            State = IndoorArState.Localizing;
            _localizingS = 0f;
            _retried = false;
            LocalizeRequested?.Invoke();
        }

        void Finish(string resultJson)
        {
            ResultJson = resultJson;
            State = IndoorArState.Done;
        }
    }
}
```

- [ ] **Step 4: Run, expect PASS** (`IndoorArSessionTests` and `IndoorArContractTests`).

- [ ] **Step 5: Commit**

```bash
git add Assets/IndoorAr/Scripts/IndoorArSession.cs* Assets/IndoorAr/Tests/EditMode/IndoorArSessionTests.cs*
git commit -m "feat(indoor-ar): add door verifier session state machine"
```

### Task A5: Mesh check — 17 doors sit on the scanned floor

**Files:**
- Create: `Assets/IndoorAr/Tests/EditMode/IndoorArDoorMeshTests.cs`
- Modify (only if Step 2 fails to compile on `UnityEditor` or physics): `Assets/IndoorAr/Tests/EditMode/IndoorAr.Tests.EditMode.asmdef`

Needs A2 Step 3 done: `floor 1 + 2.glb` imports through glTFast (a MultiSet dependency); its `.meta` is a `ScriptedImporter`.

- [ ] **Step 1: Write the test** — `IndoorArDoorMeshTests.cs`:

```csharp
using NUnit.Framework;
using UnityEditor;
using UnityEngine;

/// <summary>
/// Proves the Supabase door export and the imported scan agree: the scan at
/// identity (the MapSet origin) has a floor just under each door point. It does
/// not prove the live MultiSet frame; only the device check does.
/// </summary>
public class IndoorArDoorMeshTests
{
    const string ScanPath = "Assets/building scans/floor 1 + 2.glb";
    const float MaxDropM = 0.5f;
    const float StartAboveM = 0.1f;

    // vec_destination_points, active doors, map_version 1, copied 2026-10-28.
    static readonly object[] Doors =
    {
        new object[] { "VEC119", -5.7651f, -1.8186f, 22.6689f },
        new object[] { "VEC120", -8.5041f, -1.7956f, 22.9859f },
        new object[] { "VEC121", -22.0913f, -1.8136f, 24.4311f },
        new object[] { "VEC124", -21.8677f, -1.8286f, 27.4932f },
        new object[] { "VEC127", 0.4029f, -1.8616f, 30.2211f },
        new object[] { "VEC128", 23.6032f, -1.8326f, 22.9838f },
        new object[] { "VEC132", 21.425f, -1.7796f, 20.306f },
        new object[] { "VEC134", 16.0777f, -1.8346f, 20.806f },
        new object[] { "VEC136", 11.8828f, -1.7676f, 21.2616f },
        new object[] { "VEC201", -24.1111f, 2.3284f, 27.6193f },
        new object[] { "VEC202", -15.008f, 2.3284f, 26.7658f },
        new object[] { "VEC215", 8.2043f, 2.3284f, 28.7999f },
        new object[] { "VEC217", 14.2003f, 2.3284f, 23.8174f },
        new object[] { "VEC218", 21.0592f, 2.3284f, 23.1743f },
        new object[] { "VEC220", -3.2028f, 2.3284f, 22.7875f },
        new object[] { "VEC224", 9.5549f, 2.3284f, 21.513f },
        new object[] { "VEC227", 20.9229f, 2.3284f, 20.3065f },
    };

    GameObject _scan;

    [OneTimeSetUp]
    public void LoadScan()
    {
        var prefab = AssetDatabase.LoadAssetAtPath<GameObject>(ScanPath);
        Assert.IsNotNull(prefab, $"{ScanPath} did not import as a GameObject. Is glTFast installed?");
        _scan = Object.Instantiate(prefab); // identity transform = MapSet origin
        foreach (var filter in _scan.GetComponentsInChildren<MeshFilter>())
            filter.gameObject.AddComponent<MeshCollider>().sharedMesh = filter.sharedMesh;
        Physics.SyncTransforms();
    }

    [OneTimeTearDown]
    public void Unload() => Object.DestroyImmediate(_scan);

    [TestCaseSource(nameof(Doors))]
    public void DoorSitsOnTheScannedFloor(string doorKey, float x, float y, float z)
    {
        var start = new Vector3(x, y + StartAboveM, z);
        Assert.IsTrue(
            Physics.Raycast(start, Vector3.down, out var hit, MaxDropM + StartAboveM),
            $"{doorKey}: no surface within {MaxDropM} m below ({x}, {y}, {z})");
        Debug.Log($"[IndoorAr] {doorKey} floor drop {y - hit.point.y:0.000} m");
    }
}
```

- [ ] **Step 2: Run** (`-testFilter IndoorArDoorMeshTests`). Expected: 17 passed.

- [ ] **Step 3: If any door fails, do NOT change the test or the data.** Read the failures and send `lead-engineer` one message with the failing door keys, the logged drops for the passing ones, and which pattern it matches:
  - every door off by the same offset → frame/origin error (the scan's root transform, or the export, is not at the `Floor 1 2` map root);
  - doors pass only after mirroring x (try `-x` in a scratch copy, never commit it) → handedness error from the GLB import;
  - random misses → individual bad points.
  Continue with A6 while the lead decides.

- [ ] **Step 4: Commit** (passing or not; a failing mesh check is a finding, but say so in the commit message)

```bash
git add Assets/IndoorAr/Tests/EditMode/IndoorArDoorMeshTests.cs*
git commit -m "test(indoor-ar): check the 17 VEC door poses against the floor 1+2 scan"
```

### Task A6: MultiSet adapter behind `IIndoorArLocalizer`

**Files:**
- Create: `Assets/IndoorAr/Scripts/IIndoorArLocalizer.cs`, `Assets/IndoorAr/Scripts/MultiSetLocalizer.cs`
- Modify: `Assets/IndoorAr/Scripts/IndoorAr.Runtime.asmdef`

**Interfaces:**
- Produces `IIndoorArLocalizer` exactly as below. `MultiSetLocalizer : MonoBehaviour, IIndoorArLocalizer`, with `[SerializeField] string mapCode = "MSET_XTBY7AM7ZK77";`.

The plan cannot give the SDK calls: nobody on the team has read the SDK source yet. This task starts by reading it. **Never guess an SDK member name; every SDK call must be one you found in the imported source.**

- [ ] **Step 1: Create the interface** — `IIndoorArLocalizer.cs`:

```csharp
using System;
using UnityEngine;

namespace IndoorAr
{
    /// <summary>What IndoorArRunner needs from MultiSet. MultiSetLocalizer adapts the SDK.</summary>
    public interface IIndoorArLocalizer
    {
        event Action Authenticated;
        /// <summary>true when the failure was no network, false for rejected credentials or any other auth error.</summary>
        event Action<bool> AuthFailed;
        /// <summary>One localization request sent to MultiSet (one API request).</summary>
        event Action QuerySent;
        event Action Localized;

        /// <summary>Transform at the MapSet origin; the SDK moves it on every localization.</summary>
        Transform MapSpace { get; }
        string MapCode { get; }

        void Authenticate();
        /// <summary>Starts one localization attempt against MapCode in MapSet mode.</summary>
        void Localize();
    }
}
```

- [ ] **Step 2: Read the SDK.** Find and read the localization manager, the auth call and the sample scene:

```bash
cd /Users/kaydee/Developer/Navipet/NaviPetUnity
SDK=$(find Library/PackageCache -maxdepth 1 -iname '*multiset*' | head -1); echo "$SDK"
grep -rn "class MapLocalizationManager\|class .*Auth\|event \|UnityEvent\|public void " "$SDK" --include='*.cs' | grep -iv test | head -80
find Assets/Samples/MultiSet-SDK -name '*.unity'
```

Write down, in the adapter's header comment, the SDK names for: authenticate call + success/failure callbacks; how a failure tells "offline" apart from "bad credentials"; MapSet mode + runtime map code field; the "localize now" call; the localization success/failure callbacks; where one API request is sent (for `QuerySent`); the `Map Space` transform; whether the SDK auto-localizes on start (must be turned off: the session decides when to localize).

- [ ] **Step 3: Implement `MultiSetLocalizer.cs`**, mapping each SDK member from Step 2 onto the interface. Rules:
  - Raise each event on the Unity main thread.
  - Set MapSet mode and `mapCode` on the SDK from code in `Awake`, not only in the Inspector.
  - Disable SDK auto-localization, auto-relocalization timers and any SDK UI that duplicates the HUD.
  - Never log credentials or tokens.
  - Do not edit any file under `Library/PackageCache` or the SDK sample scripts.

- [ ] **Step 4: asmdef.** Add to `IndoorAr.Runtime.asmdef` `references`: the AR Foundation assembly name exactly as it appears in `Assets/IndoorAr/Editor/IndoorAr.Editor.asmdef`, and the MultiSet runtime assembly name from the SDK's `.asmdef`. If the SDK has no asmdef (its scripts compile into `Assembly-CSharp`), `IndoorAr.Runtime` cannot reference it: move `MultiSetLocalizer.cs` to `Assets/IndoorAr/MultiSet/MultiSetLocalizer.cs` outside any asmdef and say so in the report.

- [ ] **Step 5: Compile check**: run all EditMode tests (`-testFilter IndoorAr`). Expected: compiles, all previous tests pass.

- [ ] **Step 6: Commit**

```bash
git add Assets/IndoorAr
git commit -m "feat(indoor-ar): adapt the MultiSet SDK behind IIndoorArLocalizer"
```

### Task A7: Runner, HUD, scene, AAR

**Files:**
- Create: `Assets/IndoorAr/Scripts/IndoorArRunner.cs`
- Delete: `Assets/IndoorAr/Scripts/IndoorArSpike.cs`, `Assets/IndoorAr/Scripts/IndoorArSpike.cs.meta`
- Modify: `Assets/IndoorAr/Editor/IndoorArSetup.cs` (`BuildScene`)

**Interfaces:**
- Consumes: `IndoorArSession` (A4), `IIndoorArLocalizer` / `MultiSetLocalizer` (A6), `IndoorArBridge.ReadRequestJson()` / `IndoorArBridge.Deliver(string)` (existing).
- Produces: `IndoorArRunner.Configure(MonoBehaviour localizer, GameObject doorPinPrefab, Camera arCamera)` for the editor setup.

- [ ] **Step 1: Write `IndoorArRunner.cs`**:

```csharp
using System.Collections;
using UnityEngine;
using UnityEngine.XR.ARFoundation;
#if ENABLE_INPUT_SYSTEM
using UnityEngine.InputSystem;
#endif

namespace IndoorAr
{
    /// <summary>
    /// Runs one door verification: reads the launch request, drives
    /// IndoorArSession from AR Foundation and the localizer, shows the pin and
    /// HUD, and hands the result to the Android host.
    /// </summary>
    public class IndoorArRunner : MonoBehaviour
    {
        [SerializeField] MonoBehaviour localizerBehaviour; // must implement IIndoorArLocalizer
        [SerializeField] GameObject doorPinPrefab;
        [SerializeField] Camera arCamera;

        IIndoorArLocalizer _localizer;
        IndoorArSession _session;
        Transform _pin;
        bool _delivered;
        GUIStyle _label;
        GUIStyle _button;

        public void Configure(MonoBehaviour localizer, GameObject pinPrefab, Camera camera)
        {
            localizerBehaviour = localizer;
            doorPinPrefab = pinPrefab;
            arCamera = camera;
        }

        IEnumerator Start()
        {
            _localizer = (IIndoorArLocalizer)localizerBehaviour;
            if (!IndoorArContract.TryParseRequest(IndoorArBridge.ReadRequestJson(), out var request))
            {
                Deliver(IndoorArContract.Error(IndoorArContract.BadRequest, 0, 0));
                yield break;
            }
            _session = new IndoorArSession(request, _localizer.MapCode);
            if (_session.State == IndoorArState.Done) yield break; // MAP_MISMATCH, delivered in Update
            _session.LocalizeRequested += _localizer.Localize;
            _localizer.Authenticated += _session.OnAuthenticated;
            _localizer.AuthFailed += _session.OnAuthFailed;
            _localizer.QuerySent += _session.OnQuerySent;
            _localizer.Localized += _session.OnLocalized;

            yield return ARSession.CheckAvailability();
            _session.OnArSupport(ARSession.state != ARSessionState.Unsupported);
            if (_session.State == IndoorArState.Auth) _localizer.Authenticate();
        }

        void Update()
        {
            if (_session == null || _delivered) return;
            if (BackPressed()) _session.Cancel();
            if (_session.State == IndoorArState.Pinned && ARSession.state != ARSessionState.SessionTracking)
                _session.OnTrackingLost();
            _session.Tick(Time.unscaledDeltaTime);
            UpdatePin();
            if (_session.State == IndoorArState.Done) Deliver(_session.ResultJson);
        }

        void UpdatePin()
        {
            var pinned = _session.State == IndoorArState.Pinned;
            if (pinned && _pin == null)
            {
                var door = _session.Request;
                _pin = Instantiate(doorPinPrefab, _localizer.MapSpace).transform;
                _pin.localPosition = new Vector3(door.position.x, door.position.y, door.position.z);
                _pin.localRotation = Quaternion.Euler(0f, door.headingDeg, 0f);
            }
            if (_pin != null) _pin.gameObject.SetActive(pinned);
        }

        Vector3 CameraInMap() => _localizer.MapSpace.InverseTransformPoint(arCamera.transform.position);

        void OnGUI()
        {
            if (_session == null || _delivered) return;
            var fontSize = Screen.height / 32;
            _label ??= new GUIStyle(GUI.skin.label)
                { fontSize = fontSize, alignment = TextAnchor.MiddleCenter, wordWrap = true };
            _button ??= new GUIStyle(GUI.skin.button) { fontSize = fontSize };
            var width = Screen.width * 0.8f;
            var height = Screen.height * 0.08f;
            var x = (Screen.width - width) / 2f;

            GUI.Label(new Rect(x, Screen.height * 0.06f, width, height), StatusText(), _label);
            if (_session.State == IndoorArState.Pinned)
            {
                var camera = CameraInMap();
                var door = _session.Request;
                GUI.Label(new Rect(x, Screen.height * 0.14f, width, height),
                    $"{door.doorKey} · floor {door.floor} · {_session.HorizontalDistance(camera):0.0} m", _label);
                if (_session.IsWrongFloor(camera))
                    GUI.Label(new Rect(x, Screen.height * 0.22f, width, height),
                        $"{door.doorKey} is on floor {door.floor}", _label);
                if (GUI.Button(new Rect(x, Screen.height * 0.74f, width, height), "I'm here", _button))
                    _session.ImHere(camera);
            }
            if (GUI.Button(new Rect(x, Screen.height * 0.86f, width, height), "Exit", _button))
                _session.Cancel();
        }

        string StatusText() => _session.State switch
        {
            IndoorArState.Init => "Starting AR…",
            IndoorArState.Auth => "Connecting to MultiSet…",
            IndoorArState.Localizing => _session.WasPinned
                ? "Re-finding your position"
                : "Point at walls, doors and signs",
            IndoorArState.Pinned => "Walk to the pin, then tap I'm here",
            _ => "",
        };

        void Deliver(string resultJson)
        {
            if (_delivered) return;
            _delivered = true;
            IndoorArBridge.Deliver(resultJson);
        }

        // Android's back button arrives as Escape.
        static bool BackPressed()
        {
#if ENABLE_INPUT_SYSTEM
            return Keyboard.current != null && Keyboard.current.escapeKey.wasPressedThisFrame;
#else
            return Input.GetKeyDown(KeyCode.Escape);
#endif
        }
    }
}
```

If A6 Step 4 moved `MultiSetLocalizer` out of the asmdef, `IndoorArRunner` still compiles: it only uses the interface.

- [ ] **Step 2: Delete the spike behaviour**

```bash
git rm Assets/IndoorAr/Scripts/IndoorArSpike.cs Assets/IndoorAr/Scripts/IndoorArSpike.cs.meta
```

- [ ] **Step 3: Update `BuildScene`** in `Editor/IndoorArSetup.cs`. Replace

```csharp
            var spike = new GameObject("IndoorArSpike");
            spike.AddComponent<IndoorArSpike>();
```

with

```csharp
            var runner = new GameObject("IndoorArRunner");
            var localizer = runner.AddComponent<MultiSetLocalizer>();
            AddMultiSet(runner, localizer);
            runner.AddComponent<IndoorArRunner>().Configure(
                localizer,
                AssetDatabase.LoadAssetAtPath<GameObject>("Assets/IndoorNavigation/Prefabs/DoorMarker.prefab"),
                Camera.main);
```

and add a `static void AddMultiSet(GameObject host, MultiSetLocalizer localizer)` that creates exactly the SDK objects the A6 Step 2 sample scene uses for MapSet localization (manager component and `Map Space`), wired to `localizer`. Add `using UnityEditor;` if missing. If `Camera.main` is null after the XR Origin menu item, find the camera under the XR Origin instead and say so in the report. If `MultiSetLocalizer` lives outside the asmdef (A6 Step 4), `IndoorAr.Editor` cannot see it either: move this wiring into an editor script next to it, outside any asmdef.

- [ ] **Step 4: Rebuild the scene and run all tests**

```bash
"$UNITY" -batchmode -projectPath /Users/kaydee/Developer/Navipet/NaviPetUnity \
  -executeMethod IndoorAr.Editor.IndoorArSetup.Configure -logFile - | grep "\[IndoorAr\]"
```

(Use the namespace-qualified name the file actually declares.) Expected log: scene roots include `AR Session`, `XR Origin (Mobile AR)`, `IndoorArRunner` and the MultiSet objects. Then run all EditMode tests: all pass, except mesh-check failures already reported in A5.

- [ ] **Step 5: Editor smoke.** Play the scene in the editor (`IndoorArBridge.EditorRequestJson` is VEC119). Expected: status text "Starting AR…" or "Connecting to MultiSet…"; Exit delivers `cancelled` (the editor logs the result instead of an activity). If credentials are not in yet, auth fails with `MULTISET_AUTH` or `NETWORK`, which also proves the error path.

- [ ] **Step 6: Commit**

```bash
git add -A Assets/IndoorAr
git status --short | grep -i MultiSetConfig && echo "STOP: config staged" || echo "ok"
git commit -m "feat(indoor-ar): door pin runner with HUD replaces the transport spike"
```

- [ ] **Step 7: Build the AAR** (needs "credentials in" from A2 Step 4):

```bash
/Users/kaydee/Developer/Navipet/NaviPetUnity/tools/build-indoor-ar-aar.sh /Users/kaydee/Developer/Navipet/NaviPetFlutter/android/unity-ar
```

Expected: script succeeds; `android/unity-ar/` stays gitignored in NaviPetFlutter (`git -C /Users/kaydee/Developer/Navipet/NaviPetFlutter status --short` shows nothing under `android/unity-ar`).

- [ ] **Step 8: Secret scan, then report.** Run on the branch diff:

```bash
git diff feat/indoor-ar-transport-spike...HEAD | grep -inE "secret|client_?id|clientSecret|apikey|api_key|bearer" || echo "no hits"
```

Any hit that is not a field name: stop and report. Then send `lead-engineer`: `DONE Part A: branch feat/indoor-ar-door-verifier, <n> commits, EditMode <passed>/<total>, mesh check <17/17 or failing keys>, SDK <name>@<tag>, AAR built at NaviPetFlutter/android/unity-ar. Not pushed.`

---

## Part B — NavipetBackend (no change)

Verified by `project-manager` on 2026-10-28, no worker task:
- `/places/:placeId` returns `place.indoor` = `{ mapCode, frame: 'multiset-mapset', doorKey, floor, position: { x, y, z }, headingDeg }` (`src/modules/campus/campus.schema.ts` `IndoorDoorPoseSchema`), which maps one to one onto `IndoorArRequest` except `room`, taken from `place.roomNumber`.
- `findPlaceDetail` adds `indoor` only when `navigation.indoorDestinationId` is set; `destination_provider_refs` / `vec_destination_points.point_key` supply it.
- All 17 door `destination_id`s are `campus_destinations` rows with `type = room`, `active = true`, `searchable = true`.

---

## Part C — NaviPetFlutter (worker: `flutter`)

**Start condition:** PR #44 (`rad_check`) is merged into `main`. Until then, do nothing in Part C. `lead-engineer` tells `flutter` when to start.

- [ ] **Setup**

```bash
cd /Users/kaydee/Developer/Navipet/NaviPetFlutter
git fetch origin && git switch main && git pull --ff-only
git switch -c feat/indoor-ar-launch
flutter pub get
```

Run tests: `flutter test <file>`; Kotlin: `cd android && ./gradlew :app:testDebugUnitTest --tests '<Class>'`.

### Task C1: Parse the `indoor` pose into `CampusPlace.indoorRequest`

**Files:**
- Modify: `lib/data/indoor_ar_contract.dart`, `lib/data/campus_place.dart`
- Test: `test/indoor_ar_contract_test.dart`, `test/campus_place_test.dart`

**Interfaces:**
- Produces: `static IndoorArRequest? IndoorArRequest.fromDoorPose(Object? json, {required String room})`; `CampusPlace.indoorRequest` (`IndoorArRequest?`).

- [ ] **Step 1: GitNexus impact** on `IndoorArRequest` and `CampusPlace` (upstream). Report risk in your final message; stop and tell the lead if HIGH/CRITICAL.

- [ ] **Step 2: Write the failing tests.** Add to `test/indoor_ar_contract_test.dart` (inside `main`):

```dart
  group('IndoorArRequest.fromDoorPose', () {
    Map<String, dynamic> pose({Object? headingDeg = 185.36}) => {
      'mapCode': 'MSET_XTBY7AM7ZK77',
      'frame': 'multiset-mapset',
      'doorKey': 'VEC119',
      'floor': '1',
      'position': {'x': -5.7651, 'y': -1.8186, 'z': 22.6689},
      'headingDeg': headingDeg,
    };

    test('builds the v1 request from the backend door pose', () {
      final request = IndoorArRequest.fromDoorPose(pose(), room: '119')!;
      expect(request.toJson(), vec119Request().toJson());
    });

    test('accepts integer coordinates', () {
      final json = pose(headingDeg: 5)..['position'] = {'x': 1, 'y': 2, 'z': 3};
      final request = IndoorArRequest.fromDoorPose(json, room: '1')!;
      expect(request.position.x, 1.0);
      expect(request.headingDeg, 5.0);
    });

    test('returns null for a missing or invalid pose', () {
      expect(IndoorArRequest.fromDoorPose(null, room: '119'), isNull);
      expect(IndoorArRequest.fromDoorPose(pose(headingDeg: 360), room: '119'), isNull);
      expect(IndoorArRequest.fromDoorPose(pose(headingDeg: 'x'), room: '119'), isNull);
      expect(
        IndoorArRequest.fromDoorPose(pose()..remove('position'), room: '119'),
        isNull,
      );
      expect(
        IndoorArRequest.fromDoorPose(pose()..['doorKey'] = '', room: '119'),
        isNull,
      );
    });
  });
```

Add `import 'support/indoor_ar_fixtures.dart';` if the file lacks it. Add to `test/campus_place_test.dart` (inside `main`; reuse the file's existing minimal place JSON if it has one, else this):

```dart
  test('parses the indoor door pose into an AR request', () {
    final place = CampusPlace.fromJson({
      'id': '3c011e42-ad7d-4f6c-81d5-e7b23e977d1f',
      'type': 'room',
      'title': 'VEC 119',
      'subtitle': 'VEC',
      'source': 'csulb',
      'roomNumber': '119',
      'indoor': {
        'mapCode': 'MSET_XTBY7AM7ZK77',
        'frame': 'multiset-mapset',
        'doorKey': 'VEC119',
        'floor': '1',
        'position': {'x': -5.7651, 'y': -1.8186, 'z': 22.6689},
        'headingDeg': 185.36,
      },
    });
    expect(place.indoorRequest?.toJson(), vec119Request().toJson());
  });

  test('has no AR request without an indoor pose', () {
    final place = CampusPlace.fromJson({
      'id': 'x',
      'type': 'room',
      'title': 'VEC 119',
      'subtitle': 'VEC',
      'source': 'csulb',
    });
    expect(place.indoorRequest, isNull);
  });
```

with `import 'support/indoor_ar_fixtures.dart';`.

- [ ] **Step 3: Run, expect FAIL**: `flutter test test/indoor_ar_contract_test.dart test/campus_place_test.dart` → `fromDoorPose` / `indoorRequest` not defined.

- [ ] **Step 4: Implement.** In `IndoorArRequest` (after the constructor):

```dart
  /// Builds a request from the `indoor` door pose on `/places/:placeId`.
  /// Null when the pose is missing or fails this class's validation.
  static IndoorArRequest? fromDoorPose(Object? json, {required String room}) {
    if (json is! Map<String, dynamic>) return null;
    final position = json['position'];
    if (position is! Map<String, dynamic>) return null;
    final (x, y, z) = (position['x'], position['y'], position['z']);
    final heading = json['headingDeg'];
    final (doorKey, floor) = (json['doorKey'], json['floor']);
    final (mapCode, frame) = (json['mapCode'], json['frame']);
    if (x is! num || y is! num || z is! num || heading is! num) return null;
    if (doorKey is! String || floor is! String) return null;
    if (mapCode is! String || frame is! String) return null;
    try {
      return IndoorArRequest(
        room: room,
        doorKey: doorKey,
        floor: floor,
        position: IndoorArVector3(x.toDouble(), y.toDouble(), z.toDouble()),
        headingDeg: heading.toDouble(),
        mapCode: mapCode,
        frame: frame,
      );
    } on ArgumentError {
      return null;
    }
  }
```

In `CampusPlace`: add `this.indoorRequest,` to the constructor, `final IndoorArRequest? indoorRequest;` to the fields, the import `import 'indoor_ar_contract.dart';`, and in `fromJson`:

```dart
      indoorRequest: IndoorArRequest.fromDoorPose(
        json['indoor'],
        room: _optionalString(json['roomNumber']) ?? '',
      ),
```

- [ ] **Step 5: Run, expect PASS**, then `flutter analyze`.

- [ ] **Step 6: `detect_changes`, commit**

```bash
git add lib/data/indoor_ar_contract.dart lib/data/campus_place.dart test/indoor_ar_contract_test.dart test/campus_place_test.dart
git commit -m "feat(indoor-ar): parse the place's indoor door pose into an AR request"
```

### Task C2: Keep a result that arrives with no Dart call waiting

**Files:**
- Create: `android/app/src/main/kotlin/com/navipet/navipet/IndoorArResultSlot.kt`, `android/app/src/test/kotlin/com/navipet/navipet/IndoorArResultSlotTest.kt`
- Modify: `android/app/src/main/kotlin/com/navipet/navipet/IndoorArChannel.kt`, `lib/data/indoor_ar_launcher.dart`
- Test: `test/indoor_ar_launcher_test.dart`

**Interfaces:**
- Produces: channel method `pendingResult` → result JSON string or `null`; Dart `Future<IndoorArResult?> IndoorArLauncher.pendingResult()`; `FakeIndoorArLauncher.pending` (`IndoorArResult?`, returned once).

Why: when Android recreates `MainActivity` while Unity runs, the Dart call that launched AR is gone, and today `onActivityResult` drops the result (`pending ?: return true`).

- [ ] **Step 1: GitNexus impact** on `IndoorArChannel`, `IndoorArLauncher`, `AndroidIndoorArLauncher`, `FakeIndoorArLauncher`.

- [ ] **Step 2: Failing Kotlin test** — `IndoorArResultSlotTest.kt`:

```kotlin
package com.navipet.navipet

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class IndoorArResultSlotTest {
    @Test
    fun returnsAHeldResultOnce() {
        val slot = IndoorArResultSlot()
        slot.put("""{"status":"cancelled","localizationQueries":0,"durationMs":5}""")
        assertEquals("""{"status":"cancelled","localizationQueries":0,"durationMs":5}""", slot.take())
        assertNull(slot.take())
    }

    @Test
    fun isEmptyByDefault() {
        assertNull(IndoorArResultSlot().take())
    }
}
```

Run: `cd android && ./gradlew :app:testDebugUnitTest --tests 'com.navipet.navipet.IndoorArResultSlotTest'` → FAIL (unresolved reference).

- [ ] **Step 3: Implement** — `IndoorArResultSlot.kt`:

```kotlin
package com.navipet.navipet

/** Holds a result that came back with no Dart call waiting, until Dart takes it once. */
class IndoorArResultSlot {
    private var held: String? = null

    fun put(json: String) {
        held = json
    }

    fun take(): String? = held.also { held = null }
}
```

In `IndoorArChannel.kt`: add the field `private val unclaimed = IndoorArResultSlot()`. In `onMethodCall`, replace

```kotlin
        if (call.method != "launch") {
            result.notImplemented()
            return
        }
```

with

```kotlin
        if (call.method == "pendingResult") {
            result.success(unclaimed.take())
            return
        }
        if (call.method != "launch") {
            result.notImplemented()
            return
        }
```

Replace the body of `onActivityResult` after the request-code check with:

```kotlin
        // startedAt is 0 in an activity recreated while Unity ran.
        val durationMs = if (startedAt == 0L) 0L else SystemClock.elapsedRealtime() - startedAt
        val json = IndoorArResults.fromActivityResult(
            data?.getStringExtra(IndoorArResults.RESULT_EXTRA),
            durationMs,
        )
        val result = pending
        if (result == null) {
            unclaimed.put(json)
        } else {
            pending = null
            result.success(json)
        }
        return true
```

Run the Kotlin tests (`IndoorArResultSlotTest` and `IndoorArResultsTest`) → PASS.

- [ ] **Step 4: Failing Dart test.** Add to `test/indoor_ar_launcher_test.dart`:

```dart
  test('pendingResult decodes a held result', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'pendingResult');
      return '{"status":"arrived","checkDistanceM":0.8,"localizationQueries":3,"durationMs":41000}';
    });
    final result = await AndroidIndoorArLauncher(isAndroid: true).pendingResult();
    expect(result?.status, IndoorArStatus.arrived);
    expect(result?.checkDistanceM, 0.8);
  });

  test('pendingResult is null when nothing is held or there is no host', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => null);
    expect(await AndroidIndoorArLauncher(isAndroid: true).pendingResult(), isNull);
    messenger.setMockMethodCallHandler(channel, null);
    expect(await AndroidIndoorArLauncher(isAndroid: true).pendingResult(), isNull);
    expect(await AndroidIndoorArLauncher(isAndroid: false).pendingResult(), isNull);
  });

  test('the fake returns its pending result once', () async {
    final fake = FakeIndoorArLauncher()
      ..pending = const IndoorArResult(
        status: IndoorArStatus.cancelled,
        localizationQueries: 0,
        durationMs: 1,
      );
    expect((await fake.pendingResult())?.status, IndoorArStatus.cancelled);
    expect(await fake.pendingResult(), isNull);
  });
```

Run → FAIL (`pendingResult` not defined).

- [ ] **Step 5: Implement in `indoor_ar_launcher.dart`.** Interface:

```dart
abstract interface class IndoorArLauncher {
  Future<IndoorArResult> launch(IndoorArRequest request);

  /// A result that came back after the app's activity was recreated, so no
  /// [launch] call was waiting for it. Null when there is none. Returns it once.
  Future<IndoorArResult?> pendingResult();
}
```

`AndroidIndoorArLauncher`:

```dart
  @override
  Future<IndoorArResult?> pendingResult() async {
    if (!_isAndroid) return null;
    final Object? raw;
    try {
      raw = await _channel.invokeMethod<Object?>('pendingResult');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
    return raw is String ? IndoorArResult.decode(raw) : null;
  }
```

`FakeIndoorArLauncher`:

```dart
  IndoorArResult? pending;

  @override
  Future<IndoorArResult?> pendingResult() async {
    final result = pending;
    pending = null;
    return result;
  }
```

Run `flutter test test/indoor_ar_launcher_test.dart` → PASS. `flutter analyze`.

- [ ] **Step 6: `detect_changes`, commit**

```bash
git add android/app/src/main/kotlin/com/navipet/navipet/IndoorArResultSlot.kt android/app/src/main/kotlin/com/navipet/navipet/IndoorArChannel.kt android/app/src/test/kotlin/com/navipet/navipet/IndoorArResultSlotTest.kt lib/data/indoor_ar_launcher.dart test/indoor_ar_launcher_test.dart
git commit -m "fix(indoor-ar): keep an AR result that returns to a recreated activity"
```

### Task C3: `IndoorArLaunchScreen`

**Files:**
- Create: `lib/screens/indoor_ar_launch_screen.dart`, `test/indoor_ar_launch_screen_test.dart`
- Modify: `android/app/src/main/AndroidManifest.xml`

**Interfaces:**
- Consumes: `CampusPlace.indoorRequest` (C1), `IndoorArLauncher` (C2), `CampusSearchGateway.place(String)`, `NavigationFlowController.searchGateway` (provided by `MultiProvider` in `lib/main.dart`).
- Produces: `IndoorArLaunchScreen({required String destinationId, required IndoorArLauncher launcher, CampusSearchGateway? gateway, Future<PermissionStatus> Function() requestCamera})`.

Behaviour (spec "Flutter IndoorArLaunchScreen"): load the place → "Start AR" → camera permission (Android only) → launch → result text on the screen. Copy, exactly:

| Case | Text |
|---|---|
| empty `destinationId` or no `indoor` | `Indoor AR isn't available for this room` |
| place load failed | `Couldn't load this room.` + button `Retry` |
| camera denied | `NaviPet needs the camera to show the door pin.` + button `Try again` |
| camera permanently denied | same text + button `Open settings` |
| `arrived` | `Pin was X.X m from you` |
| `localizationFailed` | `Couldn't find your position` (start button reads `Retry`) |
| `cancelled` | no text |
| `unavailable` | `AR not included in this build` |
| `error` | per code: `ARCORE_UNSUPPORTED` `This phone doesn't support AR.`; `MULTISET_AUTH` `Couldn't connect to the indoor map service.`; `NETWORK` `No internet connection. Check it and try again.`; `UNITY_EXITED` `AR closed unexpectedly.`; `BAD_REQUEST` `This room's AR data is invalid.`; `MAP_MISMATCH` `This room's AR data is for a different map.`; `BAD_RESULT` `AR returned an unreadable result.`; any other `AR failed (<code>)` |

- [ ] **Step 1: Write the failing widget tests** — `test/indoor_ar_launch_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navipet/data/campus_place.dart';
import 'package:navipet/data/indoor_ar_contract.dart';
import 'package:navipet/data/indoor_ar_launcher.dart';
import 'package:navipet/screens/indoor_ar_launch_screen.dart';
import 'package:permission_handler/permission_handler.dart';

import 'support/flow_fakes.dart';

const _vec119Id = '3c011e42-ad7d-4f6c-81d5-e7b23e977d1f';

CampusPlace _vec119({bool indoor = true}) => CampusPlace.fromJson({
  'id': _vec119Id,
  'type': 'room',
  'title': 'VEC 119',
  'subtitle': 'VEC',
  'source': 'csulb',
  'roomNumber': '119',
  if (indoor)
    'indoor': {
      'mapCode': 'MSET_XTBY7AM7ZK77',
      'frame': 'multiset-mapset',
      'doorKey': 'VEC119',
      'floor': '1',
      'position': {'x': -5.7651, 'y': -1.8186, 'z': 22.6689},
      'headingDeg': 185.36,
    },
});

Future<FakeIndoorArLauncher> _pump(
  WidgetTester tester, {
  String id = _vec119Id,
  List<CampusPlace>? places,
  PermissionStatus camera = PermissionStatus.granted,
  IndoorArResult? result,
}) async {
  final launcher = FakeIndoorArLauncher(
    result: result ?? const IndoorArResult.unavailable(),
  );
  final gateway = FakeSearchGateway()..results = places ?? [_vec119()];
  await tester.pumpWidget(
    MaterialApp(
      home: IndoorArLaunchScreen(
        destinationId: id,
        launcher: launcher,
        gateway: gateway,
        requestCamera: () async => camera,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return launcher;
}

IndoorArResult _error(String code) => IndoorArResult(
  status: IndoorArStatus.error,
  errorCode: code,
  localizationQueries: 0,
  durationMs: 1,
);

void main() {
  testWidgets('launches the loaded door and shows the distance', (tester) async {
    final launcher = await _pump(
      tester,
      result: const IndoorArResult(
        status: IndoorArStatus.arrived,
        checkDistanceM: 0.84,
        localizationQueries: 2,
        durationMs: 30000,
      ),
    );
    expect(find.text('VEC 119'), findsOneWidget);
    await tester.tap(find.text('Start AR'));
    await tester.pumpAndSettle();
    expect(launcher.requests.single.doorKey, 'VEC119');
    expect(find.text('Pin was 0.8 m from you'), findsOneWidget);
  });

  testWidgets('a room without an indoor pose cannot start AR', (tester) async {
    await _pump(tester, places: [_vec119(indoor: false)]);
    expect(find.text("Indoor AR isn't available for this room"), findsOneWidget);
    expect(find.text('Start AR'), findsNothing);
  });

  testWidgets('an empty destination id cannot start AR', (tester) async {
    await _pump(tester, id: '');
    expect(find.text("Indoor AR isn't available for this room"), findsOneWidget);
  });

  testWidgets('a failed place load offers Retry', (tester) async {
    await _pump(tester, places: const []);
    expect(find.text("Couldn't load this room."), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('denied camera does not launch', (tester) async {
    final launcher = await _pump(tester, camera: PermissionStatus.denied);
    await tester.tap(find.text('Start AR'));
    await tester.pumpAndSettle();
    expect(launcher.requests, isEmpty);
    expect(find.text('NaviPet needs the camera to show the door pin.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('permanently denied camera offers settings', (tester) async {
    await _pump(tester, camera: PermissionStatus.permanentlyDenied);
    await tester.tap(find.text('Start AR'));
    await tester.pumpAndSettle();
    expect(find.text('Open settings'), findsOneWidget);
  });

  testWidgets('localization failure offers Retry', (tester) async {
    await _pump(
      tester,
      result: const IndoorArResult(
        status: IndoorArStatus.localizationFailed,
        localizationQueries: 6,
        durationMs: 60000,
      ),
    );
    await tester.tap(find.text('Start AR'));
    await tester.pumpAndSettle();
    expect(find.text("Couldn't find your position"), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('cancelled shows nothing, unavailable explains', (tester) async {
    final launcher = await _pump(
      tester,
      result: const IndoorArResult(
        status: IndoorArStatus.cancelled,
        localizationQueries: 0,
        durationMs: 1,
      ),
    );
    await tester.tap(find.text('Start AR'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Pin was'), findsNothing);
    expect(find.text('Start AR'), findsOneWidget);

    launcher.result = const IndoorArResult.unavailable();
    await tester.tap(find.text('Start AR'));
    await tester.pumpAndSettle();
    expect(find.text('AR not included in this build'), findsOneWidget);
  });

  for (final (code, text) in [
    ('ARCORE_UNSUPPORTED', "This phone doesn't support AR."),
    ('MULTISET_AUTH', "Couldn't connect to the indoor map service."),
    ('NETWORK', 'No internet connection. Check it and try again.'),
    ('UNITY_EXITED', 'AR closed unexpectedly.'),
    ('BAD_REQUEST', "This room's AR data is invalid."),
    ('MAP_MISMATCH', "This room's AR data is for a different map."),
    ('BAD_RESULT', 'AR returned an unreadable result.'),
    ('SOMETHING_NEW', 'AR failed (SOMETHING_NEW)'),
  ]) {
    testWidgets('error $code has its own message', (tester) async {
      await _pump(tester, result: _error(code));
      await tester.tap(find.text('Start AR'));
      await tester.pumpAndSettle();
      expect(find.text(text), findsOneWidget);
    });
  }
}
```

Also add to `test/indoor_ar_contract_test.dart`:

```dart
  test('decodes MAP_MISMATCH and unknown error codes as error', () {
    for (final code in ['MAP_MISMATCH', 'SOMETHING_NEW']) {
      final result = IndoorArResult.decode(
        '{"status":"error","errorCode":"$code","localizationQueries":0,"durationMs":1}',
      );
      expect(result.status, IndoorArStatus.error);
      expect(result.errorCode, code);
    }
  });
```

Run `flutter test test/indoor_ar_launch_screen_test.dart` → FAIL (screen missing). The contract test passes already (decode accepts any non-empty code); keep it as the spec's regression test.

- [ ] **Step 2: Implement** — `lib/screens/indoor_ar_launch_screen.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../data/campus_place.dart';
import '../data/campus_search_gateway.dart';
import '../data/indoor_ar_contract.dart';
import '../data/indoor_ar_launcher.dart';
import '../data/navigation_flow_controller.dart';

enum _Phase { loading, loadFailed, unavailable, ready, running, cameraDenied, cameraBlocked }

/// Opens indoor AR for one room: loads its door pose, asks for the camera,
/// launches Unity and shows what came back.
class IndoorArLaunchScreen extends StatefulWidget {
  const IndoorArLaunchScreen({
    super.key,
    required this.destinationId,
    required this.launcher,
    this.gateway,
    this.requestCamera = _requestCamera,
  });

  final String destinationId;
  final IndoorArLauncher launcher;

  /// Null: the app's [NavigationFlowController.searchGateway].
  final CampusSearchGateway? gateway;
  final Future<PermissionStatus> Function() requestCamera;

  static Future<PermissionStatus> _requestCamera() => Permission.camera.request();

  @override
  State<IndoorArLaunchScreen> createState() => _IndoorArLaunchScreenState();
}

class _IndoorArLaunchScreenState extends State<IndoorArLaunchScreen> {
  static const _errorText = {
    'ARCORE_UNSUPPORTED': "This phone doesn't support AR.",
    'MULTISET_AUTH': "Couldn't connect to the indoor map service.",
    'NETWORK': 'No internet connection. Check it and try again.',
    'UNITY_EXITED': 'AR closed unexpectedly.',
    'BAD_REQUEST': "This room's AR data is invalid.",
    'MAP_MISMATCH': "This room's AR data is for a different map.",
    'BAD_RESULT': 'AR returned an unreadable result.',
  };

  late final CampusSearchGateway _gateway =
      widget.gateway ?? context.read<NavigationFlowController>().searchGateway;
  var _phase = _Phase.loading;
  CampusPlace? _place;
  IndoorArResult? _last;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.destinationId.isEmpty) {
      setState(() => _phase = _Phase.unavailable);
      return;
    }
    setState(() => _phase = _Phase.loading);
    try {
      final place = await _gateway.place(widget.destinationId);
      if (!mounted) return;
      setState(() {
        _place = place;
        _phase = place.indoorRequest == null ? _Phase.unavailable : _Phase.ready;
      });
    } catch (_) {
      if (mounted) setState(() => _phase = _Phase.loadFailed);
    }
  }

  Future<void> _start() async {
    final request = _place!.indoorRequest!;
    if (defaultTargetPlatform == TargetPlatform.android) {
      final camera = await widget.requestCamera();
      if (!mounted) return;
      if (!camera.isGranted) {
        setState(
          () => _phase = camera.isPermanentlyDenied
              ? _Phase.cameraBlocked
              : _Phase.cameraDenied,
        );
        return;
      }
    }
    setState(() => _phase = _Phase.running);
    try {
      final result = await widget.launcher.launch(request);
      debugPrint(
        '[IndoorAr] ${request.doorKey} ${result.status.name} '
        'distance=${result.checkDistanceM} confidence=${result.confidence} '
        'queries=${result.localizationQueries} durationMs=${result.durationMs} '
        'error=${result.errorCode}',
      );
      if (mounted) setState(() => _last = result);
    } finally {
      // A throwing launcher must not leave the button disabled.
      if (mounted) setState(() => _phase = _Phase.ready);
    }
  }

  String? _resultText(IndoorArResult result) => switch (result.status) {
    IndoorArStatus.arrived =>
      'Pin was ${result.checkDistanceM?.toStringAsFixed(1)} m from you',
    IndoorArStatus.localizationFailed => "Couldn't find your position",
    IndoorArStatus.cancelled => null,
    IndoorArStatus.unavailable => 'AR not included in this build',
    IndoorArStatus.error =>
      _errorText[result.errorCode] ?? 'AR failed (${result.errorCode})',
  };

  @override
  Widget build(BuildContext context) {
    final place = _place;
    final last = _last;
    final resultText = last == null ? null : _resultText(last);
    return Scaffold(
      appBar: AppBar(title: const Text('Indoor AR')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (place != null)
            Text(place.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          ...switch (_phase) {
            _Phase.loading => [const Center(child: CircularProgressIndicator())],
            _Phase.loadFailed => [
              const Text("Couldn't load this room."),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
            _Phase.unavailable => [
              const Text("Indoor AR isn't available for this room"),
            ],
            _Phase.cameraDenied => [
              const Text('NaviPet needs the camera to show the door pin.'),
              FilledButton(onPressed: _start, child: const Text('Try again')),
            ],
            _Phase.cameraBlocked => [
              const Text('NaviPet needs the camera to show the door pin.'),
              FilledButton(
                onPressed: openAppSettings,
                child: const Text('Open settings'),
              ),
            ],
            _Phase.ready || _Phase.running => [
              if (resultText != null) Text(resultText),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _phase == _Phase.running ? null : _start,
                child: Text(
                  last?.status == IndoorArStatus.localizationFailed
                      ? 'Retry'
                      : 'Start AR',
                ),
              ),
            ],
          },
        ],
      ),
    );
  }
}
```

Note: the "cancelled shows nothing" test taps `Start AR` a second time after a cancelled result, so the button label must stay `Start AR` after `cancelled` — it does (`Retry` only after `localizationFailed`).

- [ ] **Step 3: Camera permission in the manifest.** In `android/app/src/main/AndroidManifest.xml`, next to the other `<uses-permission>` lines:

```xml
    <!-- Indoor AR. Declared here so permission_handler can ask for it in builds without the Unity library too. -->
    <uses-permission android:name="android.permission.CAMERA" />
```

- [ ] **Step 4: Run, expect PASS**: `flutter test test/indoor_ar_launch_screen_test.dart test/indoor_ar_contract_test.dart`; `flutter analyze`. If `flutter analyze` flags `catch (_)`, use `on Object catch (_)` and keep the behaviour.

- [ ] **Step 5: `detect_changes`, commit**

```bash
git add lib/screens/indoor_ar_launch_screen.dart test/indoor_ar_launch_screen_test.dart test/indoor_ar_contract_test.dart android/app/src/main/AndroidManifest.xml
git commit -m "feat(indoor-ar): add the launch screen with camera permission and result messages"
```

### Task C4: `/ar?destinationId=` builds the launch screen

**Files:**
- Modify: `lib/router/app_router.dart`
- Delete: `lib/screens/ar_navigation_screen.dart`
- Test: `test/app_router_test.dart`

- [ ] **Step 1: GitNexus impact** on `ArNavigationScreen` and `createAppRouter`. Expected: only `app_router.dart` uses `ArNavigationScreen`. Anything else: stop and tell the lead.

- [ ] **Step 2: Failing test.** Add to `test/app_router_test.dart`, copying the setup the existing `/dev/indoor-ar-spike` test there uses (same `AppState`, providers and `initialLocation` pattern):

```dart
  testWidgets('/ar builds the indoor AR launch screen', (tester) async {
    // same setup as the '/dev/indoor-ar-spike' test above, with
    // initialLocation: '/ar' (no destinationId, so no network call)
    await tester.pumpAndSettle();
    expect(find.byType(IndoorArLaunchScreen), findsOneWidget);
    expect(find.text("Indoor AR isn't available for this room"), findsOneWidget);
  });
```

Write the setup out in full in the test (do not leave the comment). Import `package:navipet/screens/indoor_ar_launch_screen.dart`. Run → FAIL.

- [ ] **Step 3: Implement.** In `app_router.dart` replace

```dart
    GoRoute(
      path: '/ar',
      builder: (context, state) => const ArNavigationScreen(),
    ),
```

with

```dart
    GoRoute(
      path: '/ar',
      builder: (context, state) => IndoorArLaunchScreen(
        destinationId: state.uri.queryParameters['destinationId'] ?? '',
        launcher: AndroidIndoorArLauncher(),
      ),
    ),
```

Replace `import '../screens/ar_navigation_screen.dart';` with `import '../screens/indoor_ar_launch_screen.dart';`. Delete the mockup: `git rm lib/screens/ar_navigation_screen.dart`. Then `grep -rn "ar_navigation_screen\|ArNavigationScreen" lib test` → no hits. Check `pubspec.yaml` assets the mockup alone used; leave assets in place and list them in your report.

- [ ] **Step 4: Run, expect PASS**: `flutter test test/app_router_test.dart`; `flutter analyze`.

- [ ] **Step 5: `detect_changes`, commit**

```bash
git add lib/router/app_router.dart test/app_router_test.dart
git commit -m "feat(indoor-ar): route /ar?destinationId= to the launch screen"
```

### Task C5: VEC room picker and recovered result on `/dev/indoor-ar-spike`

**Files:**
- Modify: `lib/screens/indoor_ar_spike_screen.dart`
- Test: `test/indoor_ar_spike_screen_test.dart` (rewrite)

**Interfaces:**
- Consumes: `IndoorArLauncher.pendingResult()` (C2), route `/ar?destinationId=` (C4).
- Produces: `IndoorArSpikeScreen.doors` (`List<(String, String)>`: door key, campus destination id).

Device-check builds start on this route (`--dart-define=NAVIPET_DEV_ROUTE=/dev/indoor-ar-spike`, see `lib/main.dart`), so after Android restarts the app the picker is the screen that comes back; it collects the held result.

- [ ] **Step 1: Rewrite the test** — `test/indoor_ar_spike_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:navipet/data/indoor_ar_contract.dart';
import 'package:navipet/data/indoor_ar_launcher.dart';
import 'package:navipet/screens/indoor_ar_spike_screen.dart';

Future<List<String>> _pump(WidgetTester tester, FakeIndoorArLauncher launcher) async {
  final opened = <String>[];
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => IndoorArSpikeScreen(launcher: launcher)),
      GoRoute(
        path: '/ar',
        builder: (_, state) {
          opened.add(state.uri.queryParameters['destinationId']!);
          return const Text('ar');
        },
      ),
    ],
  );
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
  return opened;
}

void main() {
  test('lists the 17 VEC floor 1–2 doors', () {
    expect(IndoorArSpikeScreen.doors, hasLength(17));
    expect(IndoorArSpikeScreen.doors.first,
        ('VEC119', '3c011e42-ad7d-4f6c-81d5-e7b23e977d1f'));
  });

  testWidgets('tapping a room opens AR for its destination', (tester) async {
    final opened = await _pump(tester, FakeIndoorArLauncher());
    await tester.tap(find.text('VEC119'));
    await tester.pumpAndSettle();
    expect(opened, ['3c011e42-ad7d-4f6c-81d5-e7b23e977d1f']);
  });

  testWidgets('shows a result recovered after a restart', (tester) async {
    final launcher = FakeIndoorArLauncher()
      ..pending = const IndoorArResult(
        status: IndoorArStatus.arrived,
        checkDistanceM: 0.5,
        localizationQueries: 2,
        durationMs: 4200,
      );
    await _pump(tester, launcher);
    expect(find.text('Recovered result: arrived, 0.50 m'), findsOneWidget);
  });
}
```

Run → FAIL.

- [ ] **Step 2: Implement** — replace the whole of `lib/screens/indoor_ar_spike_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/indoor_ar_contract.dart';
import '../data/indoor_ar_launcher.dart';

/// Debug-only VEC room picker for the door verifier device check: opens
/// `/ar?destinationId=` for one room without walking the outdoor route, and
/// shows a result that came back after Android restarted the app.
class IndoorArSpikeScreen extends StatefulWidget {
  const IndoorArSpikeScreen({super.key, required this.launcher});

  final IndoorArLauncher launcher;

  /// Active doors in vec_destination_points (floors 1–2), with their
  /// campus_destinations id, as of 2026-10-28.
  static const doors = <(String, String)>[
    ('VEC119', '3c011e42-ad7d-4f6c-81d5-e7b23e977d1f'),
    ('VEC120', '4be3965d-e8a9-44c7-b537-130030247b73'),
    ('VEC121', '9e0e4f69-489c-4878-9c6a-13088099439c'),
    ('VEC124', '0cbbd702-e0d9-4954-8041-b7b9adde130c'),
    ('VEC127', 'd217f392-7b76-4144-9561-847880aec2e8'),
    ('VEC128', '48946840-9bbc-4d43-b81e-1eb2d916e3c9'),
    ('VEC132', 'acae6c09-b287-4be4-b88d-f19bb1640c4b'),
    ('VEC134', '7d538d16-0216-4ca6-bdb2-60db49cb011c'),
    ('VEC136', '8bd597c1-4cf9-4805-9e0c-34db7dec69a9'),
    ('VEC201', '388d87e9-8d31-4e35-945d-14b32013e025'),
    ('VEC202', 'd1eea6ef-2abf-418b-a942-c32889649088'),
    ('VEC215', '630a1950-20e8-40a5-89a8-72ab00f131d2'),
    ('VEC217', 'da6fed01-a320-4613-987e-d972f318a65f'),
    ('VEC218', '3139ee48-32b3-4159-ad1e-61b91fe852db'),
    ('VEC220', '1f859c36-4962-4eb9-94cb-e0d6422fe5ba'),
    ('VEC224', 'e3ba922a-d968-4d61-833e-813913373c86'),
    ('VEC227', '9dd793bb-18fd-4321-bc75-fc68f11ea00e'),
  ];

  @override
  State<IndoorArSpikeScreen> createState() => _IndoorArSpikeScreenState();
}

class _IndoorArSpikeScreenState extends State<IndoorArSpikeScreen>
    with WidgetsBindingObserver {
  IndoorArResult? _recovered;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _collect();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Also on resume: the host may receive the result after Dart first asks.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _collect();
  }

  Future<void> _collect() async {
    final result = await widget.launcher.pendingResult();
    if (result == null || !mounted) return;
    debugPrint(
      '[IndoorAr] recovered ${result.status.name} '
      'distance=${result.checkDistanceM} confidence=${result.confidence} '
      'queries=${result.localizationQueries} durationMs=${result.durationMs} '
      'error=${result.errorCode}',
    );
    setState(() => _recovered = result);
  }

  @override
  Widget build(BuildContext context) {
    final recovered = _recovered;
    final distance = recovered?.checkDistanceM;
    return Scaffold(
      appBar: AppBar(title: const Text('Indoor AR rooms')),
      body: ListView(
        children: [
          if (recovered != null)
            ListTile(
              title: Text(
                'Recovered result: ${recovered.status.name}'
                '${distance == null ? '' : ', ${distance.toStringAsFixed(2)} m'}'
                '${recovered.errorCode == null ? '' : ', ${recovered.errorCode}'}',
              ),
            ),
          for (final (doorKey, destinationId) in IndoorArSpikeScreen.doors)
            ListTile(
              title: Text(doorKey),
              onTap: () => context.push(
                '/ar?destinationId=${Uri.encodeQueryComponent(destinationId)}',
              ),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Run, expect PASS**: `flutter test test/indoor_ar_spike_screen_test.dart test/app_router_test.dart`; `flutter analyze`. If the existing `/dev/indoor-ar-spike` router tests assert old spike text (`Request: VEC119…`), update them to `find.text('VEC119')`.

- [ ] **Step 4: `detect_changes`, commit**

```bash
git add lib/screens/indoor_ar_spike_screen.dart test/indoor_ar_spike_screen_test.dart test/app_router_test.dart
git commit -m "feat(indoor-ar): VEC room picker and recovered result on the dev route"
```

### Task C6: PR #44's AR button opens the arrived room

**Files:**
- Modify: `lib/screens/map_screen.dart` (the `FlowArrived` panel PR #44 added)
- Test: the test file that covers PR #44's `AR mode` button (`grep -rln "AR mode" test`); if none, `test/map_screen_flow_test.dart`

- [ ] **Step 1: GitNexus impact** on `_MapScreenState` build method for the arrived panel.

- [ ] **Step 2: Failing test** in the file from **Files**: in the arrived state with a destination whose `indoorDestinationId` is set, tapping `AR mode` pushes `/ar?destinationId=<destination.id>`; with no `indoorDestinationId`, `AR mode` is absent. Use the file's existing arrived-state setup and a `GoRouter` with an `/ar` route that records `state.uri.queryParameters['destinationId']`, as in C5's test.

- [ ] **Step 3: Implement.** Replace PR #44's

```dart
            OutlinedButton.icon(
              onPressed: () => context.push('/ar'),
              icon: const Icon(Icons.view_in_ar_outlined),
              label: const Text('AR mode'),
            ),
            const SizedBox(height: 8),
```

with

```dart
            if (state.destination.hasIndoorNavigation) ...[
              OutlinedButton.icon(
                onPressed: () => context.push(
                  '/ar?destinationId=${Uri.encodeQueryComponent(state.destination.id)}',
                ),
                icon: const Icon(Icons.view_in_ar_outlined),
                label: const Text('AR mode'),
              ),
              const SizedBox(height: 8),
            ],
```

(If the merged code differs from this, apply the same change to what merged and say so in the report.)

- [ ] **Step 4: Full suite**: `flutter test`, `flutter analyze`, `cd android && ./gradlew :app:testDebugUnitTest`. Then a debug build without the AAR: `flutter build apk --debug` with `android/unity-ar/` absent or moved aside **only if the lead approves moving it**; otherwise report that CI's `android-debug-build` covers it.

- [ ] **Step 5: `detect_changes`, commit, report**

```bash
git add lib/screens/map_screen.dart test/
git commit -m "feat(indoor-ar): open AR for the arrived room from the arrival panel"
```

Send `lead-engineer`: `DONE Part C: branch feat/indoor-ar-launch, <n> commits, flutter test <passed>/<total>, analyze clean, gradle unit tests pass, impact risks: <list>. Not pushed.`

---

## Part D — Review (worker: `qa`, report-only)

After Part A and after Part C, `lead-engineer` sends `qa` the branch and base. `qa` reads the full diff and reports to `lead-engineer` only:

- Every spec requirement in "Runtime flow" and "Testing" has code and a test (list gaps).
- Secrets: no MultiSet credential, token, or service-role key in the diff or in any log line; `MultiSetConfig.asset` untracked (`git ls-files | grep -i MultiSetConfig` empty).
- Unity: no SDK file edited; `IndoorArSession` transitions match the spec table; `Deliver` called exactly once per launch.
- Flutter: every result status and error code from the spec has its copy; no new dependency added.
- Answer format: one line per finding, `path:line: severity: problem. fix.` Then `VERDICT: ready / not ready`.

---

## Part E — Device check (humans; `lead-engineer` prepares, `project-manager` runs it with the user)

1. Build the APK with the AAR and the tester's credentials: `flutter build apk --debug --dart-define=NAVIPET_DEV_ROUTE=/dev/indoor-ar-spike` (plus the app's usual `--dart-define`s). Install on one ARCore phone. Team devices only.
2. In VEC: VEC127 and VEC128 (floor 1), VEC201 and VEC227 (floor 2): the farthest-apart pair in XZ per floor among doors that pass the mesh check (24.3 m and 45.6 m), so a yaw error shows as a distance-dependent miss. Three runs per door, launched from the picker, standing at the door when tapping "I'm here".
3. Pass: median `checkDistanceM` ≤ 1 m for each door.
   - Bonus, not a pass/fail gate: one or more runs at VEC119. It localizes → the cloud map covers the floor-1 west wing and the distance tests that pose. It fails to localize → the cloud map has no coverage there. Record either way.
4. Record per run: `checkDistanceM`, `confidence`, `localizationQueries`, `durationMs`, device model, Android version (from `adb logcat | grep "\[IndoorAr\]"`).
5. Failure cases once each: camera permission denied, network off, camera covered (localization failure), Exit mid-session.
6. Reading failures: same offset at every door = frame/origin error; pins mirrored across the corridor = handedness error; random scatter = localization quality.
7. Evidence (run table + screenshot or video) on issues #42, #47, #49 — posting needs the user's yes.

---

## Deviations from the spec (decided while planning)

- The result shows as text on the launch screen, not a bottom sheet: same copy, fewer moving parts, simpler tests.
- `pendingResult` is collected by the room picker (on start and on resume), not by the launch screen. When Android recreates `MainActivity`, the Flutter engine restarts at the initial route, so the launch screen never resumes; device-check builds start at the picker.
- PR #44's AR button shows only for rooms with indoor navigation.
- No `confidence` from Unity yet: the SDK's confidence value is unknown until A6 reads the SDK. If A6 finds one, `ar` reports it to the lead as a follow-up; the contract already carries `confidence`.
- Device-check doors: VEC127 replaces VEC119 on floor 1. The mesh check (A5) found no floor geometry in `floor 1 + 2.glb` under VEC119, 120, 121 and 124. Jomar's repo has no other mesh or door data for them (qa, read-only). VEC119 stays as a bonus run.
- MultiSet SDK pinned to commit `7791b41975823afe2d039a2c51a9ee2e5d8a51f6` (package version 1.9.3) on the vendor's `main`, not a release tag: 1.9.0 fails the Android AAR link on iOS-only native symbols, and the vendor never tagged 1.9.3. Do not move past this commit: a later commit (`8399fec`) changes map coordinates from global to local.
