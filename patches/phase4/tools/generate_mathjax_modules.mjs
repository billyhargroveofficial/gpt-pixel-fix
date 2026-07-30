#!/usr/bin/env node

import assert from "node:assert/strict";
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import vm from "node:vm";

const [
  baseMappingsPath,
  dynamicCalligraphicPath,
  dynamicDoubleStruckPath,
  dynamicCyrillicPath,
  fontSvgPath,
  entriesRoot,
] = process.argv.slice(2);

if (
  !baseMappingsPath ||
  !dynamicCalligraphicPath ||
  !dynamicDoubleStruckPath ||
  !dynamicCyrillicPath ||
  !fontSvgPath ||
  !entriesRoot
) {
  console.error(
    "usage: generate_mathjax_modules.mjs " +
      "<BaseMappings.js> <dynamic/calligraphic.js> " +
      "<dynamic/double-struck.js> <dynamic/cyrillic.js> " +
      "<font-svg.js> <unpacked-entries-root>",
  );
  process.exit(2);
}

function sha256(contents) {
  return crypto.createHash("sha256").update(contents).digest("hex");
}

function readVerified(file, expectedSha256) {
  const contents = fs.readFileSync(file, "utf8");
  assert.equal(
    sha256(contents),
    expectedSha256,
    `unexpected upstream source hash for ${file}`,
  );
  return contents;
}

const baseSource = readVerified(
  baseMappingsPath,
  "8576ffef345b631a88ded0c47b9eaad3d6eb8856b4d2b4deebe4c40ba8ea6243",
);
const dynamicSource = readVerified(
  dynamicCalligraphicPath,
  "82ca048228884b6a1f551474ee73a38b42539a3e94e65aeb11d0db3d902e5363",
);
const dynamicDoubleStruckSource = readVerified(
  dynamicDoubleStruckPath,
  "493bf6b05b3eeacd4ceea0b55237680ff1f31563a750533df845cc7ce625726c",
);
const dynamicCyrillicSource = readVerified(
  dynamicCyrillicPath,
  "7a6c7d8b654b01bce1ec3dbf93aba1792d4908afd919889ed36cb72c7af173e1",
);
const fontSvgSource = readVerified(
  fontSvgPath,
  "709d6e85113ef44645ad802b8424508d5f836dd61e4d1f2797b5e011a9693734",
);

const importAnchor =
  'var lengths_js_1 = require("../../../util/lengths.js");';
const extraImports = String.raw`
var UnitUtil_js_1 = require("../UnitUtil.js");
var NodeUtil_js_1 = __importDefault(require("../NodeUtil.js"));
var TexParser_js_1 = __importDefault(require("../TexParser.js"));`;

const functionAnchor =
  "var THICKMATHSPACE = (0, lengths_js_1.em)(lengths_js_1.MATHSPACE.thickmathspace);";
