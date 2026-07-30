# Android bug report: severe LaTeX scroll jank from per-formula WebViews

## Submission status

Submitted from the authenticated ChatGPT web account through
`Help -> Report a bug` on `2026-07-31T01:25+03:00`.

- text length: 1,965 / 2,000 characters;
- screenshot option: enabled;
- confirmation returned by the UI: `Thank you for your feedback!`;
- public evidence URL included:
  `https://github.com/billyhargroveofficial/gpt-pixel-fix`.

The exact 1,965-character form text is reproduced at the end of this file.

## Post-submission evidence added to the linked repository

After submission, a clean matched host-GPU matrix found that the bad
120-WebView path is dramatically amplified by the combined Android
17/WebView 145 image:

- Android 16/WebView 133, gate false: 4.36–9.88% jank, p50 18–19 ms;
- Android 17/WebView 145, gate false: 61.89–83.06% jank, p50 85–109 ms;
- Android 17/WebView 145, gate true: 0.63–1.26% steady-state jank,
  p50 16 ms.

The exact response and APK were byte-identical across conditions. Android
version and WebView version changed together, so their individual
contributions still require a cross-install control.

## Subject

ChatGPT Android 1.2026.202: LaTeX-heavy conversations create 120–149
WebViews and become effectively unscrollable for a 50% `userID` cohort

## Environment

- Package: `com.openai.chatgpt`
- Version name: `1.2026.202`
- Version code: `2620225`
- Installation: official Google Play-signed split APK set
- Primary device: Pixel 9 Pro XL
- Also reproduced on Pixel 8 and Pixel 7
- Controlled reproduction: Google API 37 x86_64/ARM64-native-bridge AVD
- Web client control: the same conversation scrolls normally in Chrome on
  the same Pixel

## Reproduction

1. Sign in with an affected account.
2. Open a long explanation containing many inline and display LaTeX nodes.
3. Wait until formulas finish rendering.
4. Scroll through the response.

The issue is especially severe after an expression containing
`\xrightarrow`.

## Observed behavior

The Android UI becomes extremely janky. Formula rendering may take a long
time, and scrolling can feel close to frozen.

On the controlled AVD, `dumpsys meminfo` and frame statistics showed:

| Test | Formula WebViews | Janky frames | Frame-time p50 |
|---|---:|---:|---:|
| 120 supported formulas, gate false | 120 | 81.25% | 89 ms |
| Same 120 formulas, gate true | 0 | 12.83% | 16 ms |
| Real heavy conversation, gate true but containing `\xrightarrow` | 149 | 87.06% | 150 ms |

Direct Google WebView versus GrapheneOS Vanadium provider A/B on the same
AVD did not fix the problem. Both retained 149 formula WebViews and a
150 ms median frame time.

## Diagnostic evidence

The official APK contains two formula paths:

- `ValdiLatexFormulaContent` / `ValdiLatexRenderer`;
- `WebViewLatexFormulaContent`.

Statsig gate `3320767387` selects the native path. The official app's cached
server response identifies it as a `userID`-bucketed `50.00` rollout. The
affected authenticated user evaluates to false, while an anonymous user on
the same AVD evaluates to true.

Separately, one unsupported Valdi expression appears to set a process-global
fallback latch. After `\xrightarrow` fails, later supported expressions are
also sent to individual WebViews until the process is restarted.

This global latch appears to be a recent regression. The official
Google-signed `1.2026.160` build contains the same gate and both renderers, but
keeps native-render failure state local to one formula composable. The global
`Throwable` latch is present by `1.2026.195` and remains in `1.2026.202`.
Downgrading does not solve the affected user's main issue because the same
`userID` cohort still evaluates the native-renderer gate to false.

This explains why the issue is not visible for every Android user and why
changing keyboard, clearing cache, changing WebView provider, or using a
different Pixel does not resolve it for the same account.

## Requested fix

1. Enable the native renderer for the affected account or complete the
   rollout if it is considered production-ready.
2. Keep fallback scoped to the unsupported formula instead of switching all
   later formulas in the process to WebView.
3. Add support for `\xrightarrow`, or translate it to an already-supported
   equivalent.
4. If the WebView fallback must remain, avoid creating and retaining one
   WebView per formula; recycle or virtualize off-screen formula views.

I can provide the exact reproduction conversation, `dumpsys gfxinfo`
framestats, `dumpsys meminfo`, logcat, screenshots, APK hashes, and the
Google/Vanadium A/B table.

## Exact submitted text

```text
ChatGPT Android 1.2026.202: severe LaTeX scroll jank from one WebView per formula

Environment:
- com.openai.chatgpt 1.2026.202 (2620225), official Play-signed APKs
- Pixel 9 Pro XL, current Android; also reproduced on Pixel 8/7
- Same account/chat is smooth in Chrome on the same Pixel
- Another account on an Honor Android phone is not affected

Repro:
1. Sign in with the affected account.
2. Open a long answer with many inline/display LaTeX formulas.
3. Wait for rendering, then scroll. It becomes nearly unusable. A formula with \xrightarrow makes it worse.

Controlled AVD evidence:
- 120 supported formulas, native gate false: 120 WebViews, 81.25% janky frames, p50 89 ms.
- Identical content, native gate true: 0 WebViews, 12.83%, p50 16 ms.
- Real heavy chat, gate true but after \xrightarrow: 149 WebViews, 87.06%, p50 150 ms.
- Google WebView vs GrapheneOS Vanadium: both kept 149 WebViews and p50 150 ms.
- Pixel GPU p50 2 ms/p99 5 ms while total frame p50 was 150 ms: CPU/View/WebView overhead, not Tensor/Mali.

APK analysis found ValdiLatexFormulaContent and WebViewLatexFormulaContent. Statsig gate 3320767387 is a 50% rollout bucketed by userID and evaluates false for the affected account. A native-render failure (notably unsupported \xrightarrow) is stored in a process-global latch, so later supported formulas fall back too.

An experimental patch forcing the shipped native renderer and keeping fallback local reduced the real chat to 0 WebViews and made scrolling smooth on the physical Pixel. This proves the slow path is in the app, but the native path still needs fixes for unsupported commands, lifecycle blanks and inline wrapping.

Please:
1. Enable/fix the native renderer for affected users.
2. Scope fallback to one formula.
3. Support \xrightarrow.
4. Virtualize/recycle fallback instead of retaining one WebView per formula.

Repro notes, scripts, measurements, screenshots:
https://github.com/billyhargroveofficial/gpt-pixel-fix
```
