# svgo.mbt — guide for coding agents

An SVG optimizer in MoonBit, compatible in spirit with svgo's preset-default.
Everything below is what an agent needs to work here without re-deriving it.
Human-facing docs: `README.mbt.md` (usage), `docs/ARCHITECTURE.md` (design),
`CONTRIBUTING.md` (how to add a plugin or fixture), `docs/DESIGN.md` (website
guidelines: voice, layout, type scale, tokens, interaction; every site change follows it).

## Repository shape

This is a workspace: `moon.work` (members: `svgo/`, `app/website`, `app/cli`) for MoonBit and pnpm
(`pnpm-workspace.yaml`) for the JavaScript side. Run `moon` commands from the
repo root; they apply to every workspace member. `pnpm install` once at the
root installs every JS package.

## Commands

| goal | command |
| --- | --- |
| type check every package on the default backend | `moon check` |
| run all tests (unit tests plus generated fixtures) | `moon test --target native` (also `js`; not `wasm-gc`: moonrun lacks the `Math` / `Number` imports of `svgo/path/host_wasm.mbt`, the wasm artifact is tested with `node --test` in `packages/svgo-mbt`) |
| update snapshot expectations after an intended output change | `moon test --update` |
| format and refresh the generated `.mbti` interface files | `moon fmt && moon info` |
| everything CI checks, in one go | `scripts/verify.sh` (`--full` adds wasm build, svgo-js comparison, render diff) |
| CLI cold start (native / node build / svgo CLI), the numbers quoted on the site | `scripts/cli-bench.sh [file] [runs]` |
| micro benchmarks as a table | `scripts/bench.sh [native\|js] [bench_test.mbt\|profile_test.mbt]` |
| byte-for-byte output comparison against a reference build | `scripts/regress.sh <dir>` (see CONTRIBUTING) |
| regenerate `svgo/plugins/fixtures_test.mbt` from `svgo/plugins/fixtures/**/*.txt` | `python3 scripts/gen-fixtures.py` (prints pass / known-failure / skipped counts) |
| regenerate compact SVG tables from an svgo checkout | `node scripts/gen-svg-tables.mjs <svgo-dir>` |
| native CLI | `moon run --target native app/cli -- file.svg --stats` (`--json`, `--plugins a,b`) |
| wasm artifact for `packages/svgo-mbt` and the site | `scripts/build-wasm.sh` (release + pinned wasm-opt; run `pnpm install` first) |
| compare with svgo-js (sizes, render diff, speed) | `pnpm compare` (or the scripts in `packages/compare/`) |
| refresh the numbers on the site | `node packages/compare/collect.mjs` → `app/website/data.json` |
| API docs data (also what mooncakes.io renders) | `pnpm docs` (= `MOON_WORK=off moon -C svgo doc`, workspace mode off because the app member is js-only) → `svgo/_build/doc/` |
| build the site into `_build/app` | `pnpm app` (= `pnpm docs && node app/website/build.mjs`; needs `moon install moonbit-community/warren`) |
| dev server with live reload | `pnpm dev` → http://localhost:4173 (warren dev + tailwind --watch) |
| regenerate the site's data files | `node app/website/gen.mjs` (after collect.mjs or moon doc changed) |
| re-render the hero animation | `pnpm -C app/website motion:render` |
| record a user-visible change for the changelog | `pnpm changeset` in the PR (writes `.changeset/*.md`) |
| release (npm via OIDC, then native binaries + GitHub release + mooncakes) | release PR: `pnpm version-packages` (changesets bump + `scripts/sync-version.mjs` copies the version into the MoonBit modules), merge it; `release.yml` publishes to npm and tags `@rivus/svgo@X.Y.Z`, `binaries.yml` does the rest (needs the `MOONCAKES_TOKEN` secret). Rehearse with `gh workflow run release.yml -f dry_run=true`. See CONTRIBUTING.md "Releasing". |

## Layout

