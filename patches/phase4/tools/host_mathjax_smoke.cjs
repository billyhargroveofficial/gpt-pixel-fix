#!/usr/bin/env node

"use strict";

const assert = require("node:assert/strict");
const path = require("node:path");
const { createRequire } = require("node:module");

const fixtureRoot = process.argv[2];
if (!fixtureRoot) {
  console.error(
    "usage: host_mathjax_smoke.cjs <fixture-with-node_modules>",
  );
  process.exit(2);
}

const fixtureRequire = createRequire(
  path.join(path.resolve(fixtureRoot), "phase3-smoke.cjs"),
);
const { mathjax } = fixtureRequire("@mathjax/src/cjs/mathjax.js");
const { TeX } = fixtureRequire("@mathjax/src/cjs/input/tex.js");
const { SVG } = fixtureRequire("@mathjax/src/cjs/output/svg.js");
const { liteAdaptor } = fixtureRequire(
  "@mathjax/src/cjs/adaptors/liteAdaptor.js",
);
const { RegisterHTMLHandler } = fixtureRequire(
  "@mathjax/src/cjs/handlers/html.js",
);

const adaptor = liteAdaptor();
RegisterHTMLHandler(adaptor);
const tex = new TeX({ packages: ["base"] });
const svg = new SVG({ fontCache: "none" });
const html = mathjax.document("", {
  InputJax: tex,
  OutputJax: svg,
});

const cases = [
  {
    name: "xrightarrow-with-over-and-under",
    source: String.raw`A \xrightarrow[under]{over} B`,
    variant: null,
    expectedPathCount: 1,
  },
  {
    name: "aligned-environment",
    source: String.raw`\begin{aligned} a &= b+c \\ d &= \frac{1}{2} \end{aligned}`,
    variant: null,
    expectedPathCount: 5,
  },
  {
    name: "lVert-rVert-delimiters",
    source: String.raw`\left\lVert x \right\rVert`,
    variant: null,
    expectedPathCount: 3,
  },
  {
    name: "mathcal-complete-uppercase",
    source: String.raw`\mathcal{ABCDEFGHIJKLMNOPQRSTUVWXYZ}`,
    variant: "-tex-calligraphic",
    expectedPathCount: 26,
  },
  {
    name: "mathbb",
    source: String.raw`\mathbb{R}`,
    variant: null,
    expectedPathCount: 1,
  },
  {
    name: "operatorname",
    source: String.raw`\operatorname{Var}(X) + \operatorname*{arg\,max}_{x} f(x)`,
    variant: null,
    expectedPathCount: 10,
  },
  {
    name: "cases-environment",
    source: String.raw`f(x)=\begin{cases}x^2,&x\ge0\\-x,&x<0\end{cases}`,
    variant: null,
    expectedPathCount: 8,
  },
  {
    name: "cyrillic-text",
    source: String.raw`\text{кириллица}`,
    variant: null,
    expectedPathCount: 9,
  },
  {
    name: "exact-cyrillic-aligned-from-cpt-chat",
    source: String.raw`\begin{aligned}
&\mathbb E X_{n,i}=0,\\
&v_{n,i}:=\mathbb E X_{n,i}^2,\\
&\sum_{i=1}^{m_n}v_{n,i}=1,\\
&L_n(\delta):=\sum_{i=1}^{m_n}\mathbb E\left[
X_{n,i}^2;|X_{n,i}|>\delta\right]\longrightarrow0
\qquad\text{для каждого }\delta>0.
\end{aligned}`,
    variant: null,
    expectedPathCount: 40,
  },
];

const report = [];
for (const testCase of cases) {
  const node = html.convert(testCase.source, { display: true });
  const output = adaptor.outerHTML(node);
  const pathCount = (output.match(/<path /g) || []).length;
  const asyncSentinelsRemaining = testCase.variant
    ? Object.values(svg.font.variant[testCase.variant].chars).filter(
        (value) => !Array.isArray(value),
      ).length
    : null;

  assert.equal(
    output.includes("merror"),
    false,
    `${testCase.name} produced an merror`,
  );
  assert.ok(
    pathCount >= testCase.expectedPathCount,
    `${testCase.name} did not render the expected SVG paths`,
  );
  if (testCase.variant) {
    assert.equal(
      asyncSentinelsRemaining,
      0,
      `${testCase.name} still contains async-load sentinels`,
    );
  }

  report.push({
    name: testCase.name,
    source: testCase.source,
    output_bytes: Buffer.byteLength(output),
    svg_path_count: pathCount,
    has_merror: false,
    async_sentinels_remaining: asyncSentinelsRemaining,
  });
}

const fontTables = {};
for (const variant of [
  "-tex-calligraphic",
  "-tex-bold-calligraphic",
]) {
  const chars = svg.font.variant[variant].chars;
  const glyphs = Array.from(
    { length: 26 },
    (_, index) => chars[0x41 + index],
  );
  assert.ok(
    glyphs.every(
      (glyph) =>
        Array.isArray(glyph) &&
        typeof glyph[3]?.p === "string" &&
        glyph[3].p.length > 0,
    ),
    `${variant} is missing one or more A-Z SVG glyphs`,
  );
  const asyncSentinelsRemaining = Object.values(chars).filter(
    (value) => !Array.isArray(value),
  ).length;
  assert.equal(
    asyncSentinelsRemaining,
    0,
    `${variant} still contains async-load sentinels`,
  );
  fontTables[variant] = {
    uppercase_svg_glyph_count: glyphs.length,
    async_sentinels_remaining: asyncSentinelsRemaining,
  };
}

const cyrillicCodePoints = Array.from(
  new Set(Array.from("кириллица", (character) => character.codePointAt(0))),
);
const cyrillicGlyphs = cyrillicCodePoints.map(
  (codePoint) => svg.font.variant.normal.chars[codePoint],
);
assert.ok(
  cyrillicGlyphs.every(
    (glyph) =>
      Array.isArray(glyph) &&
      typeof glyph[3]?.p === "string" &&
      glyph[3].p.length > 0,
  ),
  "normal font is missing one or more Cyrillic SVG glyphs",
);
fontTables.cyrillic = {
  tested_code_points: cyrillicCodePoints.map(
    (codePoint) => `U+${codePoint.toString(16).toUpperCase()}`,
  ),
  svg_glyph_count: cyrillicGlyphs.length,
};

console.log(
  JSON.stringify(
    {
      mathjax_version: fixtureRequire(
        "@mathjax/src/package.json",
      ).version,
      font_version: fixtureRequire(
        "@mathjax/mathjax-newcm-font/package.json",
      ).version,
      cases: report,
      font_tables: fontTables,
    },
    null,
    2,
  ),
);
