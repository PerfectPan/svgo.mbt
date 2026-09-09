# svgo-mbt

WebAssembly build of [svgo.mbt](https://github.com/PerfectPan/svgo.mbt), an
SVG optimizer written in MoonBit: all 34 plugins in svgo's preset-default, in its order and with its semantics.
One 200 KB `wasm-gc` file plus a 2 KB loader, no other dependencies.

```bash
npm i svgo-mbt          # the library
npx svgo-mbt in.svg -o out.svg   # the command line tool, no install
```

```js
import { optimize, plugins } from "svgo-mbt";

const r = await optimize(svgText, {
  precision: 3,        // decimal places (default 3)
  multipass: true,     // repeat until stable (default true)
  pretty: false,       // indent output (default false)
  // plugins: ["removeComments", "convertPathData", ...]  // explicit list, in order
});
r.data;          // optimized SVG
r.originalSize;  // bytes in
r.size;          // bytes out
r.passes;        // pipeline passes
r.applied;       // plugins that changed something

await plugins(); // [{ name, description, enabled }]
```

## Command line

The bin is the same optimizer compiled for node, so it needs no toolchain:

```bash
npx svgo-mbt in.svg -o out.svg
cat in.svg | npx svgo-mbt > out.svg   # stdin, or pass "-" as the input
npx svgo-mbt icons -r -o dist         # a directory, recursively
npx svgo-mbt in.svg --stats           # size statistics on stderr
npx svgo-mbt in.svg --json            # {data, originalSize, size, passes, applied}
npx svgo-mbt --list                   # available plugins
```

Exit codes: 0 on success, 1 for a usage error, 2 when a file could not be
parsed, with the failing names on stderr.

In a browser the module is fetched relative to the loader; pass your own URL
to `init(url)` before the first `optimize` call if you host it elsewhere.

Requires WebAssembly GC and JS String Builtins: Node 22+, Chrome 130+,
Firefox 134+, Safari 18.4+.

Same-process timings against svgo 4.1 (ms per call, both multipass): a Sketch
icon 0.07 vs 0.30, a 50 KB Inkscape drawing 3.5 vs 14.5, the 68 KB
Ghostscript Tiger 7.8 vs 38. Playground and details:
<https://perfectpan.github.io/svgo.mbt/>.

MIT.

Plugin entries may also be objects, for example:

```js
await optimize(svg, {
  plugins: [{ name: "cleanupIds", params: { preserve: ["logo"], minify: false } }],
});
```

Top-level `params: { cleanupIds: { preserve: ["logo"] } }` works with either
the default preset or an explicit plugin list. An entry's `params` object takes
precedence over the top-level object for that plugin. Missing parameters use
plugin defaults. `removeComments.preservePatterns` supports literal substrings
and `^`-prefixed literal prefixes, not full regular expressions.
