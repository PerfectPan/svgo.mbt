# Changesets

Every pull request that changes what `@rivus/svgo` ships adds a changeset:

    pnpm changeset

It asks for the bump level and a one-line summary, and writes a small markdown
file here. When it is time to release, `pnpm version-packages` folds the pending
changesets into `packages/svgo-mbt/package.json` and `CHANGELOG.md`, and
`scripts/sync-version.mjs` copies the version into the MoonBit modules. That
lands through an ordinary pull request; merging it makes `release.yml` publish.
See CONTRIBUTING.md, "Releasing".
