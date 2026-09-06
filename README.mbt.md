# svgo.mbt

An SVG optimizer written in MoonBit, modelled on [svgo](https://github.com/svg/svgo).
It parses an SVG, runs a pipeline of plugins that strip editor noise and
rewrite the document into its shortest equivalent form, and serializes it
back, without changing what the image looks like.

It is built WebAssembly-first: the primary artifact is a 160 KB `wasm-gc`
module with a tiny JavaScript loader (`npm/`), which runs in Node 22+ and in
current browsers at native speed. The same source also compiles to a native
CLI and to plain JavaScript.

```bash
scripts/build-wasm.sh                          # -> npm/svgo.wasm
node -e 'import("./npm/index.mjs").then(async m => {
  const r = await m.optimize(require("fs").readFileSync("testdata/sketch-icon.svg","utf8"));
  console.log(r.originalSize, "->", r.size); })'
python3 -m http.server 8765 & open http://localhost:8765/playground/   # browser playground
moon run --target native cmd/main -- testdata/sketch-icon.svg --stats  # native CLI
```

```
<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><title>icon/action/close</title><g fill="red" transform="translate(2 2)"><path stroke="red" stroke-linecap="round" stroke-width="2" d="M4 4l12 12M16 4 4 16"/><path d="M0 0h20v20H0z"/></g></svg>
testdata/sketch-icon.svg: 776 -> 245 bytes (-68.4%), 2 pass(es), plugins: ...
```

## Why

Every front-end build pipeline runs an SVG optimizer (svgo-loader, SVGR,
vite-plugin-svgo, imagemin, icon libraries). The MoonBit ecosystem has 59
packages that produce or render SVG and none that shrinks it. `svgo.mbt` is
that missing piece, and unlike the original it ships as a dependency-free
binary or Wasm module instead of a Node.js dependency tree.

The second goal is **verifiable safety**: `harness/render-diff.mjs` rasterizes
every fixture before and after optimisation and counts differing pixels, so an
optimisation that changes the picture fails the check instead of reaching
users.

## Plugins

Enabled by default, in pipeline order (svgo's `preset-default` order):

| plugin | what it does |
| --- | --- |
| removeDoctype, removeXMLProcInst, removeComments, removeMetadata | strip the prolog and editor comments (`<!--! ... -->` legal comments are kept) |
| removeEditorsNSData | drop Inkscape / Sketch / Illustrator / Figma namespaces, elements and attributes |
| cleanupAttrs, removeDesc, cleanupIds, removeUselessDefs | normalise whitespace, drop `Created with ...` descriptions, unused ids and unreferenced `<defs>` children |
| cleanupNumericValues | round numbers, remove `px` |
| convertColors | `rgb()`/names/`#RRGGBB` to the shortest form |
| removeUnknownsAndDefaults | drop attributes equal to their defaults, unless an ancestor overrides them |
| removeUselessStrokeAndFill | drop `stroke-*` when nothing is stroked, `fill-*` when nothing is filled |
| removeHiddenElems, removeEmptyText | zero-size shapes, `display:none`, empty paths and texts |
| convertShapeToPath, convertEllipseToCircle | `rect`/`line`/`polyline`/`polygon` to `path`, equal-radius ellipses to circles |
| collapseGroups | unwrap groups and push their attributes down |
| convertPathData | relative/absolute per segment, `H`/`V`/`S`/`T` shorthands, straight curves to lines, precision control with drift compensation |
| convertTransform | round transform arguments and remove identity transforms |
| mergePaths | join adjacent paths with identical attributes when their bounding boxes do not overlap |
| removeEmptyAttrs, removeEmptyContainers, removeUnusedNS, sortAttrs | final cleanup |

Optional: `removeDimensions`, `removeTitle` (`--enable`).

Not implemented yet compared to svgo: `inlineStyles`, `minifyStyles`,
`mergeStyles`, `moveElemsAttrsToGroup`, `moveGroupAttrsToElems`,
`convertTransform` matrix folding, `applyTransforms` on path data,
`removeNonInheritableGroupAttrs`, `cleanupEnableBackground`, `prefixIds`.

## Usage

CLI (native):

```bash
svgo input.svg                        # optimized SVG on stdout
svgo input.svg -o out.svg --stats     # write a file, print size statistics
svgo input.svg -p 2 --pretty          # 2 decimal places, indented output
svgo input.svg --disable convertShapeToPath --enable removeDimensions
svgo --list                           # available plugins
```

Library:

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

Configuration is a plain struct: plugin names in order, numeric precision,
multipass and pretty printing.

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

## Performance

Same Node process, multipass on both sides, ms per optimisation
(`node harness/wasm-speed.mjs`; `moon run --target wasm-gc --release cmd/bench`
gives the in-module numbers without the JS boundary):

| file | svgo.mbt (wasm-gc) | svgo 4.1 (JS) |
| --- | --- | --- |
| sketch-icon.svg, 0.8 KB | 0.37 | 0.55 |
| inkscape-drawing.svg, 2 KB | 0.33 | 1.12 |
| SVG_logo.svg, 4 KB | 1.66 | 2.20 |
| Tux.svg, 50 KB | 16.0 | 16.8 |
| Ghostscript_Tiger.svg, 68 KB | 47.4 | 53.8 |
| World map, 85 KB | 66.8 | 83.1 |

Small icons, the common case in front-end builds, are 1.5 to 10 times faster
depending on how the boundary is measured; large files are on par. Cold start
of the native CLI is about 40x faster than the svgo CLI because there is no
Node runtime to boot.

## Verifying correctness

```bash
harness/compare.sh            # sizes: original vs svgo.mbt vs svgo (Node)
cd harness && npm install && cd ..
node harness/render-diff.mjs  # rasterize before/after with resvg, count differing pixels
```

## Design notes

- `xml`: a small SVG-oriented parser that keeps whitespace inside text-like
  elements, decodes entities and preserves comments, CDATA and the prolog.
- `path`: path data parser and printer plus the optimizer. Relative
  coordinates are computed against the *rounded* current point, so rounding
  errors never accumulate along a long path.
- `plugins`: each plugin is a value `{ name, description, run }`; `run`
  reports whether it changed the tree, which drives multipass.
- Multipass is on by default (svgo's is off), so plugins that unlock each
  other, for example `collapseGroups` followed by
  `removeUnknownsAndDefaults`, converge.

## Roadmap

1. CSS: `minifyStyles` and `inlineStyles` on top of a CSS parser.
2. `applyTransforms`: bake `translate`/`scale` into path data.
3. Run svgo's plugin fixtures as a conformance suite and publish the numbers.
4. Browser playground (wasm-gc) and an npm package (js backend).

## License

MIT. Plugin semantics follow svgo (MIT, © Kir Belevich and contributors).
