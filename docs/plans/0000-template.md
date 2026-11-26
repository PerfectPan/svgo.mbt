# <Design title>

Copy this file when starting a plan for a non-trivial change (see `CONTRIBUTING.md`). Keep the sections that apply to a new system, a change, or a migration, and delete the rest. If an owner or date is unknown, write "unconfirmed". Do not invent them.

Writing and review rules live in the `technical-design-docs` skill when it is installed. This file is only the document shape.

- Status: draft / blocked / in review / active
- Owner: <name or unconfirmed>
- Last updated: <date>
- Issue / PR: <link or none>

## 1. Background and goals

### 1.1 Current behavior and constraints

State the existing behavior and limits that this design depends on. For a new system, state the demand and external constraints. Important conclusions need evidence from code, an interface, data, or an earlier decision.

### 1.2 Problem

State the concrete problem. For a change or migration, state why it is worth changing: cost, risk, failure mode, or a missing capability.

### 1.3 Goals and acceptance criteria

List checkable outcomes, observable behavior, and invariants the change must satisfy.

### 1.4 Non-goals

State related problems this design will not handle, so the scope and review do not expand.

## 2. Outline

### 2.1 Design principles

Keep only principles that actually constrain a choice.

### 2.2 Boundaries and responsibilities

Name the systems, modules, or domains involved, who owns each, and what each owns. If ownership moves, say what changes. Add a diagram when the relationship is hard to follow in prose.

### 2.3 Main path

Describe the target path. Add a before/after comparison only when the difference changes the review. A new system does not need a diagram of the current state.

### 2.4 Design decisions

For each important choice, state the alternatives considered and why this one was chosen.

## 3. Detailed design

<!-- Keep only the subsections that apply, and add domain-specific ones. -->

### 3.1 Entry points and request path

### 3.2 Interfaces

### 3.3 Domain model, state, and data ownership

### 3.4 State transitions and lifecycle

### 3.5 Concurrency, idempotency, and retries

### 3.6 Failures and recovery

### 3.7 Compatibility and migration

### 3.8 Security and privacy

### 3.9 Metrics, logs, and traces

## 4. Rollout and stability

<!-- Keep this when the change ships to production or migrates persisted data. For a local tool, describe release and recovery at the actual risk. -->

### 4.1 Gates and rollout stages

State entry conditions, rollout steps, and when to stop widening the rollout.

### 4.2 Signals and alerts

List success, failure, latency, and quality signals, and who owns each.

### 4.3 Rollback

State the trigger, steps, data impact, and expected recovery time.

## 5. Verification

<!-- Keep the checks that match the risk. -->

### 5.1 Functional checks

### 5.2 Failure and retry checks

### 5.3 Compatibility checks

### 5.4 End-to-end acceptance

## 6. Execution plan

<!-- Keep this when the work spans multiple PRs/sessions or an agent/implementer executes in batches; delete for a single-PR design. -->

An implementer should be able to follow this section without making new design decisions. Keep Status `blocked` while a decision changing scope, interfaces, data, or rollout is unresolved, and list it in section 7.

### 6.1 Preconditions

State what must be true before work starts: reviewed design, compatibility baseline, access, or upstream releases.

### 6.2 Completion contract

List the checkable conditions that make this plan done, linking each acceptance criterion to the task and test that proves it.

### 6.3 Execution order

Order tasks so each leaves the repository buildable and reviewable. Group tasks into batches that ship as one PR/MR.

#### Task 1: <name>

- Files: <paths to create, change, or delete>
- Change: <what changes in each file and why>
- Tests: <tests to add or update>
- Exit condition: <command output or observable result that ends the task>

### 6.4 Validation ledger

| Batch | Command or evidence | Expected result |
| --- | --- | --- |
| <batch> | <exact command, log, or artifact> | <pass condition> |

### 6.5 Rollback per batch

State the smallest reversible batch, how to revert it, and any persisted-data or release-order constraint. Deployment rollback stays in 4.3.

## 7. Risks and open questions

| Item | Type | Impact | Owner | Next step |
| --- | --- | --- | --- | --- |
| <item> | risk / open question / follow-up | <impact> | <owner> | <next step> |

## 8. Retirement checklist

Complete before deleting this file in the final delivery PR/MR:

- [ ] Remaining manual checks or follow-up items moved to issues
- [ ] Lasting non-code knowledge (invariants, tradeoffs, external quirks, validation limits) migrated to `docs/` or local `Why:` comments
- [ ] This plan file deleted in the final delivery PR/MR
