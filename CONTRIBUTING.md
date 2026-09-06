# Contributing

Thanks for looking. Everything runs on the stock MoonBit toolchain; there is
no build step outside `moon` except the optional Node comparison suite and the website.

## Setup

```bash
curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash   # MoonBit
git clone https://github.com/PerfectPan/svgo.mbt && cd svgo.mbt
moon test --target native                                         # unit tests + fixtures (moon.work runs every member)
scripts/verify.sh                                                 # what CI runs
pnpm install                                                      # svgo-js, resvg, pixelmatch, tailwind, remotion
scripts/verify.sh --full                                          # + wasm, sizes, pixel diffs

The MoonBit module lives in `svgo/`; `packages/` holds the npm package and the
comparison suite; `site/` the website. `moon` commands run from the root.
```

The repository ships a pre-commit hook that runs `moon check`:
`git config core.hooksPath .githooks`.

## Adding or changing a plugin

1. **Fixture first.** Create `svgo/plugins/fixtures/<svgoName>.<nn>.txt`:

   ```
   <svg xmlns="http://www.w3.org/2000/svg">...input...</svg>

   @@@

   <svg xmlns="http://www.w3.org/2000/svg">...expected...</svg>

   @@@

   {"precision": 2, "multipass": false}     ← optional
   ```

   Only the named plugin runs, once (set `"multipass": true` to iterate to a
   fixpoint). Whitespace between tags is ignored. Regenerate the MoonBit test
   with `python3 scripts/gen-fixtures.py` and run `moon test`.

   Tip: to see what the current implementation produces for an input,
   `moon run --target native svgo/cmd/main -- in.svg --plugins svgoName --no-multipass --pretty`.

2. **Implement** in the matching `svgo/plugins/*.mbt` file as a value:

   ```moonbit
   ///|
   /// One line on what is removed or rewritten and why it is safe.
   pub let my_plugin : Plugin = {
     name: "svgoName",
     description: "shown by --list and the playground",
     run: (doc, ctx) => {
       let mut changed = false
       doc.each_element((e, parent) => { ... changed = true ... })
       changed
     },
   }
   ```

   `run` must return `true` only when it changed the tree: that boolean is
   what multipass looks at. Use `remove_elements`, `remove_attrs`,
   `referenced_ids`, `split_unit` from `plugin.mbt` rather than re-implementing
   traversal. Anything that reads ancestor state should walk with an explicit
   stack as `removeUnknownsAndDefaults` does.

3. **Register** it in `preset_default` (svgo's order matters: `convertShapeToPath`
   must run before `convertPathData`, `collapseGroups` before `mergePaths`,
   `sortAttrs` last) or in `optional_plugins`.

4. **Prove it is safe.** Add the input to `svgo/testdata/` if it exercises a new
   shape of document, then `scripts/verify.sh --full`: the render diff must
   stay at zero pixels. Rendering fidelity beats bytes saved.

5. `moon fmt && moon info`, commit the `.mbti` changes, update the README
   plugin table.

## Performance work

- Baseline: `scripts/bench.sh` (native) and `scripts/bench.sh native profile_test.mbt`
  for per-plugin cost. `svgo/benchmark/README.md` records the numbers per commit.
- Output must not change: build the previous revision into a worktree,
  produce reference files, and compare.

  ```bash
  git worktree add /tmp/svgo-base HEAD && (cd /tmp/svgo-base && moon build --target native --release -q)
  mkdir -p /tmp/ref && for f in svgo/testdata/*.svg packages/compare/corpus/*.svg; do
    /tmp/svgo-base/_build/native/release/build/cmd/main/main.exe "$f" -o "/tmp/ref/$(basename "$f")"; done
  scripts/regress.sh /tmp/ref          # every line must say "same"
  ```

- Rules of thumb that paid off here: tables instead of `@math.pow`, integer
  digit folding instead of substring + `parse_double`, measure lengths
  arithmetically instead of formatting candidates, `Set` instead of
  `Array::contains` on string lists, `Map::retain` instead of `to_array` +
  `remove`, and skipping work that is provably a no-op (path data that already
  reached its fixpoint).

## Commit style

`type(scope): summary` with `feat`, `fix`, `perf`, `docs`, `bench`, `compare`, `site`,
`build`, `chore`. The body says what changed in behaviour or numbers.
