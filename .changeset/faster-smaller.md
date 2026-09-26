---
"@rivus/svgo": patch
---

Faster and smaller: `optimize` is 8 to 17% faster on typical editor exports (wasm-gc, Node 24), and the wasm module is 12.8 KB smaller (188 KB, 69 KB gzipped). The module now also imports `String` from the host for shortest number formatting; the bundled loader provides it. Output is unchanged.
