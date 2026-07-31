# Root cause

## What was slow

ChatGPT Android `1.2026.202` ships both
`ValdiLatexFormulaContent`/`ValdiLatexRenderer` and
`WebViewLatexFormulaContent`.

In the slow path, each formula is represented by a separate Android WebView.
A synthetic response containing 120 supported formulas produced 120
WebViews. The real failing conversation produced 149. Scrolling then pays the
CPU-side cost of traversing many Views, coordinating Chromium renderers, and
compositing many surfaces.

Perfetto on the physical Pixel measured GPU frame work around `p50=2 ms` and
`p99=5 ms` while complete frames had `p50=150 ms`. The bottleneck therefore
did not require a slow Tensor/Mali GPU.

## Why one account was affected

The cached Statsig configuration identified gate `3320767387` as a `50.00`
rollout bucketed by `userID`.

- affected authenticated user: `false`;
- anonymous user on the same AVD: `true`.

This explains why repeating the test on Pixel 7/8/9 with the same account
repeated the bug while a different account on an Honor phone could be smooth.
It is an account/content cohort effect that may be amplified by OS, GPU
backend, refresh rate, or OEM scheduling.

## WebView 145 is a major amplifier

A later clean, matched host-GPU control held the official APK, exact
120-formula response, screen, swipes, GPU, RAM, CPU count, and gate semantics
constant:

| Platform | Gate | WebViews | Jank across three runs | p50 |
|---|---:|---:|---:|---:|
| API 36 / WebView 133 | false | 120 | 9.88%, 4.36%, 4.75% | 18–19 ms |
| API 36 / WebView 145 | false | 120 | 81.19%, 69.32%, 68.54% | 81–85 ms |
| API 37 / WebView 133 | false | 120 | 8.21%, 3.75%, 0.00% | 16 ms |
| API 37 / WebView 145 | false | 120 | 61.89%, 80.47%, 83.06% | 85–109 ms |
| API 37 / WebView 145 | true | 0 | 14.02% settling, 0.63%, 1.26% | 16 ms |

The `API 36 / WebView 145` condition is a cross-install: the exact official
WebView 145 APK from the API 37 image was installed and selected on the API 36
control.
`dumpsys webviewupdate` and renderer process maps both verified the provider.
The active database still contained the byte-identical 120-node response.

The catastrophic slowdown followed WebView 145 onto Android 16. Android 17
is therefore not required for the regression. The reverse control installed
matching Trichrome 133 and WebView 133 on API 37 and restored smooth frame
times, confirming that the result tracks WebView generation in both
directions. The losing account cohort and a WebView-145-era provider are
independent compounding factors. This can explain an unusable current Pixel
without making the defect Pixel-hardware specific. The test does not yet
identify the first broken WebView revision or exclude a smaller additional
Android 17 effect.

## Why one formula poisoned the rest

Even with the native gate enabled, an unsupported Valdi expression such as
`\xrightarrow` could set a process-global `Throwable` latch. Later supported
formulas then selected WebView fallback until process restart.

The Google Play-signed `1.2026.160` build kept this failure local to one
formula. The global latch is present by `1.2026.195` and remains in
`1.2026.202`.

## Why common workarounds did not fix it

- Keyboard changes do not affect the renderer selected after a response is
  received.
- Chrome uses a different web rendering path and was smooth.
- Switching Google WebView to Vanadium preserved 149 WebViews and the same
  150 ms median in the controlled test.
- GrapheneOS does not change the OpenAI Statsig assignment or application
  fallback latch, and current Vanadium 150/151 did not repair the modern
  provider regression. A full source-build control with Vanadium 150 measured
  `91.79–100%` jank and 114 WebViews in the slow condition, versus
  `0.00–2.91%` and zero WebViews in the native condition.
- Pinning WebView 133 would remove later WebView security fixes and is not a
  safe daily-device workaround.

## Why grouping formulas does help

The slow renderer creates WebViews per math block, not per equation row inside
an `aligned` environment. On Android 17 + WebView 145 + gate=false, 120
separate display blocks produced 120 WebViews and `61.89–83.06%` jank.
Reformatting 120 equation rows as 12 display blocks of 10 aligned rows
produced 12 WebViews and `0.00–1.00%` jank, with every reported frame-time
percentile at 16 ms.

This is a response-structure mitigation rather than a renderer fix, but it
works in the unmodified, officially signed application and does not require
an insecure WebView downgrade. See
[`formula-grouping-workaround.md`](formula-grouping-workaround.md).
