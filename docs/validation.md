# Validation

## Controlled renderer A/B

| Workload | Gate | WebViews | Janky frames | p50 |
|---|---:|---:|---:|---:|
| 120 supported display formulas | true | 0 | 12.83% | 16 ms |
| Same 120 formulas | false | 120 | 81.25% | 89 ms |
| Real heavy conversation after `\xrightarrow` | true | 149 | 87.06% | 150 ms |

The WebView provider A/B used identical application state:

| Provider | WebViews | p50 |
|---|---:|---:|
| Google WebView | 149 | 150 ms |
| GrapheneOS Vanadium | 149 | 150 ms |

Raw values are in `experiments/webview-ab-results.tsv`.

## Full GrapheneOS source-build control

A dedicated Android 17 `userdebug` emulator product was built from the
GrapheneOS stable `2026071500` source tag. It selected the source build's
Vanadium WebView `150.0.7871.124.0`. The untouched Google Play-signed
ARM64 ChatGPT split set `1.2026.202` ran through a test-only ARM64 native
bridge.

The same prompt requested 120 separate supported display formulas. The
server produced 118 native formula nodes in the gate=true response and 114
separate formula blocks in the gate=false response. The model did not obey
the count exactly, so this is a near-matched rather than byte-identical
response control. The APK, OS build, WebView provider, screen and 48-swipe
workload were fixed.

| Condition | Formula nodes | WebViews | Jank across three runs | p50 |
|---|---:|---:|---:|---:|
| gate=true, native renderer | 118 | 0 | 2.12%, 2.91%, 0.00% | 17–18 ms |
| gate=false, WebView renderer | 114 | 114 | 91.79%, 96.41%, 100.00% | 73 ms |

This reproduces the severe failure in the full GrapheneOS runtime, rather
than only with Vanadium cross-installed into a Google AVD. Raw rows are in
`experiments/graphene-native-build.tsv`.

## Matched Android 16 / Android 17 control

The exact 1,210-character response was audited in every fresh anonymous
condition: 120 opening and 120 closing display delimiters, exact numeric
sequence `1..120`, and SHA-256
`f9f1057ad21b0565ca36530372ea5841ff9f7650e45ccf4abedbf625f26ec648`.

On API 37 / WebView 145, changing only gate `3320767387` changed:

- 120 WebViews, 61.89–83.06% jank, p50 85–109 ms;
- to 0 WebViews, then 0.63–1.26% steady-state jank and p50 16 ms.

Under the matched host-GPU setup, API 36 / WebView 133 with gate false stayed
at 4.36–9.88% jank and p50 18–19 ms.

The exact official WebView 145 APK was then cross-installed on that same API
36 AVD. The selected package and renderer process maps were verified, while
the app, gate, response SHA-256, host GPU and swipe workload stayed fixed:

- run 1: 81.19% jank, p50 85 ms;
- run 2: 69.32% jank, p50 81 ms;
- run 3: 68.54% jank, p50 81 ms.

The reverse control installed matching official Trichrome 133 and WebView 133
on API 37, verified current/preferred provider, relro `1/1`, package state and
ChatGPT process maps, then repeated the exact workload:

- run 1: 8.21% jank, all reported percentiles 16 ms;
- run 2: 3.75% jank, all reported percentiles 16 ms;
- run 3: 0.00% jank, all reported percentiles 16 ms.

The severe regression follows WebView 145 onto Android 16 and disappears with
WebView 133 on Android 17. Android version is not the primary cause, although
a smaller independent platform contribution is not ruled out.

Full conditions and excluded invalid trials:

- `docs/android16-17-matched-control.md`;
- `docs/android16-control.md`;
- `experiments/android16-17-primary.tsv`.

## Formula-grouping mitigation

The exact slowest relevant environment was retained: API 37, official WebView
`145.0.7632.218`, gate=false, official ChatGPT APK, host GPU, and the same
48-swipe input profile.

