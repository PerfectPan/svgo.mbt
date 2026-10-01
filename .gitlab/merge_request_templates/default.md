Title format: `type(scope): summary`, in English.

Allowed types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`.

## Summary

<!-- What changed and why. Link the issue, Spec, or Plan when there is one. -->

-

## Validation

<!-- Commands you ran and their results; fixtures, render diff, benchmark numbers, or screenshots for behavior claims. Name skipped checks and why. -->

- [ ] Repository checks: `gh repo-checks repository`
- [ ] MR title and description: `gh repo-checks pr-title "<title>"`, `gh repo-checks pr-body <body-file>`
- [ ] Check, format, interfaces, fixtures, tests on js and native: `scripts/verify.sh`
- [ ] Wasm, npm package tests, CLI smoke test, size comparison, render diff (plugin, wasm, or output changes): `scripts/verify.sh --full`
- [ ] Performance (hot-path changes): `scripts/bench.sh` before and after; output unchanged with `scripts/regress.sh <dir>`
- [ ] Website (site changes): `pnpm app`, reviewed against `docs/DESIGN.md`
- [ ] Changeset for user-visible changes: `pnpm changeset`

## Risks

<!-- Optional: compatibility, rollout, rollback, or follow-up risks. Delete this section when there are none. -->

-
