# Formula-grouping workaround for the official Android app

Date: 2026-07-31 (Europe/Moscow)

## Result

On the affected ChatGPT renderer, scrolling cost tracks the number of
display-math blocks because each block creates a separate Android WebView.
It does not track the number of equation rows inside an `aligned` block in the
same way.

The following controls used the worst relevant environment: Android 17,
official Google WebView `145.0.7632.218`, Statsig gate
`3320767387=false`, the unmodified official ChatGPT `1.2026.202` split APK
set, host GPU, and the same 48-swipe input profile.

| Layout | Equation rows | WebViews | Three jank results | p50/p90/p95/p99 |
|---|---:|---:|---:|---:|
| 120 separate display blocks | 120 simple rows | 120 | 61.89%, 80.47%, 83.06% | up to 109/350/400/450 ms |
| 12 display blocks × 10 aligned rows | 120 equation rows | 12 | 1.00%, 0.00%, 0.00% | 16/16/16/16 ms |
| 1 display block × 120 aligned rows | 120 equation rows | 1 | 0.17%, 0.86%, 0.00% | 16/16/16/16 ms |

The grouped formulas are more complex than the 120-number baseline, so this
is not a byte-identical content comparison. Despite that disadvantage,
reducing the node/WebView count from 120 to 12 or 1 eliminated catastrophic
scroll lag.

## Recommended format

Use at most 10 consecutive equation rows per display block:

```text
Format multi-line mathematics using aligned environments. Put no more than
10 consecutive equation rows inside each display-math block. Never wrap each
equation line in a separate display-math block. Split longer derivations into
additional blocks of at most 10 rows each.
```

This text can be appended to a math request or placed in custom instructions.
For an existing answer, ask ChatGPT to regenerate it using this format.

One 120-row block was also smooth and used roughly 6 MB less process memory
than the 12-block version, but it is not recommended for study material:

- one malformed row can invalidate the whole block;
- wide equations can overflow the phone viewport;
- selection, copying, accessibility and navigation are less manageable;
- the enormous visual object provides no measured scrolling benefit over
  12 blocks of 10 rows.

For unusually wide or complex equations, use fewer than 10 rows. Ten is the
largest directly validated conservative default, not a claimed universal
layout limit.

## 12 × 10 audit

- 12 opening and 12 closing display delimiters;
- 12 `begin{aligned}` and 12 `end{aligned}` markers;
- exactly 120 equation rows;
- 108 row separators, nine inside each block;
- complete response with `finish_type=stop`;
- 3,526 content characters;
- response SHA-256:
  `7782e4ec5f5520eba49aeacad55727561b3dd86389020b6b93013aef346fc6d1`;
- exactly 12 Android WebViews.

| Run | Frames | Janky | p50 | p90 | p95 | p99 |
|---:|---:|---:|---:|---:|---:|---:|
| 1 | 603 | 6 (1.00%) | 16 ms | 16 ms | 16 ms | 16 ms |
| 2 | 585 | 0 (0.00%) | 16 ms | 16 ms | 16 ms | 16 ms |
| 3 | 582 | 0 (0.00%) | 16 ms | 16 ms | 16 ms | 16 ms |

Final memory: PSS `210,477 KB`, RSS `395,788 KB`, 12 WebViews.

Audited database SHA-256:
`f422db063be3915c4f7373807f9702c7a2ac63817b1bc4f6270aacb66d102a1b`.

## 1 × 120 audit

- one opening and one closing display delimiter;
- one `begin{aligned}` and one `end{aligned}`;
- exactly 120 x, y and z numeric subscript sequences, each exactly `1..120`;
- 119 row separators;
- complete response with `finish_type=stop`;
- 5,001 content characters;
- response SHA-256:
  `763fefbbc937962c7c856d2dc40932dbe53a03e31be2a7a8a1fac64d64d1b8f1`;
- exactly one Android WebView.

| Run | Frames | Janky | p50 | p90 | p95 | p99 |
|---:|---:|---:|---:|---:|---:|---:|
| 1 | 597 | 1 (0.17%) | 16 ms | 16 ms | 16 ms | 16 ms |
| 2 | 583 | 5 (0.86%) | 16 ms | 16 ms | 16 ms | 16 ms |
| 3 | 581 | 0 (0.00%) | 16 ms | 16 ms | 16 ms | 16 ms |

Final memory: PSS `204,424 KB`, RSS `390,352 KB`, one WebView.

Audited database SHA-256:
`995fceb0b27e036f358f27bb6010acb9e3e7dabe6e55b43e39859d43fb87a32a`.

## Isolation

Each grouped condition began with cleared app data, a new anonymous identity,
and the same explicit gate-false override. WebView 145 was verified as
Current, Preferred and Valid with relro `1/1` before and after measurement.
The physical Pixel was not used for these controls.

Raw data: [`../experiments/formula-grouping.tsv`](../experiments/formula-grouping.tsv).
