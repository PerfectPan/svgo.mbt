---
"@rivus/svgo": patch
---

Faster and smaller: optimizing is about 15% faster on typical editor exports (wasm-gc, Node), and the wasm module is about 5 KB smaller because it takes shortest number formatting from the host (`String`) instead of shipping its own. Output is unchanged.
