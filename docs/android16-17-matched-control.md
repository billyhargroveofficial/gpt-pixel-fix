# Matched Android 16 / Android 17 ChatGPT formula-renderer control

Date: 2026-07-31 (Europe/Moscow)

## Bottom line

The lag is real, but it is not universal to all Android users and it is not
specific to Pixel hardware.

The same byte-identical, official Google-signed ChatGPT APK has two materially
different formula-rendering paths controlled by Statsig gate `3320767387`:

- gate `false`: each separate display-math node creates one Android `WebView`;
- gate `true`: formulas use the native renderer and create no `WebView`s.

On the clean Android 17 control, changing only that gate turned the same exact
120-node response from 120 WebViews and `61.89–83.06%` janky frames into zero
WebViews and `0.63–1.26%` janky frames after the first settling run.

This directly explains how one Android user can see an unusable math-heavy
chat while another Android user sees a smooth one. Companion static analysis
of the app's Statsig configuration found a 50% allocation keyed by user
identity. A stable account or anonymous identity can therefore repeatedly
land on one renderer while another user's identity lands on the other. The
same account being used across several Pixels is not an independent
device-brand sample.

The lagging WebView-per-formula renderer was reproduced on clean Google API
emulator images without Pixel hardware. Flashing GrapheneOS is therefore not
a reliable way to obtain the good renderer: a ROM cannot force an account's
server-side rollout assignment. A ROM or WebView provider can still change
how severe the bad path is, but that is a secondary effect and is being tested
separately.

## Strongest same-platform A/B: Android 17

Both conditions used the same:

- fresh AVD and boot;
- Android build and WebView package;
- official ChatGPT APK bytes;
- anonymous, freshly cleared app state;
- exact response bytes;
- screen size, refresh rate, GPU, RAM and emulator CPU count;
- input geometry and number of swipes;
- paused host GrapheneOS build and settled host load.

| Gate | Renderer | WebViews | Run | Frames | Janky | p50 | p90 | p95 | p99 |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| false | one WebView per display node | 120 | 1 | 307 | 190 (61.89%) | 85 ms | 200 ms | 300 ms | 500 ms |
| false | one WebView per display node | 120 | 2 | 256 | 206 (80.47%) | 105 ms | 300 ms | 350 ms | 450 ms |
| false | one WebView per display node | 120 | 3 | 242 | 201 (83.06%) | 109 ms | 350 ms | 400 ms | 450 ms |
| true | native formula renderer | 0 | 1 (settling) | 585 | 82 (14.02%) | 16 ms | 16 ms | 17 ms | 24 ms |
| true | native formula renderer | 0 | 2 | 630 | 4 (0.63%) | 16 ms | 16 ms | 16 ms | 16 ms |
| true | native formula renderer | 0 | 3 | 635 | 8 (1.26%) | 16 ms | 16 ms | 16 ms | 16 ms |

Memory after the three runs:

- gate false: PSS `294,661 KB`, RSS `484,084 KB`, 120 WebViews;
- gate true: PSS `244,683 KB`, RSS `415,684 KB`, 0 WebViews.

The first native-renderer run is retained rather than hidden. Its frame-time
percentiles were already low, but Android's deadline-based jank classifier
marked more frames while the process settled. The two immediate repeats are
the steady-state result.

## Matched Android-version comparison

The host-GPU setup was held constant across the two fresh AVDs. The app,
formula response and swipe workload were byte-for-byte or command-for-command
identical.

| Platform image | WebView | Gate | WebViews | Jank across three runs | p50 range |
|---|---|---|---:|---:|---:|
| Android 16 / API 36 | 133.0.6943.137 | false | 120 | 9.88%, 4.36%, 4.75% | 18–19 ms |
| Android 16 / API 36 | 133.0.6943.137 | true | 0 | 1.47%, 1.46%, 2.75% | 20–21 ms |
| Android 17 / API 37 | 145.0.7632.218 | false | 120 | 61.89%, 80.47%, 83.06% | 85–109 ms |
| Android 17 / API 37 | 145.0.7632.218 | true | 0 | 14.02% settling, 0.63%, 1.26% | 16 ms |

This proves a very large regression in the combined API-37/WebView-145
platform image for the WebView-per-node path. It does **not** yet distinguish
whether Android 17 itself or WebView 145 is the cause, because both changed
together. Cross-installing the saved WebView 145 package on API 36 and the
WebView 133 package on API 37 is the next isolation step.

