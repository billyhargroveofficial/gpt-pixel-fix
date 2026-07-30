# Android 16 / API 36 isolated control

Date: 2026-07-31 (Europe/Moscow)

## Result

The official Google-signed ChatGPT Android app reproduces the renderer split on
a clean Android 16 Google APIs image:

- Statsig gate `3320767387=false`: exactly 120 separate display-math nodes
  created exactly 120 Android `WebView` instances.
- Statsig gate `3320767387=true`: the byte-identical 120-node workload created
  0 `WebView` instances and used the native formula renderer.

GPU backend was a major confound. On the same API 36 image and app state,
hardware-host rendering was comparatively smooth, while `lavapipe` software
rendering was severely janky. Therefore the API 36 numbers alone must not be
used to claim that Android 16 or WebView 133 fixes the bug.

## Isolation and binaries

- Serial: `emulator-5590` only.
- Fresh AVD: `ChatGPT_API_36_Control_5590`.
- AVD directory: local disposable test state, intentionally not committed.
- Android fingerprint:
  `google/sdk_gphone64_x86_64/emu64xa:16/BE2A.250530.026.F3/13894323:userdebug/dev-keys`
- Android release/API/security patch: `16` / `36` / `2025-07-05`.
- ABI list/native bridge: `x86_64,arm64-v8a` /
  `libndk_translation.so`.
- ChatGPT: official `com.openai.chatgpt` `1.2026.202`,
  version code `2620225`, target SDK 37, running as `arm64-v8a`.
- APK signer SHA-256:
  `b24f4bfbb3cf293f938703b9d87027c1102cc36dc4fa206910e08927db40473c`.
- APK SHA-256:
  - `base.apk`:
    `f1198e4434d610a80bc1dd40ec2a5c268303d79939e7bcb9fc1d78d1548fc7e5`
  - `split_config.arm64_v8a.apk`:
    `6defac6da995c02846ed259fc048447599d21e29a18d71d61e0c0d7f4d50ae72`
  - `split_config.en.apk`:
    `7fbf3d0849e747855aa0ed0f35680f1976657a4718abd55022f4c0d9fdf67e04`
  - `split_config.xxhdpi.apk`:
    `72e32fc131bb839eb152987a4a2a29c85baed157822e508216f85721a98a8ef3`
- WebView: `com.google.android.webview 133.0.6943.137`.
- No user account was used. Every final condition started with `pm clear`,
  selected “Continue without logging in”, and used a fresh anonymous state.
- Root was used only to write the local Statsig override and inspect the local
  conversation database. The APK bytes and signature were never modified.
- The physical Pixel, `emulator-5554`, `emulator-5556`, and
  `emulator-5580` were never targeted.

## Exact workload and audit

The same first and only prompt was used after every fresh app state:

> Output exactly 120 separate LaTeX display math blocks. Block 1 must contain
> only number 1, block 2 only number 2, continuing through block 120 containing
> only number 120. Put each block on its own paragraph. No list markers, prose,
> or code fence. Use display math delimiters for every block.

For every primary condition, an idle copy of the active anonymous conversation
database was parsed before measurement. The final assistant message had:

- exactly 120 `\[` opening display delimiters;
- a complete `1` through `120` sequence;
- `is_complete=true`;
- `finish_type=stop`;
- 1,210 content characters.

The active screen visibly showed the numbered rendered formulas in the
scrollable chat, not a home screen or detached retained views.

The supplied database
`minimal-formulas/conversations-120-nodes.db`
(`26b02658c14c5686929fe7bf476c46ce160b62e6f00c53dda3585f80176cd791`)
was also installed and hash-verified. Anonymous mode hides imported history,
and the `/c/<id>` deep link returned to the anonymous home screen, so it was
not used for the primary frame measurements.

## Display and input geometry

- Physical display: `1344x2992`, density `480`.
- Mode: `1344x2992 @ 60.000004 Hz`.
- Rotation: portrait (`0`).
- Window and transition animation scales: `1.0`.
- Animator duration scale was unset (`null`), so the platform default applied.
- Each run reset app graphics statistics with:
  `adb -s emulator-5590 shell dumpsys gfxinfo com.openai.chatgpt reset`.
- Each run then performed 24 up/down pairs, 48 swipes total:
  - up: `(672,2333) -> (672,658)`, duration `180 ms`;
  - down: `(672,658) -> (672,2333)`, duration `180 ms`.

This is the same 78%-to-22% vertical path used in the earlier provider A/B.

## Primary measurements

