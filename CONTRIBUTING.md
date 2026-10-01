# Contributing

Thanks for looking. Everything runs on the stock MoonBit toolchain; there is
no build step outside `moon` except the optional Node comparison suite and the website.

## Setup

```bash
curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash   # MoonBit
git clone https://github.com/PerfectPan/svgo.mbt && cd svgo.mbt
moon test --target native                                         # unit tests + fixtures (moon.work runs every member)
scripts/verify.sh                                                 # what CI runs
pnpm install                                                      # svgo-js, resvg, pixelmatch, tailwind
scripts/verify.sh --full                                          # + wasm, sizes, pixel diffs
./scripts/install-git-hooks.sh                                    # pre-commit hook, see "Local Git hooks"
```

The MoonBit module lives in `svgo/`; `packages/` holds the npm package and the
comparison suite; `app/website/` the website and `app/cli/` the CLI. `moon` commands run from the root.

## Change Design Gate

Every change needs a requirement record. Use the smallest set of artifacts that
makes behavior and implementation reviewable.

| Change type | Required artifact |
| --- | --- |
| New plugin, plugin fix, or plugin parameter | The requirement in the PR description and fixtures that show it (see "Adding or changing a plugin"); no separate Spec or Plan |
| Narrow maintenance, tests, documentation, benchmarks | Requirement and PR checklist; a separate Plan only when useful |
| Technical refactor without changed output (pipeline, packages, wasm boundary, performance rework across targets) | Detailed Plan in `docs/plans/` with compatibility and acceptance conditions |
| Product behavior beyond one plugin (public API, CLI interface, npm package interface, website features) | One Spec in `docs/specs/` plus one detailed Plan for the same deliverable |

A Spec defines observable interactions, scope, failure behavior, and acceptance
examples. Use stable scenario IDs and Given/When/Then where useful. Link
scenarios to tests (fixtures count). A Spec does not prescribe components,
interfaces, or execution order. Keep active Specs under
[`docs/specs/`](docs/specs/). A small change may keep both sections in the PR
description. Split only when each slice has an independently demonstrable
outcome.

A Plan records technical decisions and the detailed execution plan that
implements them. Shared architecture, compatibility, and cross-target decisions
belong in a reviewed Plan. After implementation, move lasting constraints into
[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md), [`AGENTS.md`](AGENTS.md)
invariants, or tests. This repository does not keep an RFC directory. Removing
a proposal does not mark unimplemented ideas as delivered.

## SDD Workflow And Document Lifecycle

1. Record the problem, affected users or maintainers, in-scope behavior,
   non-goals, and acceptance conditions.
