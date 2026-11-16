# Android release camera verification

The app's release build loads `android/app/proguard-unity.pro`. It preserves
Unity Java classes and members, including
`com.unity3d.plugin.UnityAndroidPermissions`, plus `UnityHostActivity` and its
C#-called `deliverResult` method. Flutter's Gradle plugin still supplies its
default R8 configuration; shrinking remains enabled.

This addresses a possible cause of the reported release-only
`ClassNotFoundException`. It does not confirm the cause or prove live camera
works. R8 cannot infer all calls made by name from native code; see
[Android's keep-rule examples](https://developer.android.com/topic/performance/app-optimization/keep-rule-examples).

Flutter already checks `Permission.camera.status`, requests permission after
the rationale, and launches Unity only after access is granted. Denial shows
a message; permanent denial offers Settings. A Unity permission-plugin error
can therefore occur even after Flutter has obtained camera permission.

## Physical phone check

Use the existing private Unity export on the build owner's machine. Do not
upload or commit its AARs, credentials, or environment files.

1. Build the **release** APK with the Unity export present, retaining the
   API 26 minimum and arm64 configuration from the base branch.
2. Install on the Samsung arm64 phone. Reset camera permission through Android
   Settings, open AR, and allow access. Confirm a moving live camera image.
3. Repeat with permission already granted. Confirm live camera still opens.
4. Deny access and verify the message and return to the map. Permanently deny
   access and verify the Settings action; grant access there and retry AR.
5. Exit Unity and reopen it. Check that Flutter survives and that the result
   callback still returns to the map.
6. Check release logcat for the permission class exception. Inspect the APK's
   DEX and R8 mapping to confirm the permission class and its methods retain
   their original names. If the class is absent, check export packaging and
   dependency inclusion. If present with its original name and the exception
   persists, investigate Unity's class loader and initialization before making
   further R8 changes. Redact credentials before sharing any logs.

No backend/API changes are required by these keep rules. If live camera still
fails after the exception disappears, the Unity owner must check camera/ARCore
session startup and whether the scene waits for MultiSet authentication or
localization before displaying camera. Check SDK server reachability and
credentials privately on that machine if localization is involved. Those
Unity-side behaviors and service checks are unverified here; arrows and
guidance are outside this change.
