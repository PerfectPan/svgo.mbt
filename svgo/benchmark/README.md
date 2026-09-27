# Benchmarks

`moon bench` micro benchmarks over an embedded corpus (`corpus.mbt`, generated
from `svgo/testdata/` and `packages/compare/corpus/`). Run them with

```bash
scripts/bench.sh                      # native, release: end-to-end + stages
scripts/bench.sh wasm-gc              # same on wasm-gc (moonrun)
scripts/bench.sh native profile_test.mbt   # cost of every plugin on the Tiger
```

## Reference numbers

Apple M-series laptop, native `--release`, the minimum over interleaved runs
of the previous and the current revision (`moon bench` means drift by 10% or
more between runs on a warm laptop, so compare A/B, not against this table).
Each row is one `optimize` call with the default config (multipass on).

| input | size | first round | before this round | now |
| --- | ---: | ---: | ---: | ---: |
| sketch-icon.svg (Sketch export) | 0.8 KB | 99.7 µs | 89.5 µs | 80.6 µs |
| Tux.svg (Inkscape) | 50 KB | 14.3 ms | 5.81 ms | 4.70 ms |
| Ghostscript_Tiger.svg | 68 KB | 47.5 ms | 11.07 ms | 8.73 ms |
| World map (low resolution) | 85 KB | 54.6 ms | 11.92 ms | 10.48 ms |

Stage costs on the Tiger (one pass):

| stage | before this round | now |
| --- | ---: | ---: |
| xml parse | 219 µs | 222 µs |
| xml serialize | 95 µs | 90 µs |
| path parse (all `d` attributes) | 258 µs | 243 µs |
| path optimize + stringify (all `d`) | 2.37 ms | 1.93 ms |
| path stringify only | 494 µs | 263 µs |

The same round on the shipped wasm-gc module (Node 24, same process): 8 to
17% faster on these files, 9% on the 1 MB `World_map_x12.svg`, and 12.8 KB
smaller (200.7 → 187.9 KB, 75.1 → 69.2 KB gzipped). On the js build, which
the site uses: 6 to 18% faster.

Where the time went and what removed it (see the `perf:` commits):

1. `round_to` and `format_number` called `@math.pow` on every number: a
   `pow10` table.
2. Choosing between the absolute and relative spelling of a segment
   stringified both candidates: lengths are now computed arithmetically from
   the decomposed number (`segment_len`).
3. Every number in path data was sliced into a `String` and fed to
   `parse_double`: `scan_number` folds digits into an `Int64` and applies one
   exact power-of-ten division.
4. Pass 2 and 3 of multipass re-optimized every path: paths that already
   reached their fixpoint are remembered in `Context` and skipped, keyed by
   the element style the result depends on (stroked paths included).
5. The XML parser tested six markup prefixes per node with string
   comparisons and rebuilt every token char by char: dispatch on one code
   unit, slice substrings.
6. `referenced_ids` searched every attribute value, including all path data,
   for `url(`: only attributes that can hold references are inspected.
7. Decomposing a number for its shape returned a tuple, a heap object, and
   ran three times per written number: one formatter keeps the parts in
   locals, measures or writes, and places the separator itself.
8. mergePaths built convex hulls before comparing attributes, the cheap
   test that usually fails.
9. Plugins read their JSON parameters per element and per attribute: an
   empty parameter object answers without a lookup, and the hot plugins read
   theirs once per run.

Tried and dropped, because the targets disagree:

- A hand-written `Math.round` (truncate `x + 0.5`) was 5% faster on native
  but 37% slower on js (Int64 is emulated there) and slower on wasm, where
  `f64.floor` is one instruction.
- Indexing strings directly (`s[i]`) instead of `code_units()` saved 5 KB of
  wasm but doubled path parsing time on js and cost 1 to 2% on wasm, where a
  string is a JS string and every read is a `charCodeAt` call.
- Dropping the mergePaths hull cache was neutral on small files and 14%
  slower on `World_map_x12.svg`.

## Against svgo 4.1 (Node)

Same process, both multipass, ms per call (`node packages/compare/wasm-speed.mjs`,
requires `scripts/build-wasm.sh` and `pnpm install`):

| file | svgo.mbt wasm-gc | svgo-js | ratio |
| --- | ---: | ---: | ---: |
| sketch-icon.svg 0.8 KB | 0.37 | 0.55 | 1.5x |
| inkscape-drawing.svg 2 KB | 0.33 | 1.12 | 3.4x |
| SVG_logo.svg 4 KB | 1.66 | 2.20 | 1.3x |
| Tux.svg 50 KB | 16.0 | 16.8 | 1.1x |
| Ghostscript_Tiger.svg 68 KB | 47.4 | 53.8 | 1.1x |
| World map 85 KB | 66.8 | 83.1 | 1.2x |

Those wasm numbers predate the optimization round above; rerun
`node packages/compare/wasm-speed.mjs` for current values (the table in the README and
on the site is refreshed from the harness output).

## Methodology notes

- `moon bench` reports mean ± σ over 10 batches; `b.keep` prevents dead-code
  elimination of the result.
- `profile_test.mbt` measures *parse + one plugin* on a fresh document, so
  subtract the parse line to get the plugin's own cost.
- Output must not change during performance work: `scripts/regress.sh`
  compares the CLI output for every corpus file with a reference build.
