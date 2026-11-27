# Documentation Authoring Guide

## 1. Where Knowledge Belongs

Write only **non-code knowledge**: facts a reader cannot recover from the relevant source, types, tests, and config. When a rule is already enforced by types, tests, scripts, or CI, link to the check instead of restating it.

Route each piece to one owning surface:

- Readers who use the released artifact → `guides/` (reach one outcome) or `reference/` (public interface contracts: anything whose change needs a SemVer major or a migration note).
- Readers who change this repository → `architecture/` or `development/`.
- A constraint tied to one file or function → a source comment prefixed with `Why:` (so `rg 'Why:'` finds it).

Keep each category in its own directory under `docs/` (`guides/`, `reference/`, `architecture/`, `development/`), even for a single document. `docs/README.md` lists this repository's documents and any repository-specific surfaces (such as a decision log or translations); for those surfaces, its rules take precedence.

| Surface | Audience | Put here | Route elsewhere |
| --- | --- | --- | --- |
| `docs/guides/` | Users & external integrators | Getting-started tutorials and task-oriented how-to guides (including external plugin/extension guides) | Exhaustive option/API tables → `reference/`; internals → `architecture/` |
| `docs/reference/` | Users & external integrators | Public interface contracts for fast lookup: CLI commands, exit codes, config contracts, public APIs, schemas, wire mappings, error codes, compatibility matrices, SemVer guarantees; prefer linking or generating from `--help` / schemas over hand-copying | Walkthrough steps → `guides/`; rationale → `architecture/`; internal code signatures → source code |
| `docs/architecture/` | Maintainers | Current system shape: domain/module boundaries, end-to-end data flow, ownership and trust boundaries, cross-module invariants, failure/recovery semantics, major tradeoffs and rejected alternatives | Single-file quirks → `Why:` comment in source; setup & runbooks → `development/` |
| `docs/development/` | Maintainers | Local setup, test strategy, honest validation boundaries (automated vs manual/unverified), maintainer extension walkthroughs (e.g. `adding-a-provider.md`), debugging, release and deployment/rollback runbooks | User-facing guides → `guides/`; collaboration policy → `CONTRIBUTING.md` |
| `docs/plans/` | Implementers & reviewers | Active implementation plans only when upfront human alignment is needed (`0000-template.md`); skip for adjustments requested during implementation; delete in the final delivery PR/MR | Post-delivery non-code knowledge → the surfaces above; deferred work → issues |
| Code `Why:` comments | Maintainers | Single-site non-obvious constraints, external API quirks, or deliberate workarounds prefixed with `Why:` so they move and delete with the code | Cross-module invariants or system tradeoffs → `docs/architecture/` |

Other surfaces keep their own scope: `README.md` (orientation and quick start), `CONTRIBUTING.md` (workflow, Change Design Gate, CI/release policy), root `AGENTS.md` (agent rules and commands), scripts/CI (automated enforcement), and release tools (changelogs).

## 2. File Naming And Splitting

- Use kebab-case filenames (`overview.md`, `public-interface.md`, `adding-a-provider.md`).
- Start `architecture/` with `overview.md`. Split out `architecture/conventions.md` only when a repository has strict layering, modeling, or extension rules that outgrow `overview.md` and root `AGENTS.md`.
- Split a document when it mixes user lookup with maintainer internals or combines distinct audiences.

## 3. Writing Rules

- **Link to the repository as source of truth.** Point to source files, schemas, config files, scripts, and tests instead of mirroring directory trees, symbol lists, or internal type signatures.
- **Write in current-state language.** Describe how the system works now ("X validates Y"), rather than narrating history ("PR #12 changed X from A to B"). Link to the delivery PR/MR when decision history matters.
- **Keep reference docs scannable and exact.** Use tables for contracts, defaults, bounds, exit codes, and compatibility matrices.
- **Be honest about validation.** Separate verified automated gates from manual or unverified checks. Keep examples runnable when practical; label schematic examples as illustrative and state the validation gap.
- **Keep translations in sync.** If `docs/README.md` declares translated copies, update them in the same PR/MR or open an issue marking them stale.
- **Use neutral placeholders.** Use `OWNER/REPO`, `/work/...`, or `/fake-home/...` in examples and fixtures.

## 4. Retiring A Plan

Do this in the final delivery PR/MR of an active plan (the one whose merge completes its code scope). Git history and that PR/MR keep the full plan.

1. Add a `Plan retirement` table under `## Summary` in the PR/MR description: one row per section the plan kept, each with a concrete destination — `docs/<path>#<heading>`, a `Why:` comment at `<file>:<symbol>`, an issue link, `enforced by <test>`, or `dropped: <reason>`.
2. Write the docs and `Why:` comments the table names; open issues for remaining manual checks and deferred follow-ups.
3. Delete the plan file and remove or redirect every link pointing to it.

Done when every row's destination exists.

## 5. Before Finishing A Doc Change

- Every path, command, flag, default, schema field, and version was checked against the current tree or `--help`.
- Every new or renamed document appears under `## Index` in `docs/README.md` (and root `README.md` if user-facing); every relative link resolves.
- No rule or table restates another authoritative document.
- The repository checks in root `AGENTS.md` pass on the staged change.
