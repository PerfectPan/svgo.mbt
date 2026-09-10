# @rivus/svgo

## 0.2.0

### Minor Changes

- [#20](https://github.com/PerfectPan/svgo.mbt/pull/20) [`c8dd16e`](https://github.com/PerfectPan/svgo.mbt/commit/c8dd16ee9849e62c313937044cf99c783dab71e3) Thanks [@PerfectPan](https://github.com/PerfectPan)! - MoonBit module: public API reduced to the documented surface (Config, Result, optimize, list_plugins; xml Document/Element/Node/parse; path Options/Segment/PathError/parse/optimize/stringify/optimize_string/apply_matrix/has_geometry; plugins Plugin/Context/preset_default/optional_plugins/find_plugin). Helpers that were public by accident are now internal.

### Patch Changes

- [#12](https://github.com/PerfectPan/svgo.mbt/pull/12) [`271a4bc`](https://github.com/PerfectPan/svgo.mbt/commit/271a4bc9d80c3ee0c06b425eddb586ea0e327d3a) Thanks [@PerfectPan](https://github.com/PerfectPan)! - Bun 1.4+ and Deno 2 are supported runtimes: the package and its CLI pass the full fixture suite under Node 24, Bun 1.4.2 and Deno 2.9, and CI now runs that suite under all three. Fixes the `svgo-mbt` CLI under Bun and Deno, which treated its own script path as an input file because the argument parser detected the JavaScript runtime by looking for "node" in `argv[0]`. Bun 1.2 lacks JS String Builtins and fails at instantiate.

## 0.1.3

### Patch Changes

- Renamed from `svgo-mbt` to `@rivus/svgo`; the command line tool keeps its `svgo-mbt` name. Nothing else changed.
