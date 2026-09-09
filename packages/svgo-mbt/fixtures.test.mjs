// The plugin fixture suite, run through the shipped wasm instead of `moon test`.
// `moon test` covers the js and native targets; the wasm-gc build takes trig
// and slow number parsing from the host (svgo/path/host_wasm.mbt), so this is
// the run that exercises those imports. Semantics mirror scripts/gen-fixtures.py
// and svgo/plugins/fixtures_support_test.mbt: one plugin per case, upstream
// cases run twice (once for the single-pass plugins) and must match after
// every run, whitespace between tags is ignored.
import assert from "node:assert/strict";
import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";
import { optimize } from "./index.mjs";

const FIXTURES = fileURLToPath(new URL("../../svgo/plugins/fixtures", import.meta.url));
const UPSTREAM = join(FIXTURES, "upstream");
const SINGLE_PASS = new Set(["addAttributesToSVGElement", "convertTransform"]);

const knownFailures = new Set(
  readFileSync(join(UPSTREAM, "KNOWN_FAILURES.txt"), "utf8")
    .split("\n")
    .map((line) => line.trim())
    .filter((line) => line && !line.startsWith("#"))
    .map((line) => line.split("#")[0].trim()),
);

/** Drop whitespace around tags, like `compact` in fixtures_support_test.mbt. */
function compact(s) {
  let out = "";
  let pending = "";
  let afterTag = false;
  let inComment = false;
  const t = s.trim();
  for (let i = 0; i < t.length; ) {
    const c = t[i];
    if (c === "\n" || c === "\r" || c === "\t" || c === " ") {
      if (!afterTag && !inComment) pending += " ";
      i += 1;
      continue;
    }
    if (c !== "<" && pending.length > 0) out += pending;
    pending = "";
    if (c === "<" && t.startsWith("<!--", i)) {
      inComment = true;
      out += "<!--";
      i += 4;
      continue;
    }
    if (inComment && t.startsWith("-->", i)) {
      inComment = false;
      out += "-->";
      afterTag = true;
      i += 3;
      continue;
    }
    afterTag = c === ">";
    out += c;
    i += 1;
  }
  return out;
}

const listCases = (dir) =>
  readdirSync(dir)
    .filter((name) => name.endsWith(".txt") && name !== "KNOWN_FAILURES.txt")
    .sort()
    .map((name) => ({ name: name.replace(/\.txt$/, ""), plugin: name.split(".")[0], text: readFileSync(join(dir, name), "utf8") }));

for (const { name, plugin, text } of listCases(FIXTURES)) {
  test(`fixture ${name}`, async () => {
    const sections = text.split("\n@@@\n").map((s) => s.replace(/^\n+|\n+$/g, ""));
    const params = sections[2]?.trim() ? JSON.parse(sections[2]) : {};
    const result = await optimize(sections[0], {
      plugins: [plugin],
      params: { [plugin]: params },
      precision: params.precision ?? 3,
      multipass: params.multipass === true,
    });
    assert.equal(compact(result.data), compact(sections[1]));
  });
}

for (const { name, plugin, text } of listCases(UPSTREAM)) {
  test(`upstream ${name}`, async () => {
    const items = text.split(/\s*===\s*/);
    const body = items.length === 2 ? items[1] : items[0];
    const parts = body.split(/\s*@@@\s*/);
    const params = parts[2]?.trim() ? JSON.parse(parts[2]) : {};
    const want = compact(parts[1]);
    const passes = SINGLE_PASS.has(plugin) ? 1 : 2;
    let current = parts[0];
    let problem = null;
    try {
      for (let i = 0; i < passes && problem === null; i++) {
        current = (
          await optimize(current, {
            plugins: [plugin],
            params: { [plugin]: params },
            precision: params.floatPrecision ?? 3,
            multipass: false,
          })
        ).data;
        if (compact(current) !== want) problem = `pass ${i + 1}: got ${compact(current)}`;
      }
    } catch (e) {
      problem = `error: ${e.message}`;
    }
    if (knownFailures.has(name)) {
      assert.notEqual(problem, null, "case now passes: remove it from KNOWN_FAILURES.txt");
    } else {
      assert.equal(problem, null);
    }
  });
}
