# ChatGPT Android native LaTeX phase 4

This project builds a separate patched split-APK set for ChatGPT Android
1.2026.202. It does not install anything as part of the build and does not
touch a physical phone.

## What phase 4 changes

The candidate keeps the two phase-1 renderer patches:

- use the Valdi/native LaTeX renderer;
- keep WebView fallback local to a formula that genuinely cannot render.

It adds three narrowly scoped changes.

### 1. Use the APK's patched Valdi bundle

ChatGPT dynamic delivery otherwise replaces the embedded
`assets/math_jax.valdimodule` with the original signed remote bundle.
`classes.dex` is patched at `0x2ae220` from `55 60 67 8a` to
`12 10 00 00`, selecting Valdi's built-in bundled-fallback branch.

### 2. Complete the native MathJax base package

Only two of 220 entries in `math_jax.valdimodule` change:

- `src/mathjax_src/input/tex/base/BaseMappings.js`;
- the module `hash`.

The generated base map adds the exact MathJax 4.1.1 behavior needed by the
real failing chat:

- `aligned` and `cases`;
- `\xrightarrow` and `\operatorname`;
- `\lvert`, `\rvert`, `\lVert`, and `\rVert`;
- complete calligraphic, double-struck, and Cyrillic SVG glyph tables.

Font data is inserted into the APK's original precompiled
`MathJaxNewcmFont` class before its first instance is constructed. The
corresponding `calligraphic`, `double-struck`, and `cyrillic` dynamic-file
sentinels are then removed. This preserves Valdi's precompiled class ABI and
avoids unavailable `mathjax.asyncLoad` calls.

The vendored MathJax and font inputs are pinned by SHA-256. The final module
changes exactly the two expected archive entries and verifies the other 218
byte-for-byte.

### 3. Recognize display math inside Markdown quotes

The original display-delimiter regex accepts spaces before `\[` and `\]`,
but not a Markdown quote prefix. That leaves quoted display math as unmatched
U+E001 inline sentinels.

Two equal-length, DEX-sort-preserving strings in `classes5.dex` are replaced:

- `0x7e0b64`: `(?:\n|$) *\\] *(?:\n|$)` becomes
  `(?:\n|$)[ >]*?\\](\n|$)`;
- `0x7e0b7d`: `(?:\n|^) *\\(\[) *(?:\n|$)` becomes
  `(?:\n|^)[ >]*?\\(\[)(\n|$)`.

The build recomputes DEX SHA-1 and Adler-32 fields and verifies the final
bytes after extracting them from the signed APK.

## Build

```sh
cd patches/phase1
CHATGPT_PHASE4_INPUT_DIR=../phase4/input ./build.sh
cd ../phase4
./build.sh
```

Output:

`output/chatgpt-1.2026.202-native-latex-phase4/`

The split set has package versionName `1.2026.202` and versionCode `2620230`.
All four APKs are aligned, signed with the same existing local debug
certificate, and V2/V3 verified.

## Validation

`build/host-mathjax-smoke.json` runs MathJax and the New Computer Modern font
at exact version 4.1.1. Nine native SVG cases pass with no `merror`, including
the exact multiline Cyrillic `aligned` formula from the failing central-limit
theorem chat, `cases`, `operatorname`, `xrightarrow`, `lVert`, `mathbb`, and
complete uppercase `mathcal`.

On `emulator-5554`, after a force-stop and cold application start:

- the real chat `Доказательство ЦПТ свопом` visibly renders its aligned
  telescoping estimate and inline formulas;
- `для каждого` renders as Cyrillic SVG text in the exact display block;
- the distribution arrow renders natively;
- UI hierarchy reports zero WebViews at the checked problem sections;
- logcat reports no LaTeX failure, MathJax retry, asynchronous-load, unknown
  environment, or undefined-control-sequence errors.

Representative evidence:

- `/tmp/phase4-cyr-sum-visible.png`
- `/tmp/phase4-cyr-exact-centered.png`
- `/tmp/phase4-cyr-exact-centered-logcat.txt`

These emulator checks do not constitute a performance result for a Pixel:
the AVD is forced onto SwiftShader/lavapipe software rendering and the host
was concurrently loaded.
