# svgo.mbt — guide for coding agents

An SVG optimizer in MoonBit, compatible in spirit with svgo's preset-default.
Everything below is what an agent needs to work here without re-deriving it.
Human-facing docs: `README.mbt.md` (usage), `docs/ARCHITECTURE.md` (design),
`CONTRIBUTING.md` (how to add a plugin or fixture, which changes need a Spec or
Plan, PR rules, releasing), `docs/DESIGN.md` (website guidelines: voice, layout,
type scale, tokens, interaction; every site change follows it), `docs/README.md`
(what belongs in `docs/`).

## Repository shape

This is a workspace: `moon.work` (members: `svgo/`, `app/website`, `app/cli`) for MoonBit and pnpm
(`pnpm-workspace.yaml`) for the JavaScript side. Run `moon` commands from the
repo root; they apply to every workspace member. `pnpm install` once at the
root installs every JS package.

## Commands

| goal | command |
| --- | --- |
| type check every package on the default backend | `moon check` |
| run all tests (unit tests plus generated fixtures) | `moon test --target native` (also `js`; not `wasm-gc`: moonrun lacks the `Math` / `Number` imports of `svgo/internal/num/host_wasm.mbt`, the wasm artifact is tested with `node --test` in `packages/svgo-mbt`) |
| update snapshot expectations after an intended output change | `moon test --update` |
| format and refresh the generated `.mbti` interface files | `moon fmt && moon info` |
| everything CI checks, in one go | `scripts/verify.sh` (`--full` adds wasm build, svgo-js comparison, render diff) |
| repository hygiene: required files, tracked artifacts, secrets, personal paths, PR/MR template drift | `./scripts/check-repository.sh` (the `Review` workflow runs it too) |
| install the pre-commit hook (whitespace, staged repository check, `moon check`) | `./scripts/install-git-hooks.sh` |
| check a PR title / PR description before opening or editing a PR | `./scripts/check-pr-title.sh "<title>"` / `./scripts/check-pr-body.sh <file>` (or stdin) |
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
| record a user-visible change for the changelog | `pnpm changeset` in the PR (writes `.changeset/*.md`) |
| release (npm via OIDC, then native binaries + GitHub release + mooncakes) | `release.yml` opens the release PR (branch `changeset-release/main`, from `pnpm version-packages`: changesets bump + `scripts/sync-version.mjs`) whenever changesets are pending on main. To release: `gh pr close <n> && gh pr reopen <n>` so CI runs on it (a bot-opened PR gets no CI by itself), then merge; `release.yml` publishes to npm and tags `@rivus/svgo@X.Y.Z`, `binaries.yml` does the rest (needs the `MOONCAKES_TOKEN` secret). Rehearse with `gh workflow run release.yml -f dry_run=true`. See CONTRIBUTING.md "Releasing". |

## Layout