| Layout | Equation rows | WebViews | Jank across three runs | p50/p90/p95/p99 |
|---|---:|---:|---:|---:|
| 120 separate display blocks | 120 | 120 | 61.89%, 80.47%, 83.06% | up to 109/350/400/450 ms |
| 12 display blocks × 10 aligned rows | 120 | 12 | 1.00%, 0.00%, 0.00% | 16/16/16/16 ms |
| 1 display block × 120 aligned rows | 120 | 1 | 0.17%, 0.86%, 0.00% | 16/16/16/16 ms |

The grouped workloads intentionally contain more complex equations than the
simple 120-node baseline and are therefore not byte-identical. Their
delimiter, aligned-environment, row and sequence counts were audited directly
in the stored conversation databases. Full methodology and hashes are in
`docs/formula-grouping-workaround.md`; the six raw measurement rows are in
`experiments/formula-grouping.tsv`.

## Host MathJax corpus

The phase-4 host smoke test used MathJax and New Computer Modern at exact
version `4.1.1`.

- 150 formulas: 71 display and 79 inline;
- 3,397 SVG paths;
- 1.66 seconds;
- zero host-render failures.

It includes multiline Cyrillic `aligned`, `cases`, `operatorname`,
`xrightarrow`, `lVert`, `mathbb`, and uppercase `mathcal`.

## Build reproducibility

- Phase 1 exported the exact same unsigned base SHA-256 in two clean runs:
  `d2af202efd729f25168597833ecadf635d8a34e363f7298aca400ce7ca29d703`.
- Two complete phase-4 rebuilds produced identical APK SHA-256 values; they
  are recorded in
  `evidence/phase4/REPRODUCIBLE-SOURCE-BUILD-SHA256SUMS`.
- `zipcmp` reported identical payloads between every rebuilt split and the
  earlier split set installed on the physical Pixel.
- The launcher rebuilt byte-for-byte to the committed
  `launcher/dist/chatgpt-chrome.apk`.

## Emulator phase 4

At the checked problem sections after a cold application start:

- aligned telescoping estimates were visible;
- Cyrillic SVG text was visible;
- distribution arrows rendered natively;
- UI hierarchy reported zero WebViews;
- logcat contained no relevant MathJax or undefined-control-sequence errors.

## Physical Pixel: unmodified official app on WebView 133

After explicit authorization, backup, and an unlocked-bootloader warning, the
Pixel 9 Pro XL was fully flashed with Google's official
`komodo-bp2a.250605.031.a2` factory image. The resulting environment was:

- build `google/komodo/komodo:16/BP2A.250605.031.A2/13578606:user/release-keys`;
- Android 16, security patch `2025-06-05`;
- Google WebView and Chrome `133.0.6943.137`;
- untouched official ChatGPT `1.2026.202` (`versionCode=2620225`);
- a fresh successful sign-in to the official package.

With the exact heavy mathematical conversation open, a 12-up/12-down swipe
run after `dumpsys gfxinfo ... reset` recorded:

- 655 rendered frames;
- 6 deadline-janky frames (`0.92%`);
- p50/p90/p95/p99 of `6/11/13/21 ms`;
- zero missed-vsync frames.

This is the first direct physical-device proof that the old provider removes
the catastrophic amplifier without modifying ChatGPT. It does not make the
June 2025 OS/WebView safe for normal long-term use.

Raw values and the operational caveats are in
`experiments/physical-pixel-android16.tsv` and
`docs/physical-pixel-android16-webview133.md`.

## Physical Pixel: patched renderer proof

The phase-4 set with versionCode `2620230` was installed on the authorized
Pixel 9 Pro XL while preserving the existing local-signer app session.

For the exact heavy chat:

- `dumpsys` reported 313 Views and zero WebViews at inspection time;
- formulas in the inspected sections were visible;
- the user reported that scrolling was fast;
- a partial, non-standard capture after reset/autoscroll recorded 2,347
  frames, 0.26% deadline jank, and frame percentiles 6/8/9/12 ms.

The last line is not a standardized 48-swipe benchmark and must not be
compared as if it were one.

## Phase-5 lifecycle diagnostic

An instrumented emulator build returned valid SVG for 281 of 284 recorded
render calls, yet some lower/middle formula images stayed blank. This
isolates the remaining issue after SVG generation to the
`LatexView -> Asset -> Image` lifecycle/cache/decode path rather than only
MathJax parsing.