const xArrowFunction = String.raw`

// ChatGPT Android phase 3: exact MathJax AMS xArrow implementation, embedded
// in the base map so \xrightarrow works without loading the absent AMS package.
var phase3XArrow = function (parser, name, chr, l, r, m) {
    if (m === void 0) { m = 0; }
    var def = {
        width: '+' + UnitUtil_js_1.UnitUtil.em((l + r) / 18),
        lspace: UnitUtil_js_1.UnitUtil.em(l / 18),
    };
    var bot = parser.GetBrackets(name);
    var first = parser.ParseArg(name);
    var dstrut = parser.create('node', 'mspace', [], { depth: '.2em' });
    var arrow = parser.create(
        'token',
        'mo',
        { stretchy: true, texClass: MmlNode_js_1.TEXCLASS.ORD },
        String.fromCodePoint(chr)
    );
    if (m) {
        arrow.attributes.set('minsize', UnitUtil_js_1.UnitUtil.em(m));
    }
    arrow = parser.create('node', 'mstyle', [arrow], { scriptlevel: 0 });
    var mml = parser.create('node', 'munderover', [arrow]);
    var mpadded = parser.create('node', 'mpadded', [first, dstrut], def);
    NodeUtil_js_1.default.setAttribute(mpadded, 'voffset', '-.2em');
    NodeUtil_js_1.default.setAttribute(mpadded, 'height', '-.2em');
    NodeUtil_js_1.default.setChild(mml, mml.over, mpadded);
    if (bot) {
        var bottom = new TexParser_js_1.default(
            bot,
            parser.stack.env,
            parser.configuration
        ).mml();
        var bstrut = parser.create('node', 'mspace', [], { height: '.75em' });
        mpadded = parser.create('node', 'mpadded', [bottom, bstrut], def);
        NodeUtil_js_1.default.setAttribute(mpadded, 'voffset', '.15em');
        NodeUtil_js_1.default.setAttribute(mpadded, 'depth', '-.15em');
        NodeUtil_js_1.default.setChild(mml, mml.under, mpadded);
    }
    NodeUtil_js_1.default.setProperty(mml, 'subsupOK', true);
    parser.Push(parser.create('node', 'TeXAtom', [
        parser.create('node', 'TeXAtom', [], {
            texClass: MmlNode_js_1.TEXCLASS.NONE,
        }),
        mml,
    ], { texClass: MmlNode_js_1.TEXCLASS.REL }));
};

// The app ships only MathJax's base TeX package.  Add the small, self-contained
// part of AMS that implements the ubiquitous nested aligned environment.
var phase3Aligned = function (
    parser,
    begin,
    numbered,
    taggable,
    align,
    balign,
    spacing,
    style
) {
    var brackets = parser.GetBrackets(
        '\\begin{' + begin.getName() + '}'
    );
    var array = BaseMethods_js_1.default.EqnArray(
        parser,
        begin,
        numbered,
        taggable,
        align,
        balign,
        spacing,
        style
    );
    return ParseUtil_js_1.ParseUtil.setArrayAlign(
        array,
        brackets,
        parser
    );
};

// Keep \operatorname native as well.  The official app omits the AMS package,
// but real mathematical explanations use this command frequently.
var phase3OperatorName = function (parser, name) {
    var star = parser.GetStar();
    var op = UnitUtil_js_1.UnitUtil.trimSpaces(parser.GetArgument(name));
    var env = Object.assign({}, parser.stack.env, {
        font: TexConstants_js_1.TexConstant.Variant.NORMAL,
        multiLetterIdentifiers: /^[-*a-zA-Z0-9]+/,
        operatorLetters: true,
        noAutoOP: true,
    });
    var mml = new TexParser_js_1.default(
        op,
        env,
        parser.configuration
    ).mml();
    if (mml.isKind('mi')) {
        mml.removeProperty('autoOP');
    } else {
        mml = parser.create('node', 'TeXAtom', [mml]);
    }
    NodeUtil_js_1.default.setProperties(mml, {
        movesupsub: star,
        movablelimits: true,
        texClass: MmlNode_js_1.TEXCLASS.OP,
    });
    if (!star) {
        var c = parser.GetNext();
        var i = parser.i;
        if (c === '\\' && ++parser.i && parser.GetCS() !== 'limits') {
            parser.i = i;
        }
    }
    parser.Push(parser.itemFactory.create('fn', mml));
};`;

const commandMapAnchor = "new sm.CommandMap('macros', {";
const xArrowMapping = String.raw`
    xrightarrow: [phase3XArrow, 0x2192, 5, 10],
    operatorname: phase3OperatorName,`;

const delimiterAnchor = String.raw`    '\\vert': ['|', { texClass: MmlNode_js_1.TEXCLASS.ORD }],`;
const delimiterMappings = String.raw`
    '\\lvert': ['\u007C', { texClass: MmlNode_js_1.TEXCLASS.OPEN }],
    '\\rvert': ['\u007C', { texClass: MmlNode_js_1.TEXCLASS.CLOSE }],
    '\\lVert': ['\u2016', { texClass: MmlNode_js_1.TEXCLASS.OPEN }],
    '\\rVert': ['\u2016', { texClass: MmlNode_js_1.TEXCLASS.CLOSE }],`;