The GrapheneOS build and all of its compiler children were `SIGSTOP`-paused
for the entire final matrix. The host load was allowed to settle before the
measurements.

### Host GPU, 8 GB, 6 effective emulator cores

Launch flags included:
`-gpu host -memory 8192 -cores 8`; the emulator capped the CPU count to 6.

Runtime GLES:
`Android Emulator OpenGL ES Translator (NVIDIA GeForce RTX 3080 Ti/PCIe/SSE2)`.

| Gate | WebViews | Run | Frames | Janky | p50 | p90 | p95 | p99 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| false | 120 | 1 (settling) | 567 | 56 (9.88%) | 18 ms | 31 ms | 46 ms | 101 ms |
| false | 120 | 2 | 573 | 25 (4.36%) | 19 ms | 20 ms | 20 ms | 20 ms |
| false | 120 | 3 | 569 | 27 (4.75%) | 18 ms | 20 ms | 20 ms | 20 ms |
| true | 0 | 1 | 611 | 9 (1.47%) | 20 ms | 25 ms | 30 ms | 34 ms |
| true | 0 | 2 | 618 | 9 (1.46%) | 21 ms | 24 ms | 27 ms | 36 ms |
| true | 0 | 3 | 619 | 17 (2.75%) | 20 ms | 24 ms | 30 ms | 46 ms |

Memory:

- false/120 WebViews: PSS `276–279 MB`, RSS `482–485 MB`;
- true/0 WebViews: PSS `217–228 MB`, RSS `411–422 MB`.

### Lavapipe GPU, 4 GB, 6 cores

Launch flags:
`-gpu lavapipe -memory 4096 -cores 6`.

Runtime GLES:
`ANGLE (Mesa, Vulkan 1.4.318, llvmpipe 25.2.4)`.

| Gate | WebViews | Run | Frames | Janky | p50 | p90 | p95 | p99 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| false | 120 | 1 | 456 | 177 (38.82%) | 42 ms | 150 ms | 200 ms | 300 ms |
| false | 120 | 2 | 471 | 162 (34.39%) | 38 ms | 150 ms | 200 ms | 300 ms |
| false | 120 | 3 | 465 | 168 (36.13%) | 40 ms | 150 ms | 200 ms | 300 ms |
| true | 0 | 1 | 424 | 199 (46.93%) | 44 ms | 150 ms | 250 ms | 350 ms |
| true | 0 | 2 | 437 | 206 (47.14%) | 46 ms | 150 ms | 250 ms | 300 ms |
| true | 0 | 3 | 417 | 191 (45.80%) | 44 ms | 150 ms | 250 ms | 300 ms |

Memory:

- false/120 WebViews: PSS `283–287 MB`, RSS `471–475 MB`;
- true/0 WebViews: PSS `272 MB`, RSS `442 MB`.

On lavapipe, software GPU cost dominated the renderer choice and even made
the native path slightly slower in this synthetic scene. The robust renderer
difference here is architectural and memory-related: 120 WebViews versus 0,
with roughly 30–70 MB less process memory on the native path.

## Grouped-formula exploratory control

Before the build was paused, two same-device exploratory prompts were audited
in the database:

- 12 display nodes, each containing 10 `aligned` rows: exactly 120 rows,
  12 WebViews, PSS 183 MB / RSS 386 MB.
- 1 display node containing one 120-row `aligned` environment: exactly
  120 rows, 1 WebView, PSS 176 MB / RSS 380 MB.

Their frame measurements are excluded from the primary comparison because the
host build was still active. The reliable observation is the large reduction
in WebView count and memory.

## Discarded trial

An early apparent `120 WebViews / 3.18% jank` run was invalidated and is not
used anywhere above. Database audit showed that anonymous mode had created a
107-formula conversation followed by a separate 13-formula conversation.
`dumpsys meminfo` counted retained WebViews from both, while the active scroll
only contained the second conversation. Fresh app state plus active-database
auditing eliminated this error in all primary runs.

## Interpretation

1. The all-WebView renderer is not Pixel-specific. It is reproducible on a
   clean Android 16 Google APIs image.
2. Not all Android users get the same renderer: the Statsig gate changes the
   same official APK from 120 WebViews to 0.
3. GPU/backend differences can overwhelm the OS effect in emulator frame
   numbers. Android-version causality requires a matched API 37 AVD with the
   same GPU, RAM, prompt, gate, and swipe path.
4. Grouping equations reduces WebView count and memory without modifying the
   official APK, but final worst-case frame validation should be done on the
   matched API 37 lavapipe control.
