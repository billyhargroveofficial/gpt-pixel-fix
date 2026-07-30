"use strict";

Object.defineProperty(exports, "__esModule", { value: true });
exports.renderMathSvg = renderMathSvg;

var originalRenderer = require("dil_math/src/renderMathSvgOriginal");
var renderCallCount = 0;

function summarize(value) {
  var text = String(value);
  text = text.replace(/\s+/g, " ");
  return text.length > 96 ? text.slice(0, 96) + "..." : text;
}

function renderMathSvg() {
  renderCallCount += 1;
  var callId = renderCallCount;
  var startedAt = Date.now();
  var expression = arguments.length > 0 ? arguments[0] : "";
  console.warn(
    "CHATGPT_PHASE5_RENDER_BEGIN id=" +
      callId +
      " args=" +
      arguments.length +
      " tex=" +
      summarize(expression),
  );

  try {
    var output = originalRenderer.renderMathSvg.apply(
      originalRenderer,
      arguments,
    );
    console.warn(
      "CHATGPT_PHASE5_RENDER_OK id=" +
        callId +
        " ms=" +
        (Date.now() - startedAt) +
        " hasOutput=" +
        Boolean(output) +
        " svgBytes=" +
        (output && output.svg ? String(output.svg).length : -1) +
        " width=" +
        (output && output.width !== undefined ? output.width : "missing") +
        " height=" +
        (output && output.height !== undefined ? output.height : "missing"),
    );
    return output;
  } catch (error) {
    console.error(
      "CHATGPT_PHASE5_RENDER_ERROR id=" +
        callId +
        " ms=" +
        (Date.now() - startedAt) +
        " error=" +
        String(error) +
        (error && error.stack ? "\n" + error.stack : ""),
    );
    throw error;
  }
}
