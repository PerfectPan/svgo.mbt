# @rivus/svgo

## 0.3.1

### Patch Changes

- [#35](https://github.com/PerfectPan/svgo.mbt/pull/35) [`212f198`](https://github.com/PerfectPan/svgo.mbt/commit/212f198e088ee613ba414796a10f8cd4b49ea88c) Thanks [@PerfectPan](https://github.com/PerfectPan)! - minifyStyles now packs numbers in `style` attributes and `<style>` rules the way svgo's csso does (`6.000000` → `6`, `0.450000` → `.45`, `0.0px` → `0`), so Inkscape-style exports come out as small as with svgo.

- [#36](https://github.com/PerfectPan/svgo.mbt/pull/36) [`6df47c2`](https://github.com/PerfectPan/svgo.mbt/commit/6df47c2767cc2acc6bed8ff8abbee08bc59c072f) Thanks [@PerfectPan](https://github.com/PerfectPan)! - Plugin descriptions (`plugins()`, `svgo-mbt --list`) are now written the same way throughout: lower-case imperative, such as "remove comments" or "move common attributes of group children to the group".

## 0.3.0

### Minor Changes

- [#33](https://github.com/PerfectPan/svgo.mbt/pull/33) [`be64760`](https://github.com/PerfectPan/svgo.mbt/commit/be647606ffc3336ba67ce7da618ed951f86fe3e7) Thanks [@PerfectPan](https://github.com/PerfectPan)! - CLI: writing files with `-o` now prints a size report on stderr by default: aligned rows with human units (`836 B → 276 B  −67%`), a totals line with the elapsed time for several files, and for a single file the plugins that changed it. With the SVG on stdout the report stays opt-in (`--stats`); `-q` silences it and `--json` is unchanged. A failed file gets one line, `svgo-mbt: path: message`, plus a `failed` row and a count in the totals. `--list` groups plugins under `preset-default` and `optional`, `--bench` prints per-run timing with sub-millisecond resolution, and `-h` carries the version, the real command name `svgo-mbt` and one exit status per line. Colour appears only on a terminal: `NO_COLOR` turns it off, `FORCE_COLOR` turns it on for pipes, and stdout is never styled.

- [#33](https://github.com/PerfectPan/svgo.mbt/pull/33) [`be64760`](https://github.com/PerfectPan/svgo.mbt/commit/be647606ffc3336ba67ce7da618ed951f86fe3e7) Thanks [@PerfectPan](https://github.com/PerfectPan)! - MoonBit library: `Config::custom` runs your own `@plugins.Plugin` values next to the built-in ones. A name in `Config::plugins` resolves to a custom plugin first, so a custom plugin can run at any position or replace a built-in; custom plugins no name refers to run last. Parameters, multipass and `applied` treat them like built-ins, and `Context::param_bool`, `param_int`, `param_string`, `param_strings` and `has_param` are now public for reading parameters. Code that builds a `Config` with a full record literal needs the new field (`..Config::default()` covers it). The npm package runs only the built-in plugins.

### Patch Changes

- [#31](https://github.com/PerfectPan/svgo.mbt/pull/31) [`3517628`](https://github.com/PerfectPan/svgo.mbt/commit/3517628bb2a3c16123c96fe9b5e48ace969ad164) Thanks [@PerfectPan](https://github.com/PerfectPan)! - Faster and smaller: `optimize` is 8 to 17% faster on typical editor exports (wasm-gc, Node 24), and the wasm module is 12.8 KB smaller (188 KB, 69 KB gzipped). The module now also imports `String` from the host for shortest number formatting; the bundled loader provides it. Output is unchanged.

- [#31](https://github.com/PerfectPan/svgo.mbt/pull/31) [`3517628`](https://github.com/PerfectPan/svgo.mbt/commit/3517628bb2a3c16123c96fe9b5e48ace969ad164) Thanks [@PerfectPan](https://github.com/PerfectPan)! - Path data: a number written in scientific notation (`1e-5`, chosen when it is shorter, typically at precision 5 and above) is now separated from a preceding fractional number. It used to be glued on (`.03127e-5` for `.0312 7e-5`), which changed the geometry or, when it broke parsing, dropped the rest of the path.

## 0.2.1

### Patch Changes

- [#26](https://github.com/PerfectPan/svgo.mbt/pull/26) [`84ebf7d`](https://github.com/PerfectPan/svgo.mbt/commit/84ebf7daecc5a61d4f5fd75fb627c2455ca12fd9) Thanks [@PerfectPan](https://github.com/PerfectPan)! - README: the plugin parameter examples (`{ name, params }` entries and top-level `params`) now follow the API usage block instead of trailing the licence line.

## 0.2.0

### Minor Changes

- [#20](https://github.com/PerfectPan/svgo.mbt/pull/20) [`c8dd16e`](https://github.com/PerfectPan/svgo.mbt/commit/c8dd16ee9849e62c313937044cf99c783dab71e3) Thanks [@PerfectPan](https://github.com/PerfectPan)! - MoonBit module: public API reduced to the documented surface (Config, Result, optimize, list_plugins; xml Document/Element/Node/parse; path Options/Segment/PathError/parse/optimize/stringify/optimize_string/apply_matrix/has_geometry; plugins Plugin/Context/preset_default/optional_plugins/find_plugin). Helpers that were public by accident are now internal.

### Patch Changes

- [#12](https://github.com/PerfectPan/svgo.mbt/pull/12) [`271a4bc`](https://github.com/PerfectPan/svgo.mbt/commit/271a4bc9d80c3ee0c06b425eddb586ea0e327d3a) Thanks [@PerfectPan](https://github.com/PerfectPan)! - Bun 1.4+ and Deno 2 are supported runtimes: the package and its CLI pass the full fixture suite under Node 24, Bun 1.4.2 and Deno 2.9, and CI now runs that suite under all three. Fixes the `svgo-mbt` CLI under Bun and Deno, which treated its own script path as an input file because the argument parser detected the JavaScript runtime by looking for "node" in `argv[0]`. Bun 1.2 lacks JS String Builtins and fails at instantiate.

## 0.1.3

### Patch Changes

- Renamed from `svgo-mbt` to `@rivus/svgo`; the command line tool keeps its `svgo-mbt` name. Nothing else changed.
