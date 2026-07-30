# Patch design

All offsets are guarded by expected original bytes and exact input hashes.
The DEX patcher recomputes the SHA-1 signature and Adler-32 checksum.

## Phase 1

`classes4.dex`, offset `0x5124b2`:

```text
0a03 -> 1213
move-result v3 -> const/4 v3, 0x1
```

This forces the native-renderer gate result to true.

`classes5.dex`, offset `0x6ebe90`:

```text
6e20a2950100 -> 000000000000
```

This removes the write to the process-global fallback latch. A genuinely
unsupported formula may still use WebView, but it no longer poisons later
formulas.

## Phase 4

`classes.dex`, offset `0x2ae220`:

```text
5560678a -> 12100000
```

This selects Valdi's bundled-fallback branch. Without it, signed dynamic
delivery can replace the patched embedded `math_jax.valdimodule` with the
original remote module.

Two equal-length strings in `classes5.dex` are replaced so display delimiters
inside Markdown quotes reach the display-math path:

```text
0x7e0b64
(?:\n|$) *\\] *(?:\n|$)
-> (?:\n|$)[ >]*?\\](\n|$)

0x7e0b7d
(?:\n|^) *\\(\[) *(?:\n|$)
-> (?:\n|^)[ >]*?\\(\[)(\n|$)
```

The embedded MathJax 4.1.1 mapping adds:

- `\xrightarrow`, `aligned`, `cases`, and `\operatorname`;
- `\lvert`, `\rvert`, `\lVert`, and `\rVert`;
- static calligraphic, double-struck, and Cyrillic SVG glyph data.

Dynamic async sentinels are removed after the equivalent static data is
inserted, because the Valdi environment does not provide the required
`mathjax.asyncLoad` path.

Only `BaseMappings.js` and the Valdi module hash entry change; the remaining
218 archive entries are verified byte-for-byte.
