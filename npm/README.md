# svgo-mbt

WebAssembly build of [svgo.mbt](https://github.com/PerfectPan/svgo.mbt), an SVG
optimizer written in MoonBit.

```js
import { optimize } from "svgo-mbt";

const { data, originalSize, size } = await optimize(svgText, { precision: 3 });
```

Requires a runtime with WebAssembly GC and JS String Builtins: Node 22+,
Chrome 130+, Firefox 134+, Safari 18.4+.
