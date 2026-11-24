# Indoor AR floor evidence (Flutter side)

After the user confirms their floor, Flutter uses the barometer to detect
pressure changes that may indicate a floor change. Unity can use the evidence
to reject a map match on another floor. Unity's `docs/floor-evidence-contract.md`
owns the wire contract.

## What is sent

Door verification and localization use the same optional fields. Flutter
requires a confirmed floor, a settled anchor and current window, a live sensor
stream, and a newest sample at most 10 s old. Collection stops at 1200 s after
confirmation. The serializers reject confirmation ages over 1200 s.

- `floorEvidenceVersion` 1, `startFloor` (the user's own answer, never the
  destination), `startFloorAgeS`
- `pressureSinceStart`: `settled` (always `true` when sent), `moved`, `sampleAgeS`
- For Unity's optional height hint: `requestSentAtBootS` and
  `pressureSinceStart.deltaHpa`

`requestSentAtBootS` is the device boot clock in seconds, read through the
`navipet/indoor_ar` channel (`bootClockSeconds`) just before the ages are
computed, so Unity's added send-to-SDK time can only overstate them. Android
uses `SystemClock.elapsedRealtimeNanos()` and iOS uses `mach_continuous_time()`
with `mach_timebase_info`. Both keep counting while the device sleeps, which is
the clock Unity reads. If the host cannot supply it (unsupported platform, an
older host build, an error, or a negative or non-finite value) Flutter omits the
stamp and the delta, and Unity sends no height hint. The rest of the evidence is
unchanged.

`deltaHpa` is the current settled median minus the anchor median, signed, so a
negative value means pressure fell and the phone went up. It is relative only
and is sent together with the stamp only when `moved` is true and
`0.30 <= abs <= 3`. Flutter skips the boot-clock read when the delta is
ineligible. `moved` latches, so if pressure returns to the anchor Flutter sends
`moved: true` without either hint field.

If evidence is ineligible, Flutter omits all four floor fields and Unity uses
its existing localization behavior. The summary carries no absolute or raw
pressure, wall-clock time, or location. Flutter uses the same evidence snapshot
to decide whether a `localizationFailed` result should offer a fresh floor
confirmation.

## Same pressure as the recorder

The floor anchor and the optional debug recorder both use
`SensorsPlusPressureSource`. The `sensors_plus` barometer reports
`BarometerEvent.pressure` directly in hPa. Flutter requests a 1 s sampling
period. iOS ignores that request for the barometer, and Android treats it as a
hint. The [parity test](../test/floor_pressure_parity_test.dart) drives the
plugin channels to check units, movement, and the fields sent to Unity. See the
[debug recorder instructions](../README.md#wave-d-floor-pressure-measurements)
for local measurements and export.

## Settling and movement

Flutter drops captures less than 0.5 s apart. The initial hold needs its first
accepted capture within 1.5 s of confirmation and allows gaps up to 2 s. From
20 s through the 22 s deadline, Flutter checks the full hold for stability and
takes the anchor median from the trailing 20 s. A settled window has at least
8 samples spanning at least 18 s on both capture clocks and a range below
0.06 hPa.

After the initial hold, captures that pass the spacing check clear the pressure
window if the gap is at least 10 s on either capture clock or a timestamp goes
backward. Flutter is intentionally stricter than Unity at the gap and range
boundaries. Unity resets for gaps over 10 s and accepts a settled range of
0.06 hPa. Flutter treats ranges within 1e-9 hPa of that limit as unsettled.
The separate sample-age limit above remains inclusive.

Flutter compares each new settled median with the original anchor. A
difference of at least 0.30 hPa sets `moved`. The flag remains set for that
confirmation even if the pressure returns to the anchor.

## Known limits

- `sensors_plus` converts boot-clock sample times to wall-clock with an offset
  cached once (iOS at process start, Android at handler creation). A wall-clock
  step or sleep can drop or mis-age readings. The usual result is dropped
  readings and omitted evidence. A clock step before confirmation combined with
  fast stairs could hide the start of the climb and make the previous floor
  look valid.
- Thresholds come from one afternoon of readings on one iPhone in one building.
  Android is unverified.
- The iOS Motion & Fitness permission dialog may interrupt the hold.
- Useful evidence needs a paired Unity build that contains the floor policy
  (NaviPetUnity PR 37 or later). Older Unity builds ignore the fields. Flutter
  has no version handshake and cannot tell which build it launches.
- The foreground check before launch is Dart-only. Home pressed while the
  platform call is queued can still reach the native handler.
- A brief loss of focus waits for the app to resume. A hidden, paused, or
  detached transition during token minting or the subsequent wait invalidates
  the token. On resume, Flutter checks expiry against the current phone clock
  and against the mint-start clock advanced by monotonic elapsed time. Either
  check rejects a token with one minute or less remaining. Clock skew already
  present at minting can make the monotonic check early or late.
- The boot-clock stamp and the delta are covered by Dart tests, and the iOS clock
  call was checked in a standalone Swift program on macOS, where
  `mach_continuous_time()` tracked time since boot and exceeded the
  sleep-excluding uptime. The Android and iOS host methods have not been built
  or run on a device, and no request with these fields has reached a real Unity
  build or the MultiSet server. Whether the floor-height hint changes
  localization is unverified.
- Nothing here has been verified on a device.
