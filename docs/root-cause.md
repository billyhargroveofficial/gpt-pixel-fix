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

## Android 17 is a major amplifier

A later clean, matched host-GPU control held the official APK, exact
120-formula response, screen, swipes, GPU, RAM, CPU count, and gate semantics
constant:

| Platform | Gate | WebViews | Jank across three runs | p50 |
|---|---:|---:|---:|---:|
| API 36 / WebView 133 | false | 120 | 9.88%, 4.36%, 4.75% | 18–19 ms |
| API 37 / WebView 145 | false | 120 | 61.89%, 80.47%, 83.06% | 85–109 ms |
| API 37 / WebView 145 | true | 0 | 14.02% settling, 0.63%, 1.26% | 16 ms |

The losing account cohort and the newer platform stack are therefore
independent compounding factors. This can explain a smooth Android-16 Honor
and unusable current Pixels without making the defect Pixel-hardware
specific. Because Android version and WebView version changed together, this
test does not yet assign the regression to one of them individually.

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
  fallback latch.
