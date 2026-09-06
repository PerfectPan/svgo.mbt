# svgo-mbt

WebAssembly build of [svgo.mbt](https://github.com/PerfectPan/svgo.mbt), an
SVG optimizer written in MoonBit with svgo's preset-default plugin pipeline.
One 165 KB `wasm-gc` file plus a 2 KB loader, no other dependencies.

```bash
npm i svgo-mbt
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

In a browser the module is fetched relative to the loader; pass your own URL
to `init(url)` before the first `optimize` call if you host it elsewhere.

Requires WebAssembly GC and JS String Builtins: Node 22+, Chrome 130+,
Firefox 134+, Safari 18.4+.

Same-process timings against svgo 4.1 (ms per call, both multipass): a Sketch
icon 0.07 vs 0.30, a 50 KB Inkscape drawing 3.5 vs 14.5, the 68 KB
Ghostscript Tiger 7.8 vs 38. Playground and details:
<https://perfectpan.github.io/svgo.mbt/>.

MIT.