2. Choose artifacts with the [Change Design Gate](#change-design-gate). The
   Spec states required behavior: interactions and acceptance scenarios. The
   Plan owns the technical decisions (design, package and interface changes,
   data flow) and the detailed execution plan (ordered tasks, tests, exit
   conditions, validation, and rollback).
3. Review the behavior and technical design before implementing the affected
   scope. The Plan must resolve implementation decisions rather than leave them
   to the implementer; keep it blocked while a material decision is
   unresolved. New behavior revises the Spec. New implementation decisions
   revise the Plan.
4. Implement inside that boundary. Add evidence for each acceptance condition
   (fixtures, tests, `scripts/verify.sh --full` output, benchmark numbers), or
   say why existing evidence is enough. Update current-state docs in the same
   change.
5. Before retiring a completed Spec or Plan, move still-valid behavior,
   invariants, and limits into current-state docs and tests. The final delivery
   PR may delete the completed files. Keep an unfinished Spec or Plan active.
6. Git history and the delivery PR keep the retired decision. Do not copy
   completed Specs or Plans into a second archive.

[`docs/plans/`](docs/plans/) contains active Plans. Copy
[`0000-template.md`](docs/plans/0000-template.md) and keep only the sections
that apply. A product plan links its paired Spec. The execution plan lists
preconditions, a completion contract, ordered tasks with files, changes, tests,
and exit conditions, a validation ledger, and rollback per batch. Keep unknown
owners, dates, and interfaces marked "unconfirmed". A plan may make
feature-specific technical decisions, but it cannot silently override
`docs/ARCHITECTURE.md` or the invariants in `AGENTS.md`.

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
`ci`, `chore`, `revert`. `scripts/check-pr-title.sh` enforces this on every PR
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

Every PR answers: what changed, why, how it was tested, which validation gates
were skipped and why, what evidence backs the claim (fixtures, render diff,
benchmark numbers, screenshots for site changes), and what risks follow.

The description keeps every `##` section of
[`.github/pull_request_template.md`](.github/pull_request_template.md) (the
GitLab copy in `.gitlab/merge_request_templates/` stays identical apart from
PR/MR wording). Summary and Validation must hold real content, not template
placeholders, and the description carries no agent attribution lines such as
"Generated with <tool>"; the author is accountable for the content. Check it
before opening or editing the PR:

```bash
./scripts/check-pr-title.sh "fix(minifyStyles): minify numbers in style attributes"
./scripts/check-pr-body.sh pr-body.md      # or pipe the body on stdin
```

The `Review` workflow runs `repository checks`, `conventional PR title` and
`PR description` on every PR event, including description edits. PRs opened by
bot accounts (the release PR) skip the description check but not the title
check. Update the description when review feedback, rebases, or follow-up
commits change the scope or the validation result.

## Repository checks

`./scripts/check-repository.sh` catches missing repository files, tracked local
or generated artifacts, obvious secrets, personal filesystem paths, and drift
between the PR/MR templates. It does not replace `scripts/verify.sh`; run both
before opening review. Do not commit tokens, local config, internal hostnames,
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
`git diff --cached --check`, `./scripts/check-repository.sh --staged` and
`moon check`. If `core.hooksPath` already points elsewhere, the script fails
instead of overwriting it; re-run with `--force` only after moving those hooks
into `.githooks`. Hooks are a local guardrail; CI and branch protection are the
enforcement.

## Release notes

Release notes come from changesets. A PR that changes what users get records
each user-facing change as a change file (`pnpm changeset`), and changesets
writes `packages/svgo-mbt/CHANGELOG.md` at release time. Do not edit that
generated changelog by hand or keep a hand-written root `CHANGELOG.md` beside
it.

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
3. To release, run CI on the release PR and merge it. The PR is opened with
   the workflow token, and GitHub does not start workflows for events that
   token causes, so CI has to be started by a person: close and reopen the PR
   (`gh pr close <n> && gh pr reopen <n>`) or push an empty commit to its
   branch. `gh workflow run ci.yml` does not count: a dispatched run is not
   attached to the PR and does not satisfy the required checks. Merging runs
   `release.yml` again: build, tests, `changeset publish` (npm, OIDC trusted
   publishing, so no token lives in the repo) and the tag `@rivus/svgo@X.Y.Z`.
4. The tag runs `binaries.yml`: native CLI tarballs for linux-x86_64,
   linux-arm64 and macos-arm64 on a GitHub release, and `moon publish` of
   `PerfectPan/svgo` to mooncakes using the `MOONCAKES_TOKEN` secret.

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
account). `scripts/configure-github-repository.sh` writes classic branch
protection instead; on this repository it would duplicate the ruleset, so use
it only if the ruleset is removed, and then with `--approvals 0` (a sole
maintainer cannot approve their own PRs) and `--check` for each CI job:

```bash
./scripts/configure-github-repository.sh --repo PerfectPan/svgo.mbt --approvals 0 \
  --check "verify (ubuntu-latest)" --check "verify (macos-latest)"   # dry run; add --apply to write
```

## Security reports

Follow [`SECURITY.md`](SECURITY.md). Do not put exploit details, secrets, or
private infrastructure in public issues or pull requests.

