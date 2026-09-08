import assert from "node:assert/strict";
import test from "node:test";
import { optimize } from "./index.mjs";

const svg = '<svg><path id="logo"/><path id="unused"/><use href="#logo"/></svg>';

test("wasm accepts object plugin entries and top-level params", async () => {
  const options = { preserve: ["unused"], minify: false };
  const inline = await optimize(svg, {
    plugins: [{ name: "cleanupIds", params: options }],
  });
  const topLevel = await optimize(svg, {
    plugins: ["cleanupIds"],
    params: { cleanupIds: options },
  });
  assert.equal(inline.data, svg);
  assert.deepEqual(inline, topLevel);
  assert.equal(inline.passes, 1);
});

test("entry params override top-level params without leaking to later calls", async () => {
  const result = await optimize(svg, {
    plugins: [{ name: "cleanupIds", params: { minify: false } }],
    params: { cleanupIds: { remove: false, minify: true } },
  });
  assert.equal(result.data, '<svg><path id="logo"/><path/><use href="#logo"/></svg>');
  const defaults = await optimize(svg, { plugins: ["cleanupIds"] });
  assert.equal(defaults.data, '<svg><path id="a"/><path/><use href="#a"/></svg>');
});

test("mixed plugin entries preserve order and scalar/array parameter types", async () => {
  const result = await optimize('<svg><!--!legal--><path fill="#aabbcc"/></svg>', {
    plugins: ["removeComments", { name: "convertColors", params: { shorthex: false } }],
    params: { removeComments: { preservePatterns: false } },
  });
  assert.equal(result.data, '<svg><path fill="#aabbcc"/></svg>');
  await assert.rejects(optimize("<svg/>", { plugins: [{ name: "unknown", params: {} }] }), /unknown plugin/);
});
