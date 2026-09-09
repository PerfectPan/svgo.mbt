# Architecture

svgo.mbt is a pipeline: **parse → plugins (repeat until stable) → serialize**.
Every stage is a separate MoonBit package with a small public surface, so
each can be used, tested and benchmarked on its own.

```
          ┌────────┐    Document     ┌──────────────────┐   Document   ┌───────────┐
  String ─┤  @xml  ├────────────────▶│ @plugins (×pass) ├─────────────▶│   @xml    ├─▶ String
          │ parse  │                 │ 25 × run(doc,ctx)│              │ serialize │
          └────────┘                 └───────┬──────────┘              └───────────┘
                                             │ d="..."
                                       ┌─────▼─────┐
                                       │   @path   │  parse → optimize → stringify
                                       └───────────┘
```

## Packages

### `xml` — a DOM for SVG, not a general XML parser

`Document { children }` holds the prolog nodes and one root `Element`.
`Element { mut name, attrs : Map[String, String], children : Array[Node] }`.
`Map` preserves insertion order, so attribute order survives round trips
until `sortAttrs` decides otherwise.

Design decisions:

- **Whitespace policy is svgo's.** Text between tags is dropped unless the
  element is text-like (`text`, `tspan`, `style`, `title`, ...), in which
  case it is kept verbatim. This is what makes compact output safe.
- **Entities are decoded on input and re-escaped on output**, so plugins see
  real characters (`&` not `&amp;`) and never need to think about escaping.
- **Comments, CDATA, doctype and processing instructions are nodes**, so the
  removal plugins are one-liners and legal comments (`<!--! ... -->`) can be
  kept.
- Parsing dispatches on the code unit after `<`, slices tokens as
  substrings, and never backtracks: 68 KB parses in about 0.25 ms.

### `path` — the numeric core

`Segment { cmd : Char, args : Array[Double] }` is the canonical form; implicit
command repetition is expanded on parse and re-folded on print.

`optimize` walks the segments keeping two current points: the **exact** one
from the input, and the **rounded** one the consumer of the output will be
at. Relative coordinates are computed against the rounded point, so rounding
error never accumulates along a long path (the classic drift bug when
converting to relative coordinates). For every segment it measures the
absolute and the relative spelling and emits the shorter one; `M` prefers
absolute on ties because it usually starts a subpath far from the current
point.

`number.mbt` is why the optimizer is fast:

- `scan_number` folds up to 15 significant digits into an `Int64` and applies
  a single exact power-of-ten division. No substring, no general float parser.
- `decompose` turns a double into sign / integer part / fraction digits once;
  `write_number_shaped` prints from that and returns a packed "shape" (length,
  starts with `-`, starts with `.`, has `.`) so the separator rules and the
  abs-vs-rel length comparison never build strings.

### `plugins` — svgo's preset-default as values

```moonbit
pub(all) struct Plugin { name : String; description : String; run : (Document, Context) -> Bool }
```

A plugin is data, not a class: the preset is an array literal, the CLI and
the wasm export list it, and tests run any subset in any order. `run`
returns whether it changed the tree; the driver repeats the whole pipeline
while any plugin reports a change (at most 10 passes). Multipass is on by
default because plugins unlock each other: `collapseGroups` exposes
attributes that `removeUnknownsAndDefaults` can then drop, `convertShapeToPath`
produces paths that `mergePaths` can join.

SVG vocabulary tables retain svgo's shared groups in compact strings generated
by `scripts/gen-svg-tables.mjs`. The handwritten `svg_tables_parse.mbt` parses
groups on first use and expands each element's rules only when queried; both
levels are cached. Color maps use the same string-pair decoder and lazy caches.
This avoids emitting thousands of repeated Map/Set construction instructions.

`Context` carries the precision, the current plugin's JSON parameters, and run-level caches: path data that
`convertPathData` already left unchanged. The optimizer is idempotent on such
data, so later passes skip it; this is what keeps a 3-pass run on a
path-heavy file close to the cost of a single pass.

Safety rules that recur across plugins:

- anything with an `id` that is referenced (`url(#id)`, `href="#id"`,
  `begin="id.click"`, `<style>` text) is never removed or restyled;
- inherited presentation attributes equal to their default are only dropped
  when no ancestor overrides them;
- `mergePaths` requires identical attributes and non-overlapping bounding
  boxes, so fill rules cannot interact.

### `svgo` (root) — the API

`optimize(svg, config?) -> Result raise` wires the three packages together.
`Config` is a plain struct (plugin names in order, per-plugin JSON parameter
objects, precision, multipass,
pretty); `Result` has the output plus byte sizes, pass count and the plugins
that did something. `utf8_length` counts bytes without encoding.

### Delivery forms

| form | package | notes |
| --- | --- | --- |
| wasm-gc module + JS loader | `svgo/wasm/`, `packages/svgo-mbt/` | JS String Builtins: MoonBit `String` *is* a JS string, so the boundary is two string arguments and one string back. Config and result cross as length-prefixed tokens rather than JSON, and trig plus the slow path of number parsing are host imports (`svgo/path/host_wasm.mbt`), so the module carries no JSON, strconv or fdlibm code: about 200 KB after the pinned Binaryen `wasm-opt -Oz --converge` step, down from 269 KB. |
| CLI | `app/cli/` | One MoonBit source, two IO backends: `extern "C"` file access on the native target, node's `fs` on the js target, which is what `packages/svgo-mbt/cli.mjs` ships. `--json` for tooling. |
| MoonBit library | `svgo/` | `moon add perfectpan/svgo`. The website in `app/website/` is the first consumer: a Rabbita app compiled to JS that calls `@svgo.optimize` directly, so the demo and the playground run the same code the tests run. |

## Verification layers

1. **Unit and snapshot tests** in each package (`moon test` on js and native; the wasm-gc artifact runs the same fixture suite under node, see `packages/svgo-mbt/fixtures.test.mjs`).
2. **Fixtures** (`svgo/plugins/fixtures/*.txt`, svgo's `@@@` format) generated into
   a test file; one plugin at a time.
3. **Corpus regression** (`scripts/regress.sh`): byte-identical output across
   refactors.
4. **Render diff** (`packages/compare/render-diff.mjs`): resvg rasterizes before and
   after, pixelmatch counts differences.
5. **Benchmarks** (`moon bench`, `scripts/bench.sh`): per-file and
   per-plugin timings; `packages/compare/wasm-speed.mjs` for the same-process
   comparison with svgo-js.

## What is deliberately not here

- Matrix folding in `convertTransform` and `applyTransforms` on path data.
  Both are correctness-sensitive; they come with render-diff coverage or not at all.