```
LICENSE                       GPL-3.0-only; svgo/LICENSE is a copy for the mooncakes module
THIRD_PARTY_NOTICES.md        MIT notices for code and data from svgo (ported plugins, fixtures) and lz-string; copied to svgo/
moon.work, package.json       workspace roots (MoonBit members / pnpm packages), .npmrc pins registry.npmjs.org
svgo/                         the MoonBit module PerfectPan/svgo
  svgo.mbt, svgo_test.mbt     public API: optimize(svg, config?) -> Result, Config (custom plugins via Config::custom), list_plugins
  xml/                        Document/Node/Element, parse, serialize (SVG-oriented, keeps prolog)
  path/                       path data: Segment, PathError, parse, optimize, stringify, apply_matrix, has_geometry
  internal/num/               number I/O, trig; host_wasm.mbt / host_default.mbt = trig and slow number parsing per target
  internal/css/               CSS parser, minifier and selector matcher (used by inlineStyles)
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
  public/                     index.html shell, favicon, og.jpg (social card), fonts; style.css is built by Tailwind
  samples/                    the SVGs the site optimizes (Nib mascot, three model logos); SOURCES.md has provenance and licences
  src/style.css               Tailwind v4 entry: @theme tokens + component layer, @source "../ui"
  shots.mjs                   full-page screenshots of _build/app for design review (see docs/DESIGN.md)
  build.mjs / dev.mjs         tailwind + gen + warren build / warren dev with live reload
app/cli/                      the CLI, itself a MoonBit module (PerfectPan/svgo-cli)
  main.mbt                    argument parsing, help, --list and the optimize/print loop
  report.mbt                  the stderr size report: terminal detection (TTY, NO_COLOR, locale, COLUMNS), units, columns
  params.mbt                  --param plugin.key=value parser
  io_native.mbt / io.c        C file I/O, isatty and a monotonic clock for the native backend (io_js.mbt: the node equivalents)
  io_stub.mbt                 stubs so the package type-checks on wasm
scripts/                      build-wasm, verify, bench, regress, gen-fixtures; check-repository, check-pr-title,
                              check-pr-body, install-git-hooks, configure-github-repository (shared project template)
.githooks/pre-commit          installed by scripts/install-git-hooks.sh
docs/ARCHITECTURE.md          design notes; docs/README.md lists the current-state docs
docs/specs/, docs/plans/      active Specs (behavior) and Plans (technical decisions + execution plan); see CONTRIBUTING
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
   `svgo/internal/num/host_*.mbt`.** The library compiles unchanged to wasm-gc, js and
   native. The `host_*` pair is the one exception: on wasm-gc the
   transcendentals, the slow path of number parsing and shortest number
   formatting are host imports (`Math`, `Number.parseFloat`, `String`), which
   keeps about 25 KB of core out of the artifact; the other targets call core.
   Keep it to pure functions with identical results.

## Conventions

- Code blocks separated by `///|`; doc comments on every `pub` item (the
  site's API reference is generated from them).
- Derive `Debug`, not `Show`, for data; implement `Show` only for errors.
  A pub type's trait methods (`x.to_string()`, `x.to_repr()`, `x.equal(y)`) are
  methods only with an explicit `pub extend T with Trait::{...}` next to the type;
  the compiler warns about the old implicit promotion.
- Blackbox tests (`*_test.mbt`) call the package under test with its prefix
  (`@plugins.find_plugin`); an unqualified call is a warning.
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

## Changes and pull requests

- Pick artifacts with the Change Design Gate in `CONTRIBUTING.md`: a plugin
  addition or fix needs only the requirement in the PR plus fixtures; a
  refactor across packages or targets needs a Plan in `docs/plans/`; public
  API, CLI, npm interface or website features need a Spec in `docs/specs/`
  plus a Plan. Do not start a Plan that is blocked on an unresolved decision;
  after delivery move lasting constraints into `docs/ARCHITECTURE.md`, the
  invariants above, or tests, and delete the finished Spec/Plan.
- Commit messages and PR titles are English `type(scope): summary` with types
  `feat fix docs style refactor perf test build ci chore revert`. Areas are
  scopes: `perf(bench):`, `test(compare):`, `feat(site):`, `fix(<pluginName>):`.
- PR descriptions keep every section of `.github/pull_request_template.md`,
  list the exact validation commands and skipped gates, and carry no
  "Generated with <tool>" lines. Run `./scripts/check-pr-title.sh` and
  `./scripts/check-pr-body.sh` before `gh pr create` or editing the body.
- Keep the GitHub PR and GitLab MR templates identical apart from PR/MR wording.
- Release notes come from changesets: record each user-visible change with
  `pnpm changeset` in the same PR, and changesets writes
  `packages/svgo-mbt/CHANGELOG.md` at release time. Never edit that generated
  changelog by hand or add a hand-written root `CHANGELOG.md`.

## Adding a plugin (short version, details in CONTRIBUTING.md)

1. Write `pub let my_plugin : Plugin = { name: "svgoName", description, run }`
   in the matching `svgo/plugins/*.mbt` file. `run` mutates the `@xml.Document` and
   returns `true` iff it changed anything.
2. Add it to `preset_default` (in svgo's order) or `optional_plugins`.
3. Add `svgo/plugins/fixtures/svgoName.01.txt`, run `python3 scripts/gen-fixtures.py`,
   then `moon test`.
4. Document it in the README plugin table; `moon fmt && moon info`.
