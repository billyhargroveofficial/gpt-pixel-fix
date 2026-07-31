# Investigation worklog

## Diagnosis

1. Reproduced the problem on Pixel 7/8/9 and an Android emulator.
2. Verified that the identical conversation is smooth in Chrome.
3. Ruled out keyboard input because the defect occurs during formula
   rendering and scrolling.
4. Counted one WebView per formula on the affected path.
5. Located the native Valdi and WebView renderers in the official APK.
6. Identified Statsig gate `3320767387` and its `userID` 50% rollout.
7. Identified the process-global fallback latch triggered by unsupported
   native expressions.
8. Compared Google WebView with Vanadium and found no improvement when the
   number of formula WebViews stayed constant.
9. Used Perfetto to separate low Pixel GPU time from high total frame time.

## Patch iterations

- Phase 1: force native gate and keep fallback local.
- Phase 2/3: investigate why real-chat commands and remote Valdi delivery
  still caused fallback or raw LaTeX.
- Phase 4: pin the embedded bundle, extend MathJax mappings/fonts, and repair
  quoted display delimiters.
- Phase 5: instrument SVG rendering to isolate remaining blank-image
  lifecycle failures. This was emulator-only diagnostics.

## Physical result

With explicit authorization, phase 4 was installed on the Pixel. The exact
heavy chat reported zero WebViews at inspection, visible formulas in tested
sections, and a large subjective scrolling improvement. Inline layout and
some lifecycle blanks remain.

Later, after explicit approval for a destructive factory flash and confirmed
backups, the same Pixel was downgraded to Google's official Android 16 build
`BP2A.250605.031.A2`. The untouched official ChatGPT `1.2026.202` completed a
fresh login and used WebView/Chrome `133.0.6943.137`. In the real heavy chat,
24 automated swipes produced 655 frames, `0.92%` deadline jank, p50 `6 ms`,
and p99 `21 ms`. This closed the remaining emulator-to-physical-device gap in
the WebView-version causal test.

## OpenAI report

On `2026-07-31T01:25+03:00`, the built-in ChatGPT web command
`Help -> Report a bug` submitted a 1,965-character English report from the
authenticated account. The UI returned:

```text
Thank you for your feedback!
```

The submitted text is preserved in `docs/openai-bug-report.md`. A screenshot
of the filled form is retained locally under ignored `private-evidence/`
because it exposes the account name and private conversation titles.
