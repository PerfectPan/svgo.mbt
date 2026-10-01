Title format: `type(scope): summary`, in English.

Allowed types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`.

## Summary

-

## Motivation

-

## Implementation Notes

-

## Validation

- [ ] Repository checks: `./scripts/check-repository.sh`
- [ ] MR title: `./scripts/check-pr-title.sh "<title>"`
- [ ] MR description: `./scripts/check-pr-body.sh <body-file>`
- [ ] Check, format, interfaces, fixtures, tests on js and native: `scripts/verify.sh`
- [ ] Wasm, npm package tests, CLI smoke test, size comparison, render diff (plugin, wasm, or output changes): `scripts/verify.sh --full`
- [ ] Performance (hot-path changes): `scripts/bench.sh` before and after; output unchanged with `scripts/regress.sh <dir>`
- [ ] Website (site changes): `pnpm app`, reviewed against `docs/DESIGN.md`
- [ ] Changeset for user-visible changes: `pnpm changeset`

Skipped gates and reasons:

-

## Evidence

- Requirement and paired Spec/Plan:
- Logs, screenshots, package output, or deployed artifact:
- Reviewer notes that changed the final scope:

## Safety Checklist

- [ ] No credentials, tokens, private hostnames, personal filesystem paths, or generated logs are included.
- [ ] Local config, generated output, build artifacts, and temporary workspaces are not staged.
- [ ] User-facing behavior, docs, release change files, migrations, or rollback notes are updated when relevant.
- [ ] Completed Spec/Plan constraints are migrated to tests or current-state docs before retirement; unfinished scope remains active.
- [ ] The branch is current enough for review, and the remote head matches the intended commit.

## Follow-up Risks

-
