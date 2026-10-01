# <Design title>

Copy this file when starting a plan. A plan records the technical decisions (sections 1-5) and the detailed execution plan (section 6) for one deliverable. Keep the sections that apply to a new system, a change, or a migration, and delete the rest. If an owner, reviewer, or date is unknown, write "unconfirmed". Do not invent them.

Writing and review rules live in the `technical-design-docs` skill when it is installed. This file is only the document shape.

<!-- Keep the sections that apply to a new system, a change, or a migration. Merge sections in a small design and delete the rest. If an owner, reviewer, or date is unknown, write "unconfirmed". Do not invent them. -->

- Status: draft / blocked / in review / accepted
- Owner: <name or team>
- Reviewer: <name or team>
- Last updated: <date>
- Paired Spec: <path, or none>

## Contents

<!-- List the top-level sections you keep. Delete this comment before review. -->

## 1. Background and goals

### 1.1 Current behavior and constraints

State the existing behavior and limits that this design depends on. For a new system, state the demand and the external constraints. Important conclusions need evidence from code, an interface, data, or an earlier decision.

### 1.2 Problem

State the concrete problem. For a change or migration, state why it is worth changing: cost, risk, failure mode, or a missing capability.

### 1.3 Goals and success criteria

List results the design must achieve and that someone can check.

### 1.4 Non-goals

State related problems this design will not handle, so the review does not expand.

## 2. Outline

### 2.1 Design principles

Keep only principles that actually constrain a choice.

### 2.2 Boundaries and responsibilities

Name the systems or domains involved, who owns each, and what each owns. If ownership moves, say what changes. Add a diagram when the relationship is hard to follow in prose.

### 2.3 Main path

Describe the target path. Add a before/after comparison only when the difference changes the review. A new system does not need a diagram of the current state.

### 2.4 Design decisions

For each important choice, state the alternatives considered and why this one was chosen.

## 3. Detailed design

<!-- Keep the subsections you need, and add domain-specific ones. -->

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

<!-- Keep this when the change ships or migrates data. For a local tool, describe release and recovery at the actual risk. -->

### 4.1 Gates and rollout stages

State the entry conditions, the rollout steps, and when to stop widening the rollout.

### 4.2 Signals and alerts

List success, failure, latency, and quality signals, and who owns each.

### 4.3 Rollback

State the trigger, the steps, the data impact, and the expected recovery time.

## 5. Verification

<!-- Keep the checks that match the risk. A local tool or a low-risk change needs the important checks, not all four. -->

### 5.1 Functional checks

### 5.2 Failure and retry checks

### 5.3 Compatibility checks

### 5.4 End-to-end acceptance

## 6. Execution plan

An implementer should be able to follow this section without making new design decisions. Keep the Status `blocked` while a decision that changes scope, interfaces, data, or rollout is unresolved, and list it in section 7.

### 6.1 Preconditions

State what must be true before work starts: reviewed Spec and design, compatibility baseline, access, or upstream releases.

### 6.2 Completion contract

List the checkable conditions that make this plan done. Link each paired Spec scenario ID to the task and test that proves it.

### 6.3 Execution order

Order tasks so each one leaves the repository buildable and reviewable. Group tasks into batches that ship as one PR/MR.

#### Task 1: <name>

- Files: <paths to create, change, or delete>
- Change: <what changes in each file and why>
- Tests: <tests to add or update, with scenario IDs>
- Exit condition: <command output or observable result that ends the task>

### 6.4 Validation ledger

| Batch | Command or evidence | Expected result |
| --- | --- | --- |
| <batch> | <exact command, log, or artifact> | <pass condition> |

### 6.5 Rollback per batch

State the smallest reversible batch, how to revert it, and any persisted-data or release-order constraint. Deployment rollback stays in 4.3.

### 6.6 Work split and schedule

Keep this when more than one person delivers the change. Mark unconfirmed owners and dates as "unconfirmed". Estimates must state their basis, assumptions, and dependencies. An estimate is not a team commitment.

| Batch or component | Owner | Depends on | Effort | When |
| --- | --- | --- | --- | --- |
| <batch> | <owner> | <dependency> | <range or person-days> | <range> |

State cross-component compatibility and the required release order when batches ship separately.

## 7. Risks, open questions, and follow-up

| Item | Type | Impact | Owner | Next step or deadline |
| --- | --- | --- | --- | --- |
| <item> | risk / open question / follow-up | <impact> | <owner> | <next step> |

## Appendix

Put evidence, rejected options, and long references here when they would break the main review.
