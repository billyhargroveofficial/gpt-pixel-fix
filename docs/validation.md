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

## Matched Android 16 / Android 17 control

The exact 1,210-character response was audited in every fresh anonymous
condition: 120 opening and 120 closing display delimiters, exact numeric
sequence `1..120`, and SHA-256
`f9f1057ad21b0565ca36530372ea5841ff9f7650e45ccf4abedbf625f26ec648`.

On API 37 / WebView 145, changing only gate `3320767387` changed:

- 120 WebViews, 61.89–83.06% jank, p50 85–109 ms;
- to 0 WebViews, then 0.63–1.26% steady-state jank and p50 16 ms.

Under the matched host-GPU setup, API 36 / WebView 133 with gate false stayed
at 4.36–9.88% jank and p50 18–19 ms. This proves a large regression in the
combined newer platform image, but Android and WebView contributions remain
confounded.

Full conditions and excluded invalid trials:

- `docs/android16-17-matched-control.md`;
- `docs/android16-control.md`;
- `experiments/android16-17-primary.tsv`.

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

## Physical Pixel

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
