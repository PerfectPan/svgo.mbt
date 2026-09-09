#!/usr/bin/env node
// One version for the whole repo. changesets bumps packages/svgo-mbt/package.json;
// this copies that version into the MoonBit side (moon.mod files, the CLI's
// --version, the wasm's version() export). `--check` only reports drift and
// exits 1; verify.sh runs that.
import { readFileSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { join } from "node:path";

const ROOT = fileURLToPath(new URL("..", import.meta.url));
const check = process.argv.includes("--check");
const version = JSON.parse(readFileSync(join(ROOT, "packages/svgo-mbt/package.json"), "utf8")).version;

// [file, pattern whose first capture group is the version]
const targets = [
  ["svgo/moon.mod", /^version = "([^"]+)"/m],
  ["app/website/moon.mod", /"PerfectPan\/svgo@([^"]+)"/],
  ["app/cli/moon.mod", /"PerfectPan\/svgo@([^"]+)"/],
  ["app/cli/main.mbt", /^const VERSION = "([^"]+)"/m],
  ["svgo/wasm/wasm.mbt", /pub fn version\(\) -> String \{\n  "([^"]+)"/],
];

let drift = 0;
for (const [file, pattern] of targets) {
  const path = join(ROOT, file);
  const text = readFileSync(path, "utf8");
  const match = pattern.exec(text);
  if (!match) throw new Error(`${file}: version pattern not found`);
  if (match[1] === version) continue;
  drift++;
  if (check) {
    console.error(`${file}: ${match[1]} (package.json says ${version})`);
  } else {
    const updated = text.slice(0, match.index) + match[0].replace(match[1], version) + text.slice(match.index + match[0].length);
    writeFileSync(path, updated);
    console.log(`${file}: ${match[1]} -> ${version}`);
  }
}
if (check && drift) process.exit(1);
if (!drift) console.log(`all at ${version}`);