const environmentAnchor =
  "new sm.EnvironmentMap('environment', ParseMethods_js_1.default.environment, {";
const alignedMapping = String.raw`
    aligned: [
        phase3Aligned,
        null,
        null,
        null,
        'rl',
        'bt',
        ParseUtil_js_1.ParseUtil.cols(0, 2),
        '.5em',
        'D',
    ],
    cases: [
        BaseMethods_js_1.default.Array,
        null,
        '\\{',
        '.',
        'll',
        null,
        '.2em',
        'T',
    ],`;

function replaceOnce(source, anchor, replacement) {
  assert.equal(
    source.split(anchor).length - 1,
    1,
    `expected exactly one anchor: ${anchor}`,
  );
  return source.replace(anchor, replacement);
}

assert.equal(baseSource.includes("xrightarrow:"), false);
assert.equal(baseSource.includes("operatorname:"), false);
let patchedBase = replaceOnce(
  baseSource,
  importAnchor,
  importAnchor + extraImports,
);
patchedBase = replaceOnce(
  patchedBase,
  functionAnchor,
  functionAnchor + xArrowFunction,
);
patchedBase = replaceOnce(
  patchedBase,
  commandMapAnchor,
  commandMapAnchor + xArrowMapping,
);
patchedBase = replaceOnce(
  patchedBase,
  delimiterAnchor,
  delimiterAnchor + delimiterMappings,
);
patchedBase = replaceOnce(
  patchedBase,
  environmentAnchor,
  environmentAnchor + alignedMapping,
);
patchedBase = replaceOnce(
  patchedBase,
  "//# sourceMappingURL=BaseMappings.js.map",
  "exports.BaseMappingsLoaded = true;\n" +
    "//# sourceMappingURL=BaseMappings.js.map",
);

let capturedDynamicData = null;
const sandbox = {
  exports: {},
  module: { exports: {} },
  require(specifier) {
    assert.equal(specifier, "../../svg.js");
    return {
      MathJaxNewcmFont: {
        dynamicSetup(prefix, name, data) {
          assert.equal(prefix, "");
          assert.equal(name, "calligraphic");
          assert.equal(capturedDynamicData, null);
          capturedDynamicData = data;
        },
      },
    };
  },
};
vm.runInNewContext(dynamicSource, sandbox, {
  filename: dynamicCalligraphicPath,
});

assert.ok(capturedDynamicData, "dynamicSetup was not called");
const regular = capturedDynamicData["-tex-calligraphic"];
const bold = capturedDynamicData["-tex-bold-calligraphic"];
assert.deepEqual(
  Object.keys(regular).map(Number),
  Array.from({ length: 26 }, (_, index) => 0x41 + index),
);
assert.deepEqual(
  Object.keys(bold).map(Number),
  Array.from({ length: 26 }, (_, index) => 0x41 + index),
);

let capturedDoubleStruckData = null;
const doubleStruckSandbox = {
  exports: {},
  module: { exports: {} },
  require(specifier) {
    assert.equal(specifier, "../../svg.js");
    return {
      MathJaxNewcmFont: {
        dynamicSetup(prefix, name, data) {
          assert.equal(prefix, "");
          assert.equal(name, "double-struck");
          assert.equal(capturedDoubleStruckData, null);
          capturedDoubleStruckData = data;
        },
      },
    };
  },
};
vm.runInNewContext(dynamicDoubleStruckSource, doubleStruckSandbox, {
  filename: dynamicDoubleStruckPath,
});
assert.ok(
  capturedDoubleStruckData,
  "double-struck dynamicSetup was not called",
);
const doubleStruckNormal = capturedDoubleStruckData.normal;
const doubleStruck = capturedDoubleStruckData["double-struck"];
assert.equal(Object.keys(doubleStruckNormal).length, 72);
assert.deepEqual(Object.keys(doubleStruck).map(Number), [0x131, 0x237]);

