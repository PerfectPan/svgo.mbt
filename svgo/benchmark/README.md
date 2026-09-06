# Benchmarks

`moon bench` micro benchmarks over an embedded corpus (`corpus.mbt`, generated
from `svgo/testdata/` and `packages/compare/corpus/`). Run them with

```bash
scripts/bench.sh                      # native, release: end-to-end + stages
scripts/bench.sh wasm-gc              # same on wasm-gc (moonrun)
scripts/bench.sh native profile_test.mbt   # cost of every plugin on the Tiger
```

## Reference numbers

Apple M-series laptop, native `--release`, mean of `moon bench` runs.
Each row is one `optimize` call with the default config (multipass on).

| input | size | before this round | now | speedup |
| --- | ---: | ---: | ---: | ---: |
| sketch-icon.svg (Sketch export) | 0.8 KB | 99.7 µs | 45 µs | 2.2x |
| Tux.svg (Inkscape) | 50 KB | 14.3 ms | 2.7 ms | 5.3x |
| Ghostscript_Tiger.svg | 68 KB | 47.5 ms | 6.8 ms | 7.0x |
| World map (low resolution) | 85 KB | 54.6 ms | 9.6 ms | 5.7x |

Stage costs on the Tiger (one pass):

| stage | before | now |
| --- | ---: | ---: |
| xml parse | 692 µs | 228 µs |
| xml serialize | 97 µs | 102 µs |
| path parse (all `d` attributes) | – | 296 µs |
| path optimize + stringify (all `d`) | 12.4 ms | 1.7 ms |
| path stringify only | – | 528 µs |
| all other plugins together | ~0.9 ms | ~0.8 ms |

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
   reached their fixpoint are remembered in `Context` and skipped.
5. The XML parser tested six markup prefixes per node with string
   comparisons and rebuilt every token char by char: dispatch on one code
   unit, slice substrings.
6. `referenced_ids` searched every attribute value, including all path data,
   for `url(`: only attributes that can hold references are inspected.

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

Those wasm numbers predate the optimisation round above; rerun
`node packages/compare/wasm-speed.mjs` for current values (the table in the README and
on the site is refreshed from the harness output).

## Methodology notes

- `moon bench` reports mean ± σ over 10 batches; `b.keep` prevents dead-code
  elimination of the result.
- `profile_test.mbt` measures *parse + one plugin* on a fresh document, so
  subtract the parse line to get the plugin's own cost.
- Output must not change during performance work: `scripts/regress.sh`
  compares the CLI output for every corpus file with a reference build.