```
moon.work, package.json       workspace roots (MoonBit members / pnpm packages), .npmrc pins registry.npmjs.org
svgo/                         the MoonBit module PerfectPan/svgo
  svgo.mbt, svgo_test.mbt     public API: optimize(svg, config?) -> Result, Config, list_plugins
  xml/                        Document/Node/Element, parse, serialize (SVG-oriented, keeps prolog)
  path/                       path data: parse, optimize, stringify; number.mbt = fast number I/O; host_wasm.mbt / host_default.mbt = trig and slow number parsing per target
  plugins/                    Plugin { name, description, run }, Context (+ params.mbt accessors), preset_default order
    cleanup.mbt               removal plugins (doctype, comments, editor data, ids, empty things)
    values.mbt                numeric values and colours
    structure.mbt             tree rewrites: defaults, groups, shapes->path, path data, merging
    transform.mbt             transform attribute simplification
    preset.mbt                preset_default / optional_plugins / find_plugin
    fixtures/*.txt            input @@@ expected [@@@ params JSON] — regenerated into fixtures_test.mbt
    fixtures/upstream/        svgo's preset-default cases, verbatim; KNOWN_FAILURES.txt = expected failures (ratchet, only shrinks); unwritten plugins' cases are skipped via NOT_IMPLEMENTED in gen-fixtures.py
  wasm/                       foreign_library exporting optimize/plugins/version; strings cross as length-prefixed tokens (no JSON in the wasm), decoded by packages/svgo-mbt/index.mjs
  benchmark/                  moon bench tests over an embedded corpus (corpus.mbt is generated)
  testdata/                   editor exports used by tests, the render diff and the site gallery
packages/svgo-mbt/            npm package @rivus/svgo (bin `svgo-mbt`): JS loader + svgo.wasm (built by scripts/build-wasm.sh)
packages/compare/             svgo-js comparison: sizes, resvg pixel diff, same-process speed, collect.mjs
app/website/                  the website, itself a MoonBit module (PerfectPan/svgo-website) built with Rabbita
  main/                       browser entry (js backend), mounts ui.app
  ui/                         pages and components; data.mbt / samples.mbt / api_data.mbt are generated by gen.mjs
                              i18n.mbt: every user-facing string is t(en, zh); browser.mbt: the only JS (extern) bindings
                              lz.mbt: lz-string port for share links; highlight.mbt: lossless SVG lexer for the editors
  public/                     index.html shell, hero video, favicon; style.css is built by Tailwind
  src/style.css               Tailwind v4 entry: @theme tokens + component layer, @source "../ui"
  motion/                     Remotion composition for the hero video (pnpm -C app/website motion:render)
  build.mjs / dev.mjs         tailwind + gen + warren build / warren dev with live reload
app/cli/                      the CLI, itself a MoonBit module (PerfectPan/svgo-cli)
  main.mbt                    argument parsing and the optimize/print loop
  params.mbt                  --param plugin.key=value parser
  io_native.mbt / io.c        C file I/O for the native backend
  io_stub.mbt                 stubs so the package type-checks on wasm
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
   Plugin parameters use svgo's names and JSON shapes: `Config::params`
   (plugin name → JSON object), wasm `plugins: [{name, params}]` or top-level
   `params`, CLI `--param plugin.key=value`. Inside a plugin read them only via
   `ctx.param_bool/int/string/strings(name, default)`; defaults are svgo's.
4. **Deterministic, idempotent output.** Optimizing the output again must
   produce the same bytes (`scripts/regress.sh` and the corpus check this).
5. **No target-specific code outside `app/cli/io_native.mbt`, `svgo/wasm/` and
   `svgo/path/host_*.mbt`.** The library compiles unchanged to wasm-gc, js and
   native. The `host_*` pair is the one exception: on wasm-gc the
   transcendentals and the slow path of number parsing are host imports
   (`Math`, `Number.parseFloat`), which keeps about 20 KB of core out of the
   artifact; the other targets call core. Keep it to pure functions with
   identical results.

## Conventions

- Code blocks separated by `///|`; doc comments on every `pub` item (the
  site's API reference is generated from them).
- Derive `Debug`, not `Show`, for data; implement `Show` only for errors.
- Tests: `inspect(value, content=...)` snapshots for outputs, `assert_eq` for
  invariant checks. New plugin behavior gets a fixture file first, then a
  unit test if the logic is subtle. After any plugin change run
  `python3 scripts/gen-fixtures.py && moon test --target native -p PerfectPan/svgo/plugins`:
  an upstream case that starts passing fails with "now passes: remove it from
  KNOWN_FAILURES.txt"; delete that line in the same change. Never add lines
  to KNOWN_FAILURES.txt without a reason. Cases whose plugin does not exist yet
  are imported anyway and skipped through `NOT_IMPLEMENTED` in
  `scripts/gen-fixtures.py`; when you write one of those plugins, delete its
  entry there so its cases run.
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