let capturedCyrillicData = null;
const cyrillicSandbox = {
  exports: {},
  module: { exports: {} },
  require(specifier) {
    assert.equal(specifier, "../../svg.js");
    return {
      MathJaxNewcmFont: {
        dynamicSetup(prefix, name, data) {
          assert.equal(prefix, "");
          assert.equal(name, "cyrillic");
          assert.equal(capturedCyrillicData, null);
          capturedCyrillicData = data;
        },
      },
    };
  },
};
vm.runInNewContext(dynamicCyrillicSource, cyrillicSandbox, {
  filename: dynamicCyrillicPath,
});
assert.ok(capturedCyrillicData, "cyrillic dynamicSetup was not called");
assert.deepEqual(
  Object.keys(capturedCyrillicData).sort(),
  ["bold", "bold-italic", "italic", "normal"],
);
for (const [variant, glyphs] of Object.entries(capturedCyrillicData)) {
  assert.ok(
    Object.keys(glyphs).length > 200,
    `unexpectedly small Cyrillic ${variant} table`,
  );
}

const phase3FontBootstrap = `
// Keep the archive's ABI-compatible precompiled font class.  Populate its
// static character tables before the first font instance is constructed, and
// remove only the two dynamic sentinels whose files are absent from the app.
var phase3FontClass = require("../../../../mathjax_font/svg.js").MathJaxNewcmFont;
var phase3FontData = ${JSON.stringify({
  calligraphic: regular,
  calligraphicBold: bold,
  doubleStruckNormal,
  doubleStruck,
  cyrillic: capturedCyrillicData,
})};
Object.assign(
    phase3FontClass.defaultChars['-tex-calligraphic'],
    phase3FontData.calligraphic
);
Object.assign(
    phase3FontClass.defaultChars['-tex-bold-calligraphic'],
    phase3FontData.calligraphicBold
);
Object.assign(
    phase3FontClass.defaultChars.normal,
    phase3FontData.doubleStruckNormal
);
Object.assign(
    phase3FontClass.defaultChars['double-struck'],
    phase3FontData.doubleStruck
);
for (var phase3CyrillicVariant in phase3FontData.cyrillic) {
    Object.assign(
        phase3FontClass.defaultChars[phase3CyrillicVariant],
        phase3FontData.cyrillic[phase3CyrillicVariant]
    );
}
delete phase3FontClass.dynamicFiles.calligraphic;
delete phase3FontClass.dynamicFiles['double-struck'];
delete phase3FontClass.dynamicFiles.cyrillic;
`;
patchedBase = replaceOnce(
  patchedBase,
  "exports.BaseMappingsLoaded = true;",
  phase3FontBootstrap + "\nexports.BaseMappingsLoaded = true;",
);

function staticFontModule(exportName, glyphs, extraExports = {}) {
  const assignments = [
    `exports.${exportName} = ${JSON.stringify(glyphs, null, 2)};`,
    ...Object.entries(extraExports).map(
      ([name, value]) =>
        `exports.${name} = ${JSON.stringify(value, null, 2)};`,
    ),
  ];
  return (
    '"use strict";\n' +
    'Object.defineProperty(exports, "__esModule", { value: true });\n' +
    assignments.join("\n") +
    "\n"
  );
}