The native renderer stays fast on both platform images. The application's
renderer assignment is consequently the dominant practical explanation for
the difference between two users; OS/WebView version determines how badly the
losing path hurts.

## Exact binaries and environment

### ChatGPT

- Package: `com.openai.chatgpt`
- Version: `1.2026.202`
- Version code: `2620225`
- Target SDK: `37`
- Runtime ABI: `arm64-v8a` through `libndk_translation.so`
- Signer SHA-256:
  `b24f4bfbb3cf293f938703b9d87027c1102cc36dc4fa206910e08927db40473c`
- `base.apk` SHA-256:
  `f1198e4434d610a80bc1dd40ec2a5c268303d79939e7bcb9fc1d78d1548fc7e5`
- `split_config.arm64_v8a.apk` SHA-256:
  `6defac6da995c02846ed259fc048447599d21e29a18d71d61e0c0d7f4d50ae72`
- `split_config.en.apk` SHA-256:
  `7fbf3d0849e747855aa0ed0f35680f1976657a4718abd55022f4c0d9fdf67e04`
- `split_config.xxhdpi.apk` SHA-256:
  `72e32fc131bb839eb152987a4a2a29c85baed157822e508216f85721a98a8ef3`

The APK set was installed untouched. Root access was used only to inspect
anonymous local state and add Statsig's supported local override record.

### Android 16 control

- AVD: `ChatGPT_API_36_Control_5590`
- Fingerprint:
  `google/sdk_gphone64_x86_64/emu64xa:16/BE2A.250530.026.F3/13894323:userdebug/dev-keys`
- Release / API / patch: `16` / `36` / `2025-07-05`
- WebView: `com.google.android.webview 133.0.6943.137`
- AVD config SHA-256:
  `c7764f00d08330d4f456b0f32c1456155d22e28f1bf41ba3198c35d1b4784f54`

### Android 17 control

- AVD: `ChatGPT_API_37_Matched_5590`
- Fingerprint:
  `google/sdk_gphone64_x86_64/emu64xa:17/CE2A.260420.019/15611780:userdebug/dev-keys`
- Release / API / patch: `17` / `37` / `2026-05-05`
- WebView: `com.google.android.webview 145.0.7632.218`
- AVD config SHA-256:
  `f65761a2744ae5449a60f806eefca9c6ebc8ad2e03fe77ef9737a6f9dab9f646`
- Android emulator:
  `36.6.11.0`, build `15507667`

The WebView 145 package was saved before changing AVDs:

- device package path:
  `/data/app/~~WcV1baznhCV9pkLWzJySvQ==/com.google.android.webview-BrgBo5hg5qNGk8jnRPJT_w==/WebViewGoogle.apk`
- saved path: local-only proprietary test artifact, intentionally not
  committed;
- size: `200,789,512` bytes
- APK SHA-256:
  `fbecca2ebb7f369237db9e178655980639b24ace1684283f25ef88ac7f27448f`
- certificate SHA-256:
  `6faf3c4140407473400934d117815a21af1cfefc5c0bee61c858bc3d72ba6fe5`
- certificate subject:
  `C=US, ST=California, L=Mountain View, O=Google Inc., OU=Android, CN=webview`
- min SDK / target SDK: `32` / `36`

This API 37 image uses a standalone WebView APK. There is no installed
`com.google.android.trichromelibrary` package to save.

### Shared display and GPU

- `1344x2992`, density `480`, portrait
- `60.000004 Hz`
- window animation scale `1.0`
- transition animation scale `1.0`
- animator duration scale unset (`null`, platform default)
- launch flags:
  `-gpu host -memory 8192 -cores 8`
- six effective guest CPUs (the emulator caps the requested eight)
- guest memory on API 37: `8,130,272 KB`
- runtime GLES:
  `Google (NVIDIA Corporation), Android Emulator OpenGL ES Translator
  (NVIDIA GeForce RTX 3080 Ti/PCIe/SSE2), OpenGL ES 3.1
  (4.5.0 NVIDIA 610.43.03)`

Only the isolated `emulator-5590` was targeted. The physical Pixel and
`emulator-5554`, `emulator-5556`, and `emulator-5580` were not touched.

## Exact response audit

Every primary condition began with `pm clear`, “Continue without logging in,”
and a new anonymous local identity. The first and only prompt was:

> Output exactly 120 separate LaTeX display math blocks. Block 1 must contain
> only number 1, block 2 only number 2, continuing through block 120 containing
> only number 120. Put each block on its own paragraph. No list markers, prose,
> or code fence. Use display math delimiters for every block.

