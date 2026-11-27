# Contributing

Thanks for looking. Everything runs on the stock MoonBit toolchain; there is
no build step outside `moon` except the optional Node comparison suite and the website.

## Setup

```bash
curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash   # MoonBit
git clone https://github.com/PerfectPan/svgo.mbt && cd svgo.mbt
moon test --target native                                         # unit tests + fixtures (moon.work runs every member)
scripts/verify.sh                                                 # what CI runs
pnpm install                                                      # svgo-js, resvg, pixelmatch, tailwind (pnpm 12, see below)
scripts/verify.sh --full                                          # + wasm, sizes, pixel diffs
gh extension install PerfectPan/gh-repo-checks                    # review checks, see "Repository checks"
./scripts/install-git-hooks.sh                                    # pre-commit hook, see "Local Git hooks"
```

The code requires moonc ≥ 0.10.19 and is verified warning-free on moonc
1.0.0-rc1 (it uses `Int32`, `#derive(...)`, `Set::insert`, and
`Buffer::write_bytesview`). If `moon check` fails on older syntax or warns
about deprecated methods, run `moon upgrade`.

Use Node.js 26.x from 26.13.1 onward for development. The root
`devEngines.runtime` range selects the Node.js version for CI, Pages and releases.
`package.json` pins pnpm with `packageManager`; pnpm 10 and later switch to
that version by themselves. Dependency build scripts are blocked unless
`allowBuilds` in `pnpm-workspace.yaml` lists the package, and nothing here
needs one. pnpm resolves only versions published at least a day ago
(`minimumReleaseAge: 1440` in `pnpm-workspace.yaml`, pnpm's default); an
install that needs a newer release fails with
`ERR_PNPM_MINIMUM_RELEASE_AGE_VIOLATION`, so pick a mature version or wait a
day rather than lowering the setting.

The MoonBit module lives in `svgo/`; `packages/` holds the npm package and the
comparison suite; `app/website/` the website and `app/cli/` the CLI. `moon` commands run from the root.

## Change Design Gate

Most changes need only a clear PR description (`## Summary` and `## Validation`), not a separate document. Write a Plan only when upfront alignment with a human is needed before implementing. Do not write a Plan for adjustments requested during implementation or review—reflect those directly in code, durable docs, and the PR description.

| Change scope | Required artifact |
| --- | --- |
| New plugin, plugin fix, or plugin parameter | PR description and fixtures (see "Adding or changing a plugin"); no Plan |
| Bugfix, localized feature/refactor, tests, benchmarks, dependencies, or docs | PR description explaining what changed, why, and how it was verified |
| New subsystem or package, public API / CLI / npm / wasm contract change, major cross-target refactor, or multi-PR/multi-session work | One Plan in [`docs/plans/`](docs/plans/) |

## Plan Lifecycle And Retirement

1. Draft a plan from [`docs/plans/0000-template.md`](docs/plans/0000-template.md) only when triggered by the [Change Design Gate](#change-design-gate). Keep `Status: blocked` while a material scope, interface, data, or rollout decision is unresolved.
2. Review the goals, boundaries, and key decisions before implementing; update an active plan mid-flight only when remaining multi-PR or multi-session work still needs re-alignment.
3. Implement within that scope, adding evidence for each acceptance criterion (fixtures, tests, `scripts/verify.sh --full` output, benchmark numbers) and updating current-state docs in the same change.
4. Retire the plan in its final delivery PR as soon as its code scope lands on the default branch; move deferred manual checks and future polish to issues rather than keeping the plan open. Follow [`docs/AGENTS.md` §4](docs/AGENTS.md#4-retiring-a-plan) (migrating lasting constraints into [`docs/architecture/overview.md`](docs/architecture/overview.md), [`AGENTS.md`](AGENTS.md) invariants, tests, or `Why:` comments).

[`docs/plans/`](docs/plans/) holds active Plans only while non-trivial work is in flight. Copy [`0000-template.md`](docs/plans/0000-template.md) and keep only the sections that apply. State the problem, goals, non-goals, boundaries, rejected alternatives, failure/rollback behavior, and verification; a file list alone is not a design. Keep unknown owners, dates, and interfaces marked "unconfirmed". A plan may make feature-specific technical decisions, but it cannot silently override `docs/architecture/overview.md` or the invariants in `AGENTS.md`. This repository does not keep an RFC directory.

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
   reason comment. Upstream plugin params are passed through as JSON.

2. **Implement** in the matching `svgo/plugins/*.mbt` file as a package-private value:

   ```moonbit
   ///|
   /// One line on what is removed or rewritten and why it is safe.
   let my_plugin : Plugin = {
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

5. `moon fmt && moon info`, commit the `.mbti` changes, update the
   `svgo/README.mbt.md` plugin table.

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

- Measure every change on native, js (`scripts/bench.sh js`, what the site
  runs) and the wasm artifact (`node packages/compare/wasm-speed.mjs` after
  `scripts/build-wasm.sh`), and check the wasm size. The targets can
  disagree: Int64 arithmetic is emulated on js, strings are JS strings on
  wasm, and core's generic code costs bytes per instantiation.
  `svgo/benchmark/README.md` lists attempts that won on one target and lost
  on another.
- Rules of thumb that paid off here: tables instead of `@math.pow`, integer
  digit folding instead of substring + `parse_double`, measure lengths
  arithmetically instead of formatting candidates, `Set` instead of
  `Array::contains` on string lists, `Map::retain` instead of `to_array` +
  `remove`, and skipping work that is provably a no-op (path data that already
  reached its fixpoint).

## Commit and PR titles

Commit messages and PR titles are English `type(scope): summary`. Allowed
types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`,
`ci`, `chore`, `revert`. `gh repo-checks pr-title` enforces this on every PR
and rejects CJK characters. Areas of the repository are scopes, not types:

| area | examples |
| --- | --- |
| a plugin | `fix(minifyStyles): ...`, `feat(removeXlink): ...` |
| benchmarks | `perf(bench): ...`, `test(bench): ...` |
| svgo-js comparison suite | `test(compare): ...`, `chore(compare): ...` |
| website | `feat(site): ...`, `fix(site): ...`, `docs(site): ...` |
| CLI, npm package, wasm | `feat(cli): ...`, `fix(npm): ...`, `perf(wasm): ...` |
| releases | `chore(release): version packages` (the release PR from `release.yml`) |

The body says what changed in behavior or numbers.

## Pull requests

The PR template,
[`.github/pull_request_template.md`](.github/pull_request_template.md) (the
GitLab copy in `.gitlab/merge_request_templates/` stays identical apart from
PR/MR wording), has three sections:

- **Summary**: what changed and why, with links to the issue or Plan when there is one.
- **Validation**: the commands you ran and their results, the evidence behind
  the claim (fixtures, render diff, benchmark numbers, screenshots for site
  changes), and skipped gates with reasons.
- **Risks** (optional): compatibility, rollout, rollback or follow-up risks.
  Delete it when there are none.

Summary and Validation must hold real content, not template placeholders;
other sections are optional. The description carries no agent attribution
lines such as "Generated with <tool>"; the author is accountable for the
content. Check it before opening or editing the PR:

```bash
gh repo-checks pr-title "fix(minifyStyles): minify numbers in style attributes"
gh repo-checks pr-body pr-body.md      # or pipe the body on stdin
```

The `Review` workflow runs `repository checks`, `conventional PR title` and
`PR description` on every PR event, including description edits. PRs opened by
bot accounts (the release PR) skip the description check but not the title
check. Update the description when review feedback, rebases, or follow-up
commits change the scope or the validation result.

## Repository checks

The review checks come from
[`PerfectPan/gh-repo-checks`](https://github.com/PerfectPan/gh-repo-checks):
CI runs them through its GitHub Action (`uses: PerfectPan/gh-repo-checks@v1`),
and locally they run as a GitHub CLI extension
(`gh extension install PerfectPan/gh-repo-checks`). Do not copy the check
scripts into this repository; change them upstream. Repository-specific
additions, such as extra required files or forbidden patterns, go in
`.github/repo-checks.conf`, and repository-specific scripts run as extra steps
after the shared check.

`gh repo-checks repository` catches missing repository files, tracked local or
generated artifacts, obvious secrets, personal filesystem paths, and PR/MR
templates that lost a review section. It does not replace `scripts/verify.sh`;
run both before opening review. Do not commit tokens, local config, internal hostnames,
or personal paths, including inside fixtures and `svgo/testdata/`.

Workflows reference actions by their latest major version tag, such as
`actions/checkout@v7`, not by commit SHA. `.github/workflows/review.yml` is
copied from the project template and takes action upgrades from the template
rather than local edits.

## Local Git hooks

```bash
./scripts/install-git-hooks.sh
```

This sets `core.hooksPath` to `.githooks`. The pre-commit hook runs
`git diff --cached --check`, `gh repo-checks repository --staged` and
`moon check`; without the extension it warns and skips the repository check. If `core.hooksPath` already points elsewhere, the script fails
instead of overwriting it; re-run with `--force` only after moving those hooks
into `.githooks`. Hooks are a local guardrail; CI and branch protection are the
enforcement.

## Release notes

Release notes come from changesets. A PR that changes what users get records
each user-facing change as a change file (`pnpm changeset`), and changesets
writes `packages/svgo-mbt/CHANGELOG.md` at release time. Do not edit that
generated changelog by hand or keep a hand-written root `CHANGELOG.md` beside
it.

## License

svgo.mbt is licensed under MIT ([`LICENSE`](LICENSE)): it is a library and a
tool, and tools and libraries use MIT (applications use GPL-3.0-only). Package
metadata (`package.json`, `moon.mod`) uses the SPDX identifier `MIT`. Change
the license only as a deliberate project decision.

Keep third-party notices for code or data copied from other projects in
[`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md); svgo's MIT license covers
the ported plugin code, the generated SVG tables and the upstream fixtures.
The published artifacts carry both files: `svgo/` holds copies for the
mooncakes module (`scripts/verify.sh` fails if they drift),
`scripts/build-cli.sh` copies them into the npm package, `binaries.yml` puts
them in the native archives, and `app/website/build.mjs` copies them into the
site, whose footer links to the notices. When a dependency that is compiled
into an artifact (including the website's bundle) is added or changes its
license, update `THIRD_PARTY_NOTICES.md` in the same PR.

## Releasing

`main` is protected: every change is a pull request, merged by rebase or squash
(no merge commits), with CI green.

1. A PR that changes what users get runs `pnpm changeset` and commits the file
   it writes under `.changeset/` (bump level + one line for the changelog).
2. When that PR lands, `release.yml` opens (or updates) the release PR on the
   branch `changeset-release/main` by running `pnpm version-packages`:
   changesets bumps `packages/svgo-mbt/package.json` and writes
   `packages/svgo-mbt/CHANGELOG.md`, then `scripts/sync-version.mjs` copies
   the version into `svgo/moon.mod`, the app modules' dependency, the CLI's
   `--version` and the wasm's `version()`. `scripts/verify.sh` fails if those
   ever disagree.
   Further changesets merged later are folded into the same PR.
3. Changesets returns the version PR to Draft on every update. Review the version changes, mark
   the PR Ready, and verify that both required CI jobs pass on its current head. Merging
   it runs `release.yml` again to build and test the npm package. Changesets publishes
   through npm Trusted Publishing and creates the package tag and GitHub Release.
4. The publish action reports the released package and version. The workflow dispatches
   `binaries.yml` at that tag to attach the Linux x86-64, Linux arm64 and macOS arm64
   CLI archives and publish the matching MoonBit source to mooncakes. To retry the
   attachments, dispatch `binaries.yml` with `tag=@rivus/svgo@X.Y.Z` and `dry_run=false`.

One-time setup, done: `@rivus/svgo` has a Trusted Publisher on npmjs.com
pointing at this repository and `release.yml` (the first publish needed a
token because only an existing package can be given one), and the mooncakes
token from `~/.moon/credentials.json` is the repository secret
`MOONCAKES_TOKEN`. No npm token is stored anywhere. `gh workflow run release.yml -f dry_run=true` and
`gh workflow run binaries.yml -f dry_run=true` rehearse without publishing.

`main` is protected by a repository ruleset on GitHub (pull requests, rebase
or squash, linear history, required `verify (ubuntu-latest)` and
`verify (macos-latest)`). The `Review` workflow's checks, `repository checks`,
`conventional PR title` and `PR description`, belong in that ruleset's required
status checks; add them by editing the ruleset in the repository settings or
through `gh api repos/PerfectPan/svgo.mbt/rulesets/<id>` (needs an admin
account). `gh repo-checks protect` writes classic branch protection instead;
on this repository it would duplicate the ruleset, so use it only if the
ruleset is removed, and then with `--approvals 0` (a sole maintainer cannot
approve their own PRs) and `--check` for each CI job:

```bash
gh repo-checks protect --repo PerfectPan/svgo.mbt --approvals 0 \
  --check "verify (ubuntu-latest)" --check "verify (macos-latest)"   # dry run; add --apply to write
```

## Security reports

Follow [`SECURITY.md`](SECURITY.md). Do not put exploit details, secrets, or
private infrastructure in public issues or pull requests.