// Valdi's source CommonJS loader appends ".js" while resolving a relative
// require. Upstream MathJax spells those imports with an explicit suffix,
// which would otherwise become "TokenMap.js.js" on Android.
function valdiCompatibleSource(source) {
  return source.replace(
    /require\((["'])(\.[^"']+)[.]js\1\)/g,
    "require($1$2$1)",
  );
}

function withValdiDiagnostics(label, source) {
  const strict = '"use strict";';
  assert.ok(source.startsWith(strict));
  return (
    strict +
    "\ntry {\n" +
    source.slice(strict.length) +
    "\n} catch (phase3Error) {\n" +
    `  console.error("${label}: " + String(phase3Error) + ` +
    `(phase3Error && phase3Error.stack ? "\\n" + phase3Error.stack : ""));\n` +
    "  throw phase3Error;\n" +
    "}\n"
  );
}

const fontDataImport =
  'var FontData_js_1 = require("@mathjax/src/cjs/output/svg/FontData.js");';
const archiveFontDataImport =
  'var FontData_js_1 = require("../mathjax_src/output/svg/FontData.js");';
const dynamicCalligraphicBlock = String.raw`        ['calligraphic', {
                '-tex-calligraphic': [
                    [0x41, 0x5A]
                ],
                '-tex-bold-calligraphic': [
                    [0x41, 0x5A]
                ]
            }],
`;
const normalCharsAnchor =
  "        'normal': normal_js_1.normal,";
const normalCharsWithDoubleStruck =
  "        'normal': __assign(__assign({}, normal_js_1.normal), " +
  "double_struck_js_1.doubleStruckNormal),";
const dynamicDoubleStruckStart = "        ['double-struck', {";
const dynamicDoubleStruckEnd = "        ['fraktur', {";

function removeRangeOnce(source, startAnchor, endAnchor) {
  const start = source.indexOf(startAnchor);
  assert.notEqual(start, -1, `missing range start: ${startAnchor}`);
  assert.equal(
    source.indexOf(startAnchor, start + 1),
    -1,
    `duplicate range start: ${startAnchor}`,
  );
  const end = source.indexOf(endAnchor, start);
  assert.notEqual(end, -1, `missing range end: ${endAnchor}`);
  return source.slice(0, start) + source.slice(end);
}

// Static A-Z glyphs alone are insufficient: MathJax's dynamic-file table
// replaces them with an async-load sentinel during FontData construction.
// Remove only that one sentinel range so the embedded glyph arrays are used.
let patchedFontSvg = replaceOnce(
  fontSvgSource,
  fontDataImport,
  archiveFontDataImport,
);
patchedFontSvg = replaceOnce(
  patchedFontSvg,
  dynamicCalligraphicBlock,
  "",
);
patchedFontSvg = replaceOnce(
  patchedFontSvg,
  normalCharsAnchor,
  normalCharsWithDoubleStruck,
);
patchedFontSvg = removeRangeOnce(
  patchedFontSvg,
  dynamicDoubleStruckStart,
  dynamicDoubleStruckEnd,
);

const outputs = new Map([
  [
    "src/mathjax_src/input/tex/base/BaseMappings.js",
    withValdiDiagnostics(
      "CHATGPT_PHASE3_BASEMAPPINGS",
      valdiCompatibleSource(patchedBase),
    ),
  ],
]);

const report = {};
for (const [relative, contents] of outputs) {
  const target = path.join(entriesRoot, ...relative.split("/"));
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.writeFileSync(target, contents, "utf8");
  report[relative] = {
    bytes: Buffer.byteLength(contents),
    sha256: sha256(contents),
    source_js: true,
  };
}

const phase3Hash = sha256(
  Array.from(outputs)
    .map(([relative, contents]) => `${relative}\0${contents}`)
    .join("\0"),
);
const hashTarget = path.join(entriesRoot, "hash");
fs.writeFileSync(hashTarget, phase3Hash, "utf8");
report.hash = {
  bytes: Buffer.byteLength(phase3Hash),
  sha256: sha256(phase3Hash),
  source_js: false,
  module_content_hash: phase3Hash,
};

const entriesRootResolved = path.resolve(entriesRoot);
for (const [relative, contents] of outputs) {
  const target = path.resolve(
    entriesRoot,
    ...relative.split("/"),
  );
  const relativeRequires = [];
  const requirePattern = /require\((["'])([^"']+)\1\)/g;
  for (const match of contents.matchAll(requirePattern)) {
    const specifier = match[2];
    if (!specifier.startsWith(".")) {
      continue;
    }
    const dependency = path.resolve(
      path.dirname(target),
      specifier.endsWith(".js") ? specifier : `${specifier}.js`,
    );
    assert.ok(
      dependency.startsWith(entriesRootResolved + path.sep),
      `relative require escapes archive root: ${relative} -> ${specifier}`,
    );
    assert.ok(
      fs.statSync(dependency).isFile(),
      `relative require is absent from archive: ${relative} -> ${specifier}`,
    );
    relativeRequires.push(specifier);
  }
  report[relative].relative_requires_verified = relativeRequires;
}

console.log(JSON.stringify(report, null, 2));
