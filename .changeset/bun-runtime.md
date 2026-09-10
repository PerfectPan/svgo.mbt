---
"@rivus/svgo": patch
---

Bun 1.4+ and Deno 2 are supported runtimes: the package and its CLI pass the full fixture suite under Node 24, Bun 1.4.2 and Deno 2.9, and CI now runs that suite under all three. Fixes the `svgo-mbt` CLI under Bun and Deno, which treated its own script path as an input file because the argument parser detected the JavaScript runtime by looking for "node" in `argv[0]`. Bun 1.2 lacks JS String Builtins and fails at instantiate.
