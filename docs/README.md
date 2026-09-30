# Documentation Standards

Use `docs/` for durable project knowledge that a maintainer should be able to read without replaying pull requests or chat history. This includes current architecture, development guides, and factual references.

Keep collaboration policy in `CONTRIBUTING.md`, AI-agent instructions in `AGENTS.md`, issue and review evidence requirements in templates, and automated enforcement in scripts or CI workflows.

## Current Documents

- [`ARCHITECTURE.md`](ARCHITECTURE.md): the parse, plugins, serialize pipeline, the MoonBit packages and their public surfaces, and the design decisions behind them.
- [`DESIGN.md`](DESIGN.md): website guidelines (voice, layout, type scale, tokens, interaction); every site change follows it.
- [`NATIVE_BINARIES.md`](NATIVE_BINARIES.md): how the native CLI binary is built and distributed.

Documentation owned elsewhere: usage and the plugin table in [`svgo/README.mbt.md`](../svgo/README.mbt.md) (the root `README.md` links to it), plugin and release workflow in [`CONTRIBUTING.md`](../CONTRIBUTING.md), agent instructions in [`AGENTS.md`](../AGENTS.md), benchmark numbers in [`svgo/benchmark/README.md`](../svgo/benchmark/README.md), and release notes in [`packages/svgo-mbt/CHANGELOG.md`](../packages/svgo-mbt/CHANGELOG.md).

## Adding Documents

Add a document when there is real current-state knowledge for a reader need: architecture, development guides, factual references (APIs, CLI flags, configuration), or tutorials. Do not create empty directories or placeholder files. List every new document in the section above.

## Spec And Plan Boundary

- [`../specs/`](../specs/) declares active product behavior and acceptance contracts.
- [`plans/`](plans/) contains active technical decisions and detailed execution plans.

The Change Design Gate in [`CONTRIBUTING.md`](../CONTRIBUTING.md) decides which artifacts a change needs. After delivery, lasting constraints belong in current-state `docs/`. Git history keeps the retired Spec or Plan.

## Writing Standards

- Give every durable document one clear audience, purpose, and owner area.
- Prefer current-state language over historical narration in `docs/`; link to the delivery PR for decision history.
- Keep examples runnable when practical; otherwise label them as illustrative and explain the validation gap.
- Link to source files, commands, schemas, or dashboards when they are the real source of truth.
- Update docs in the same change as behavior, configuration, command, API, deployment, architecture, or operational changes.
- Keep private tokens, internal hostnames, personal filesystem paths, generated logs, and environment-specific secrets out of documentation.
