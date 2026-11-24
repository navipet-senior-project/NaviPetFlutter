# Indoor AR floor evidence (Flutter side)

Before launching Unity, the app asks which floor the user stands on and sends
Unity a small summary of whether the phone stayed on that level. Unity uses it
to veto a map match on the wrong floor. The wire contract is Unity's
`docs/floor-evidence-contract.md`; this page covers the Flutter host.

## What is sent

The app sends the fields below only when the user confirmed a positive integer
floor, both pressure windows are settled, the confirmation is at most 1200 s
old, the newest sample is at most 10 s old, and the sensor stream is alive.

- `floorEvidenceVersion` 1, `startFloor` (the user's own answer, never the
  destination), `startFloorAgeS`
- `pressureSinceStart`: `settled` (always `true` when sent), `moved`, `sampleAgeS`

Otherwise nothing is sent and Unity behaves as it did before. The AR floor
summary carries no absolute or raw pressure, wall-clock time, or location.
Skipping the prompt reads no sensor.

## Same pressure as the recorder

The floor anchor and the optional debug recorder both use
`SensorsPlusPressureSource`. The `sensors_plus` barometer reports
`BarometerEvent.pressure` directly in hPa. Starting a debug recording saves
per-floor `deltaHpa` and `elapsedMs` measurements on the device. The user can
choose to copy the recording as JSON.
Flutter requests a 1 s sampling period. iOS ignores that request for the
barometer, and Android treats it as a hint.
`test/floor_pressure_parity_test.dart` drives that source
through the plugin's channels and checks that a 0.47 hPa step is 0.47 in the
recorder and latches `moved` in the anchor, and that the wire summary holds no
pressure values. That shows the two paths agree; it does not show the sensor is
accurate on any device.

The anchor drops captures less than 0.5 s apart. A settled 20 s window has
at least 8 samples spanning at least 18 s and a range of at most 0.06 hPa.
A settled median difference of at least 0.30 hPa sets `moved`.

After the initial hold, a capture gap over 10 s or a non-increasing timestamp
clears the pressure window. Collection can continue until the confirmation
expires at 1200 s. A new settled window is compared with the original anchor,
and any movement already detected stays latched.

## Known limits

- `sensors_plus` converts boot-clock sample times to wall-clock with an offset
  cached once (iOS at process start, Android at handler creation). A wall-clock
  step or sleep can drop or mis-age readings. The usual result is dropped
  readings and omitted evidence. A clock step before confirmation combined with
  fast stairs could hide the start of the climb and make the previous floor
  look valid. No native pressure source is added to avoid this.
- Thresholds come from one iPhone in one building. Android is unverified.
- The iOS Motion & Fitness permission dialog may interrupt the hold.
- The floor prompt is skippable. Useful evidence needs a paired Unity build that
  contains the floor policy (NaviPetUnity PR 37 or later); older Unity builds
  ignore the fields. Flutter has no version handshake and cannot tell which
  build it launches.
- The foreground check before launch is Dart-only. Home pressed while the
  platform call is queued can still reach the native handler.
- Token expiry uses the phone's clock at mint start plus monotonic elapsed
  time, so skew already present at minting can make the check early or late.
  The launch also checks the current phone clock and rejects the token if
  either check indicates expiry within the one-minute launch margin.
- Nothing here has been verified on a device.
