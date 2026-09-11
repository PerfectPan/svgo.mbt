# Changesets

Every pull request that changes what `@rivus/svgo` ships adds a changeset:

    pnpm changeset

It asks for the bump level and a one-line summary, and writes a small markdown
file here. Once the pull request lands, `release.yml` folds the pending
changesets into `packages/svgo-mbt/package.json` and `CHANGELOG.md` (with
`scripts/sync-version.mjs` copying the version into the MoonBit modules) and
opens the release pull request on `changeset-release/main`. Close and reopen
that PR to run CI, merge it, and `release.yml` publishes. See CONTRIBUTING.md,
"Releasing".
