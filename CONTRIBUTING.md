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
comparison suite; `app/website/` the website and `app/cli/` the CLI. `moon` commands run from the root.
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
   `moon run --target native app/cli -- in.svg --plugins svgoName --no-multipass --pretty`.

   **svgo's own cases.** `svgo/plugins/fixtures/upstream/` holds svgo's
   `test/plugins` suite verbatim (see `NOTICE.md` there). They run with svgo's
   rules: the plugin runs twice and both results must equal `expected`. Cases
   we do not pass yet are listed in `upstream/KNOWN_FAILURES.txt` and generated
   as expected failures. When your change makes one pass, the test tells you to
   delete its line; do that in the same commit. Never add a line without a
   reason comment. Cases that need plugin params (`preserve`, `force`, ...)
   are generated as skipped tests until params exist.

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
    "$(cd /tmp/svgo-base && scripts/bin-path.sh)" "$f" -o "/tmp/ref/$(basename "$f")"; done
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
`build`, `chore`. The body says what changed in behavior or numbers.

## Releasing

`main` is protected: every change is a pull request, merged by rebase or squash
(no merge commits), with CI green.

1. A PR that changes what users get runs `pnpm changeset` and commits the file
   it writes under `.changeset/` (bump level + one line for the changelog).
2. To release, open a PR from `pnpm version-packages`: changesets bumps
   `packages/svgo-mbt/package.json` and writes `CHANGELOG.md`, then
   `scripts/sync-version.mjs` copies the version into `svgo/moon.mod`, the app
   modules' dependency, the CLI's `--version` and the wasm's `version()`.
   `scripts/verify.sh` fails if those ever disagree.
3. Merging that PR runs `release.yml`: build, tests, `changeset publish` (npm,
   OIDC trusted publishing, so no token lives in the repo) and the tag
   `svgo-mbt@X.Y.Z`.
4. The tag runs `binaries.yml`: native CLI tarballs for linux-x86_64,
   linux-arm64 and macos-arm64 on a GitHub release, and `moon publish` of
   `PerfectPan/svgo` to mooncakes using the `MOONCAKES_TOKEN` secret.

One-time setup, both on the maintainer's side: the npm package must exist
before a Trusted Publisher can be configured for it on npmjs.com (first publish
by hand with `npm login && npm publish` in `packages/svgo-mbt`), and the
mooncakes token from `~/.moon/credentials.json` goes into the repository secret
`MOONCAKES_TOKEN`. `gh workflow run release.yml -f dry_run=true` and
`gh workflow run binaries.yml -f dry_run=true` rehearse without publishing.

