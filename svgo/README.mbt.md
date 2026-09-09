# svgo.mbt

**An SVG optimizer written in MoonBit, shipped as WebAssembly.**
All 34 plugins in [svgo](https://github.com/svg/svgo)'s preset-default, in its
order and with its semantics, and none of the Node.js dependency tree: a 269 KB
`wasm-gc` module that runs in the browser and in Node 22+, a CLI that installs
with `npx`, and a MoonBit library.

[**Website & playground**](https://perfectpan.github.io/svgo.mbt/) ·
[API reference](https://perfectpan.github.io/svgo.mbt/api.html) ·
[mooncakes.io](https://mooncakes.io/docs/perfectpan/svgo) ·
[npm `svgo-mbt`](https://www.npmjs.com/package/svgo-mbt)

```
$ svgo testdata/sketch-icon.svg --stats
<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><title>icon/action/close</title><g fill="red" transform="translate(2 2)"><path stroke="red" stroke-linecap="round" stroke-width="2" d="M4 4l12 12M16 4 4 16"/><path d="M0 0h20v20H0z"/></g></svg>
testdata/sketch-icon.svg: 836 -> 276 bytes (-67%), 3 pass(es), plugins: removeXMLProcInst, removeComments, ...
```

## Why

Every front-end build runs an SVG optimizer (svgo-loader, SVGR,
vite-plugin-svgo, imagemin, icon pipelines) and every one of them pulls in
svgo plus Node. svgo.mbt is the same idea as a dependency-free artifact:
drop the wasm file next to your bundler, call it from a service worker, embed
the native binary in a CI image, or use the MoonBit packages directly.

Three properties drive the design:

- **Safe by construction and by test.** Plugins only remove what a renderer
  cannot observe; ids that are referenced anywhere survive; inherited
  defaults are only dropped when no ancestor overrides them. Every fixture is
  rasterized before and after with resvg and compared pixel by pixel.
- **Fast.** In one Node process the wasm build is 4 to 6 times faster than
  svgo-js on the same files; the native CLI starts about 40 times faster than
  the svgo CLI. Numbers below.
- **Plugins are values.** `{ name, description, run }`. The preset is an array
  in svgo's order; the CLI, the playground and the tests run any subset in
  any order.

## Install and use

**JavaScript** (Node 22+, Chrome 130+, Firefox 134+, Safari 18.4+):

```bash
npm i svgo-mbt
```

```js
import { optimize } from "svgo-mbt";
const r = await optimize(svg, { precision: 3 });
r.data; r.originalSize; r.size; r.passes; r.applied;
```

**Command line**, without a toolchain (Node 22+):

```bash
npx svgo-mbt input.svg -o out.svg
cat input.svg | npx svgo-mbt > out.svg          # stdin, or pass "-" as the input
npx svgo-mbt icons -r -o dist                   # a directory, recursively
```

Or build the native binary, which is the same MoonBit source with C file I/O
instead of node's `fs`:

```bash
moon build --target native --release          # -> $(scripts/bin-path.sh), under _build/native/release/
svgo-mbt input.svg                            # optimized SVG on stdout
svgo-mbt input.svg -o out.svg --stats         # write a file, print size statistics
svgo-mbt input.svg -p 2 --pretty              # 2 decimal places, indented output
svgo-mbt input.svg --json                     # {data, originalSize, size, passes, applied}
svgo-mbt input.svg --plugins convertPathData,sortAttrs
svgo-mbt input.svg --param cleanupIds.preserve=logo,icon --param cleanupIds.minify=false
svgo-mbt input.svg --disable convertShapeToPath --enable moveGroupAttrsToElems
svgo-mbt --list                               # available plugins
```

Exit codes: 0 on success, 1 for a usage error, 2 when a file could not be
parsed (the names go to stderr, so a shell loop can act on them).

`--param <plugin>.<key>=<value>` is repeatable. Values `true`/`false` become
booleans, integers become numbers, comma-separated values become string arrays,
and other values remain strings.

**MoonBit**:

```bash
moon add perfectpan/svgo
```

```mbt check
///|
test "optimize" {
  let result = @svgo.optimize(
    (
      #|<svg xmlns="http://www.w3.org/2000/svg" width="10px" height="10px">
      #|  <!-- Generator: Sketch -->
      #|  <g fill="#FF0000" stroke="none">
      #|    <rect x="0" y="0" width="10.000" height="10.000"/>
      #|  </g>
      #|</svg>
    ),
  )
  inspect(
    result.data,
    content=(
      #|<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"><path fill="red" d="M0 0h10v10H0z"/></svg>
    ),
  )
}
```

`Config` is a plain struct: plugin names in order, a `params : Map[String, Json]`
of per-plugin parameter objects, numeric precision,
multipass and pretty printing. Start from the default and override fields.

```mbt check
///|
test "config" {
  let config = { ..@svgo.Config::default(), precision: 1, pretty: true, }
  let r = @svgo.optimize(
    "<svg xmlns=\"http://www.w3.org/2000/svg\"><path d=\"M0.123 0.456 L 10 10\"/></svg>",
    config~,
  )
  inspect(
    r.data,
    content=(
      #|<svg xmlns="http://www.w3.org/2000/svg">
      #|  <path d="M.1.5 10 10"/>
      #|</svg>
      #|
    ),
  )
}
```

The `xml` and `path` packages are usable on their own, for example
`@path.optimize_string("M 0,0 L 10,10")` gives `"M0 0l10 10"`.

## Plugins

Enabled by default, in svgo's `preset-default` order:

| plugin | what it does |
| --- | --- |
| removeDoctype, removeXMLProcInst, removeComments, removeMetadata | strip the prolog and editor comments (`<!--! ... -->` legal comments are kept) |
| removeEditorsNSData | drop Inkscape / Sketch / Illustrator / Figma namespaces, elements and attributes |
| cleanupAttrs, removeDesc, cleanupIds, removeUselessDefs | normalise whitespace, drop `Created with ...` descriptions, unused ids and unreferenced `<defs>` children |
| cleanupNumericValues | round numbers, remove `px` |
| convertColors | `rgb()` / names / `#RRGGBB` to the shortest form |
| mergeStyles, inlineStyles, minifyStyles | merge `<style>` elements, inline matching rules to `style="..."`, minify CSS and drop unused selectors |
| removeUnknownsAndDefaults | drop attributes equal to their defaults, unless an ancestor overrides them |
| removeDeprecatedAttrs | drop attributes the SVG spec deprecated, keeping the ones that still render |
| removeNonInheritableGroupAttrs | drop presentation attributes off a `<g>` that children cannot inherit |
| removeUselessStrokeAndFill | drop `stroke-*` when nothing is stroked, `fill-*` when nothing is filled |
| cleanupEnableBackground | drop `enable-background` unless a filter uses `BackgroundImage` |
| removeHiddenElems, removeEmptyText | zero-size shapes, `display:none`, empty paths and texts |
| convertShapeToPath, convertEllipseToCircle | `rect` / `line` / `polyline` / `polygon` to `path`, equal-radius ellipses to circles |
| moveElemsAttrsToGroup | lift an attribute every child shares onto their group |
| collapseGroups | unwrap groups and push their attributes down |
| convertPathData | element transforms baked into the data, curve runs to arcs, relative/absolute per segment, `H`/`V`/`S`/`T` shorthands, straight curves to lines, precision with drift compensation |
| convertTransform | multiply, decompose and round transform lists, drop identity and redundant ones |
| mergePaths | join adjacent paths with identical attributes when their outlines do not intersect |
| removeEmptyAttrs, removeEmptyContainers, removeUnusedNS, sortAttrs, sortDefsChildren | final cleanup |

Optional: `removeDimensions`, `removeTitle`, `moveGroupAttrsToElems` (see the
deviation noted under compatibility).

Every plugin in svgo's preset-default is implemented.

## Performance

Same Node process, both with multipass, milliseconds per call
(`node packages/compare/collect.mjs`, Node 22, svgo 4.1.0):

| file | size | svgo.mbt (wasm-gc) | svgo-js | ratio |
| --- | ---: | ---: | ---: | ---: |
| sketch-icon.svg | 836 B | 0.066 | 0.295 | 4.5× |
| inkscape-drawing.svg | 2 KB | 0.116 | 0.661 | 5.7× |
| SVG_logo.svg | 4 KB | 0.265 | 1.719 | 6.5× |
| Tux.svg | 50 KB | 3.5 | 14.5 | 4.1× |
| Ghostscript_Tiger.svg | 68 KB | 7.8 | 38.1 | 4.9× |
| World map (low resolution) | 85 KB | 9.1 | 53.0 | 5.8× |

In-module (`scripts/bench.sh`, native release): the Tiger takes 6.8 ms end to
end, of which parsing is 0.23 ms and path data optimization 1.7 ms per pass.
`benchmark/README.md` has the stage breakdown and the history of what made it
fast.

Output sizes are on par: svgo.mbt wins on path-heavy files (Tiger 53.7 KB vs
68.1 KB) and loses 5 to 13% on style-heavy files until `inlineStyles` and
`minifyStyles` exist.

## Verifying correctness

```bash
scripts/verify.sh            # check, fmt, .mbti drift, fixtures, tests on wasm-gc / js / native
scripts/verify.sh --full     # + wasm build, sizes vs svgo-js, resvg pixel diff, speed (needs pnpm install)
scripts/regress.sh <ref-dir> # byte-for-byte output comparison against a reference build
```

Five layers: unit and snapshot tests per package; our own svgo-style fixture
files (`svgo/plugins/fixtures/*.txt`, one plugin each); **svgo's own plugin
test suite**, copied verbatim into `svgo/plugins/fixtures/upstream/` and run
with svgo's rules (one plugin, twice, both results must match); a corpus that
must reproduce byte for byte across refactors; and a render diff that
rasterizes every fixture before and after. Details in `docs/ARCHITECTURE.md`.

### Compatibility with svgo, measured

Two numbers matter here, and they answer different questions.

**Do the implemented plugins behave like svgo?** Yes, on svgo's own cases for
them (svgo e4cb29b, 2026-08-27):

| | cases |
| --- | --- |
| pass | 289 |
| known differences | 0 |
| skipped | 0 |

All 289 match byte for byte, including the rules that rewrite geometry:
element transforms baked into the path data, curve runs turned into arcs,
adjacent paths merged, groups collapsed. `fixtures/upstream/KNOWN_FAILURES.txt`
is empty and the harness fails the build if a case starts failing again, so an
entry there is a regression rather than a new baseline.

<<<<<<< HEAD
**Is the pipeline complete?** Yes for `preset-default`: all 34 plugins are
implemented, 33 of them on by default, plus `removeDimensions` and
`removeTitle`, which svgo keeps opt-in. Nothing is skipped, so every imported
case runs on every test run.

One deliberate deviation: `moveGroupAttrsToElems` is implemented and passes
svgo's cases, but it ships opt-in (`--enable moveGroupAttrsToElems`). Pushing a
group's `transform` onto its children lets `convertPathData` bake the matrix
into every path, which lengthens coordinates and leaves formerly identical
siblings unmergeable. Over the eleven files in `svgo/testdata/` and
`packages/compare/corpus/` it costs 15,859 bytes on the Ghostscript tiger and
saves 48 bytes across the rest. svgo shows the same effect on that file (68,101
bytes with the plugin, 52,029 without), so this is a size choice, not a
compatibility gap.

svgo also has 17 opt-in plugins (88 further cases) that are not imported at all,
and its parser, stringifier, style and CLI unit tests are not imported either
since they cover svgo's internals rather than its output.
=======
**Is the pipeline complete?** Not yet. svgo's `preset-default` runs 34 plugins;
svgo.mbt runs 28 of them plus `removeDimensions` and `removeTitle`, which svgo
keeps opt-in. The cases for the six missing plugins are imported too and
generated as skipped tests, so the gap shows up in every test run:

| missing plugin | cases | what it would take |
| --- | --- | --- |
| `moveElemsAttrsToGroup` | 7 | attribute motion across a group boundary, with inheritance rules |
| `moveGroupAttrsToElems` | 6 | same |
| `removeDeprecatedAttrs` | 8 | a table lookup |
| `cleanupEnableBackground` | 5 | one deprecated attribute |
| `removeNonInheritableGroupAttrs` | 2 | drop non-inheritable presentation attributes off a group |
| `sortDefsChildren` | 1 | sort the children of `<defs>` |

That is 29 skipped cases against 260 passing, and deleting a plugin's entry
from `NOT_IMPLEMENTED` in `scripts/gen-fixtures.py` makes its cases live. svgo
also has 17 opt-in plugins (88 further cases) that are not imported at all, and
its parser, stringifier, style and CLI unit tests are not imported either since
they cover svgo's internals rather than its output.
>>>>>>> 24e327c (plugins: a CSS module and the three style plugins (upstream 209 → 260 cases))

## Repository layout

A MoonBit workspace (`moon.work`) and a pnpm workspace side by side:

```
svgo/                 the MoonBit module: xml/ path/ plugins/ (+ fixtures) svgo.mbt wasm/ benchmark/ testdata/
packages/svgo-mbt/    npm package: JS loader + svgo.wasm + the CLI bin
packages/compare/     svgo-js comparison, resvg render diff, same-process speed, site numbers
app/website/          the website: a MoonBit (Rabbita) app that imports svgo/, Tailwind v4, Remotion hero
app/cli/              the CLI: a MoonBit executable that imports svgo/, C file I/O on native
scripts/              build-wasm, build-cli, verify, bench, regress, gen-fixtures
```

`AGENTS.md` is the guide for coding agents (commands, invariants, conventions);
`CONTRIBUTING.md` explains how to add a plugin or a fixture.

## License

MIT. Plugin semantics follow svgo (MIT, © Kir Belevich and contributors).

### Plugin parameters

Parameters use svgo's names and JSON shapes. Each plugin receives only its own
object; omitted fields use these defaults:

| Plugin | Parameters and defaults |
| --- | --- |
| cleanupIds | `remove: true`, `minify: true`, `preserve: []`, `preservePrefixes: []`, `force: false` |
| convertColors | `currentColor: false`, `names2hex: true`, `rgb2hex: true`, `shorthex: true`, `shortname: true` |
| convertShapeToPath | `convertArcs: false`, `floatPrecision`: config precision |
| convertTransform | `floatPrecision`: config precision (3), `transformPrecision: 5` (limited to matrix precision), `degPrecision`: derived from matrix digits and float precision |
| removeComments | `preservePatterns: ["^!"]`; `false` or `[]` removes all comments |
| removeUnknownsAndDefaults | `unknownContent`, `unknownAttrs`, `defaultAttrs`, `uselessOverrides`, `keepDataAttrs`, `keepAriaAttrs`: all `true`; `keepRoleAttr: false` |
| removeUselessStrokeAndFill | `stroke: true`, `fill: true`, `removeNone: false` |
| sortAttrs | `xmlnsOrder: "front"`; `order: ["id", "width", "height", "x", "x1", "x2", "y", "y1", "y2", "cx", "cy", "r", "fill", "stroke", "marker", "d", "points"]` |

`preserve` and `preservePrefixes` accept one string or an array of strings.
`currentColor` accepts a boolean or an exact color string and does not replace
colors inside masks. `preservePatterns` supports literal substring matches and
`^`-prefixed literal prefix matches, **not full regular expressions**.
