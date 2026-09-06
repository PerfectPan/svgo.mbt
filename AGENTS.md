# svgo.mbt — guide for coding agents

An SVG optimizer in MoonBit, compatible in spirit with svgo's preset-default.
Everything below is what an agent needs to work here without re-deriving it.
Human-facing docs: `README.mbt.md` (usage), `docs/ARCHITECTURE.md` (design),
`CONTRIBUTING.md` (how to add a plugin or fixture).

## Repository shape

This is a workspace: `moon.work` (members: `svgo/`) for MoonBit and pnpm
(`pnpm-workspace.yaml`) for the JavaScript side. Run `moon` commands from the
repo root; they apply to every workspace member. `pnpm install` once at the
root installs every JS package.

## Commands

| goal | command |
| --- | --- |
| type check every package on the default backend | `moon check` |
| run all tests (unit tests plus generated fixtures) | `moon test --target native` (also `wasm-gc`, `js`) |
| update snapshot expectations after an intended output change | `moon test --update` |
| format and refresh the generated `.mbti` interface files | `moon fmt && moon info` |
| everything CI checks, in one go | `scripts/verify.sh` (`--full` adds wasm build, svgo-js comparison, render diff) |
| micro benchmarks as a table | `scripts/bench.sh [native\|wasm-gc\|js] [bench_test.mbt\|profile_test.mbt]` |
| byte-for-byte output comparison against a reference build | `scripts/regress.sh <dir>` (see CONTRIBUTING) |
| regenerate `svgo/plugins/fixtures_test.mbt` from `svgo/plugins/fixtures/*.txt` | `python3 scripts/gen-fixtures.py` |
| native CLI | `moon run --target native svgo/cmd/main -- file.svg --stats` (`--json`, `--plugins a,b`) |
| wasm artifact for `packages/svgo-mbt` and the site | `scripts/build-wasm.sh` |
| compare with svgo-js (sizes, render diff, speed) | `pnpm compare` (or the scripts in `packages/compare/`) |
| refresh the numbers on the site | `node packages/compare/collect.mjs` → `site/data.json` |
| API docs data (also what mooncakes.io renders) | `moon -C svgo doc` → `_build/doc/` |
| build the site into `_build/site` | `pnpm site` (= `moon -C svgo doc && node site/build.mjs`) |
| re-render the hero animation | `pnpm -C site motion:render` |
| publish the MoonBit module | `cd svgo && moon publish` |

## Layout

```
moon.work, package.json       workspace roots (MoonBit members / pnpm packages), .npmrc pins registry.npmjs.org
svgo/                         the MoonBit module perfectpan/svgo
  svgo.mbt, svgo_test.mbt     public API: optimize(svg, config?) -> Result, Config, list_plugins
  xml/                        Document/Node/Element, parse, serialize (SVG-oriented, keeps prolog)
  path/                       path data: parse, optimize, stringify; number.mbt = fast number I/O
  plugins/                    Plugin { name, description, run }, Context, preset_default order
    cleanup.mbt               removal plugins (doctype, comments, editor data, ids, empty things)
    values.mbt                numeric values and colours
    structure.mbt             tree rewrites: defaults, groups, shapes->path, path data, merging
    transform.mbt             transform attribute simplification
    preset.mbt                preset_default / optional_plugins / find_plugin
    fixtures/*.txt            input @@@ expected [@@@ params] — regenerated into fixtures_test.mbt
  cmd/main/                   native CLI (C file I/O in io.c; stubs keep other targets checking)
  wasm/                       foreign_library exporting optimize/plugins/version as JSON strings
  benchmark/                  moon bench tests over an embedded corpus (corpus.mbt is generated)
  testdata/                   editor exports used by tests, the render diff and the site gallery
packages/svgo-mbt/            npm package: JS loader + svgo.wasm (built by scripts/build-wasm.sh)
packages/compare/             svgo-js comparison: sizes, resvg pixel diff, same-process speed, collect.mjs
site/                         landing page + playground + API reference (Tailwind v4, built by build.mjs)
  src/style.css               Tailwind entry: @theme tokens + component layer used by the JS-rendered markup
  motion/                     Remotion composition for the hero video (pnpm -C site motion:render)
scripts/                      build-wasm, verify, bench, regress, gen-fixtures
docs/ARCHITECTURE.md          design notes
```

## Invariants (tests enforce these; keep them)

1. **Rendering is preserved.** A plugin may only remove or rewrite what a
   conforming renderer cannot observe at the configured precision. When in
   doubt, keep the element/attribute. `packages/compare/render-diff.mjs` must
   stay at 0 differing pixels on `svgo/testdata/` except for sub-pixel precision effects.
2. **Plugins return whether they changed the tree.** That boolean drives
   multipass; returning `true` without a change makes every run take 10 passes.
3. **Every plugin is independently runnable** via `Config::plugins` /
   `--plugins`, in any order, on any document, without raising.
4. **Deterministic, idempotent output.** Optimizing the output again must
   produce the same bytes (`scripts/regress.sh` and the corpus check this).
5. **No target-specific code outside `svgo/cmd/main/io_native.mbt` and `svgo/wasm/`.**
   The library compiles unchanged to wasm-gc, js and native.

## Conventions

- Code blocks separated by `///|`; doc comments on every `pub` item (the
  site's API reference is generated from them).
- Derive `Debug`, not `Show`, for data; implement `Show` only for errors.
- Tests: `inspect(value, content=...)` snapshots for outputs, `assert_eq` for
  invariant checks. New plugin behaviour gets a fixture file first, then a
  unit test if the logic is subtle.
- Lookups in hot paths use `Set`/`Map`, never linear `Array::contains` over
  string lists. Measure with `scripts/bench.sh` before and after; the
  numbers in `svgo/benchmark/README.md` are the reference.
- MoonBit specifics that bite: `String::compare` is length-first (use
  `lexical_compare`); `s[a:b]` is a `StringView`, `.to_owned()` to keep it;
  `for k, v in map` iterates key/value but `for i, x in array` is index/value;
  `Map`/`Set` literals are `Map([])`/`Set([])`; `@env.now()` is milliseconds.

## Adding a plugin (short version, details in CONTRIBUTING.md)

1. Write `pub let my_plugin : Plugin = { name: "svgoName", description, run }`
   in the matching `svgo/plugins/*.mbt` file. `run` mutates the `@xml.Document` and
   returns `true` iff it changed anything.
2. Add it to `preset_default` (in svgo's order) or `optional_plugins`.
3. Add `svgo/plugins/fixtures/svgoName.01.txt`, run `python3 scripts/gen-fixtures.py`,
   then `moon test`.
4. Document it in the README plugin table; `moon fmt && moon info`.
