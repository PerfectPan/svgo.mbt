# svgo.mbt

**An SVG optimizer written in MoonBit, shipped as WebAssembly.**
All 34 plugins in [svgo](https://github.com/svg/svgo)'s preset-default, in its
order and with its semantics, and none of the Node.js dependency tree: a 200 KB
`wasm-gc` module that runs in the browser and in Node 24+, a CLI that installs
with `npx`, and a MoonBit library.

[**Website & playground**](https://perfectpan.github.io/svgo.mbt/) ·
[API reference](https://perfectpan.github.io/svgo.mbt/#/api) ·
[mooncakes.io](https://mooncakes.io/docs/PerfectPan/svgo) ·
[npm `@rivus/svgo`](https://www.npmjs.com/package/@rivus/svgo)

## Quickstart

**JavaScript** (Node 24+, Chrome 130+, Firefox 134+, Safari 18.4+; JS String Builtins need V8 13.6):

```bash
npm i @rivus/svgo
```

```js
import { optimize } from "@rivus/svgo";
const r = await optimize(svg, { precision: 3 });
r.data; r.originalSize; r.size; r.passes; r.applied;
```

**Command line**, without a toolchain (Node 24+):

```bash
npx @rivus/svgo input.svg -o out.svg
cat input.svg | npx @rivus/svgo > out.svg       # stdin, or pass "-" as the input
npx @rivus/svgo icons -r -o dist                # a directory, recursively
# installed (npm i -g @rivus/svgo) the command is `svgo-mbt`
```

**MoonBit**:

```bash
moon add PerfectPan/svgo
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

`Config` provides plugin selection, `params : Map[String, Json]`, precision, multipass, and pretty printing; see the [API reference](https://perfectpan.github.io/svgo.mbt/#/api) for all fields.

## Command line

```bash
svgo-mbt input.svg                            # optimized SVG on stdout
svgo-mbt input.svg -o out.svg --stats         # write a file, print size statistics
svgo-mbt input.svg -p 2 --pretty              # 2 decimal places, indented output
svgo-mbt input.svg --json                     # {data, originalSize, size, passes, applied}
svgo-mbt input.svg --plugins convertPathData,sortAttrs
svgo-mbt input.svg --param cleanupIds.preserve=logo,icon --param cleanupIds.minify=false
svgo-mbt input.svg --disable convertShapeToPath --enable moveGroupAttrsToElems
svgo-mbt --list                               # available plugins
```

Exit codes: 0 on success, 1 for a usage error, 2 when a file could not be parsed (the names go to stderr, so a shell loop can act on them).

`--param <plugin>.<key>=<value>` is repeatable. Values `true`/`false` become booleans, integers become numbers, comma-separated values become string arrays, and other values remain strings.

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

Optional: `removeDimensions`, `removeTitle`, `moveGroupAttrsToElems`.

Parameters use svgo's names and JSON shapes. Each plugin receives only its own object; omitted fields use these defaults:

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

`preserve` and `preservePrefixes` accept one string or an array of strings. `currentColor` accepts a boolean or an exact color string and does not replace colors inside masks. `preservePatterns` supports literal substring matches and `^`-prefixed literal prefix matches, **not full regular expressions**.

## Performance

Same Node process, both with multipass, milliseconds per call (`node packages/compare/collect.mjs`, Node 24, svgo 4.1.0):

| file | size | svgo.mbt (wasm-gc) | svgo-js | ratio |
| --- | ---: | ---: | ---: | ---: |
| sketch-icon.svg | 836 B | 0.119 | 0.319 | 2.7× |
| inkscape-drawing.svg | 2 KB | 0.188 | 0.669 | 3.6× |
| SVG_logo.svg | 4 KB | 0.579 | 1.674 | 2.9× |
| Tux.svg | 50 KB | 7.092 | 14.238 | 2.0× |
| Ghostscript_Tiger.svg | 68 KB | 12.485 | 36.016 | 2.9× |
| World map (low resolution) | 85 KB | 11.889 | 51.867 | 4.4× |

Between 1.7× and 4.4× depending on the file, 2.9× at the median. Cold start on a small icon, whole process (`scripts/cli-bench.sh`): native CLI about 10 ms, Node build about 50 ms, svgo CLI about 160 ms.

## Compatibility with svgo

Upstream cases (svgo e4cb29b, 2026-08-27):

| | cases |
| --- | --- |
| pass | 289 |
| known differences | 0 |
| skipped | 0 |

`moveGroupAttrsToElems` ships opt-in (`--enable moveGroupAttrsToElems`). Pushing a group's `transform` onto its children lets `convertPathData` bake the matrix into every path, which lengthens coordinates and leaves formerly identical siblings unmergeable. Across the test corpus files it costs 15,859 bytes on the Ghostscript tiger and saves 48 bytes across the rest. svgo shows the same effect on that file (68,101 bytes with the plugin, 52,029 without, against 52,690 for svgo.mbt).

svgo also has 19 opt-in plugins; `removeDimensions` and `removeTitle` are implemented, and the other 17 are not.

## Verification

```bash
scripts/verify.sh            # check, fmt, .mbti drift, fixtures, tests on js / native
scripts/verify.sh --full     # + wasm build, sizes vs svgo-js, resvg pixel diff, speed (needs pnpm install)
```

Runs unit tests, svgo's own fixture suite, resvg pixel diff, and byte-for-byte corpus checks. Details and developer guides: [docs/ARCHITECTURE.md](https://github.com/PerfectPan/svgo.mbt/blob/main/docs/ARCHITECTURE.md), [CONTRIBUTING.md](https://github.com/PerfectPan/svgo.mbt/blob/main/CONTRIBUTING.md), [AGENTS.md](https://github.com/PerfectPan/svgo.mbt/blob/main/AGENTS.md).

## License

MIT. Plugin semantics follow svgo (MIT, © Kir Belevich and contributors).