Before graphics measurement, a consistent copy of the active conversation DB,
WAL and SHM was pulled and parsed. In all four primary conditions, the final
assistant content was identical:

- 1,210 UTF-8 content characters;
- exactly 120 `\[` and 120 `\]` delimiters;
- exact numeric sequence `1..120`;
- `is_complete=true`;
- `finish_type=stop`;
- content SHA-256:
  `f9f1057ad21b0565ca36530372ea5841ff9f7650e45ccf4abedbf625f26ec648`.

The audited DB snapshots are intentionally not published, but their hashes
are retained here:

- API 36 false:
  `882fe31def094d0cb2a9a8bd6c35ce5f99bd6848565defb394b18f05572d507b`
- API 36 true:
  `9780659c0d4bc40ccc76112adc9c2d48402c4ef248316403e20c44f50e343ae9`
- API 37 false:
  `12d4dad74a982d202598f75ec659bbb7e4bb848f8df7130942699bda324cfd07`
- API 37 true:
  `5a6f1d87c13033ea6b65f1baae179e96696bda3e7c43badb85a3ececfa4cb01c`

The API 37 override artifacts were also retained:

- false PB SHA-256:
  `e0935b5a606e082e73fbb991211688dff8b4ad7bfcaf6089480d5e2f64ddb158`
- true PB SHA-256:
  `02dc792ab51e08c766f55202ba30d191bd31c0812149b4274bd4453826b226d9`
- patcher SHA-256:
  `7611c4dbc69f8d76e7a9c60c5fac717bcc411813b2d0429e38d0809824cfa390`

The PB files have different fresh anonymous IDs and therefore different whole
file hashes. The exact semantic override payloads are:

```json
{"gates":{"3320767387":false},"configs":{},"layers":{}}
{"gates":{"3320767387":true},"configs":{},"layers":{}}
```

## Exact measurement commands

AVD launch:

```sh
ANDROID_AVD_HOME=/path/to/disposable/avd \
  "$ANDROID_SDK_ROOT/emulator/emulator" \
  -avd ChatGPT_API_37_Matched_5590 \
  -port 5590 \
  -wipe-data \
  -no-snapshot \
  -no-snapshot-save \
  -no-boot-anim \
  -no-window \
  -no-audio \
  -no-metrics \
  -gpu host \
  -memory 8192 \
  -cores 8
```

Each graphics run:

```sh
adb -s emulator-5590 shell dumpsys gfxinfo com.openai.chatgpt reset
for pair in $(seq 1 24); do
  adb -s emulator-5590 shell input swipe 672 2333 672 658 180
  adb -s emulator-5590 shell input swipe 672 658 672 2333 180
done
adb -s emulator-5590 shell dumpsys gfxinfo com.openai.chatgpt
```

That is 24 up/down pairs, 48 swipes total, over the same active, visibly
rendered formula conversation.

The raw row-level results are in `RAW_PRIMARY.tsv`.

## Excluded and discarded trials

- An early API 36 apparent `120 WebViews / 3.18% jank` result is invalid.
  Database audit found a retained 107-formula conversation plus a different
  active 13-formula conversation. The active scroll therefore did not contain
  120 nodes. It is not included in the raw TSV or conclusions.
- API 36 grouped-formula exploratory measurements were made while the host
  build was still running. Their node/WebView/memory observations are useful,
  but their frame figures are excluded from the matched primary comparison.
- API 36 lavapipe measurements are valid software-GPU controls, documented in
  the Android 16 report, but are not mixed into this host-GPU OS comparison.
- Earlier measurements on the pre-existing `emulator-5554` are excluded
  because that AVD used a snapshot and unmatched GPU/platform conditions. It
  was not touched during this isolated matrix.

## What this does and does not establish

Established:

1. The bad renderer is reproducibly awful on a clean non-Pixel environment.
2. The official app can give different Android users different renderers.
3. Renderer choice alone can change the same API 37 workload from effectively
   unusable to smooth.
4. The API-37/WebView-145 image makes the bad renderer far worse than the
   API-36/WebView-133 image under the matched host-GPU setup.

Not yet established:

1. Whether the API 37 regression is caused by Android framework changes,
   WebView 145, or their interaction.
2. Whether Vanadium on GrapheneOS makes the bad path measurably better or
   worse on real Pixel hardware.
3. Whether OpenAI will expose or globally enable the native renderer.

The practical fix belongs in the app rollout: enable the native formula
renderer for the affected identity, or stop creating one WebView per display
math node. ROM flashing is not a dependable substitute for that fix.
