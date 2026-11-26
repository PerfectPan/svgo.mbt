# Documentation Standards

Use `docs/` for durable project knowledge that a maintainer or user cannot easily infer from reading the code alone. This includes current architecture and tradeoffs, user guides, factual references, and development workflows.

Keep collaboration policy in `CONTRIBUTING.md`, AI-agent instructions in `AGENTS.md`, issue and review evidence requirements in templates, and automated enforcement in scripts or CI workflows.

## Current Documents

- [`ARCHITECTURE.md`](ARCHITECTURE.md): the parse, plugins, serialize pipeline, the MoonBit packages and their public surfaces, and the design decisions behind them.
- [`DESIGN.md`](DESIGN.md): website guidelines (voice, layout, type scale, tokens, interaction); every site change follows it.
- [`NATIVE_BINARIES.md`](NATIVE_BINARIES.md): how the native CLI binary is built and distributed.

Documentation owned elsewhere: usage and the plugin table in [`svgo/README.mbt.md`](../svgo/README.mbt.md) (the root `README.md` links to it), plugin and release workflow in [`CONTRIBUTING.md`](../CONTRIBUTING.md), agent instructions in [`AGENTS.md`](../AGENTS.md), benchmark numbers in [`svgo/benchmark/README.md`](../svgo/benchmark/README.md), and release notes in [`packages/svgo-mbt/CHANGELOG.md`](../packages/svgo-mbt/CHANGELOG.md).

## Adding Documents

Add a document when there is real current-state knowledge for a reader need: user guides (`guides/`), factual references (`reference/` for APIs, CLI flags, configuration), architecture (`architecture/`), or development workflows (`development/`). Do not create empty directories or placeholder files. List every new document in the section above.

## Active Plans Boundary

- [`plans/`](plans/) contains active implementation plans only while non-trivial work is in flight.

The Change Design Gate in [`CONTRIBUTING.md`](../CONTRIBUTING.md#change-design-gate) decides when a change needs a plan. After the code lands on the default branch, move lasting non-code knowledge into `docs/` (and local `Why:` comments in code), move remaining follow-up items to issues, and delete the completed plan. Git history and the delivery PR keep the full plan.

## Writing Standards

- Give every durable document one clear audience, purpose, and owner area.
- Record what source code cannot express: *why* a design or workaround was chosen, alternatives rejected, ownership and trust boundaries, external system quirks, and known validation limits.
- Do not duplicate directory trees, symbol lists, or type signatures that source code and type checks already express.
- Prefer current-state language over historical narration in `docs/`; link to the delivery PR for decision history.
- Keep examples runnable when practical; otherwise label them as illustrative and explain the validation gap.
- Link to source files, commands, schemas, or dashboards when they are the real source of truth.
- Update docs in the same change as behavior, configuration, command, API, deployment, architecture, or operational changes.
- Keep private tokens, internal hostnames, personal filesystem paths, generated logs, and environment-specific secrets out of documentation.
