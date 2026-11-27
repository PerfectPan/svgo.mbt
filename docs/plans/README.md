# Implementation Plans

A plan records the design and execution steps for one non-trivial deliverable. Bugfixes and routine changes do not need a plan—explain what changed, why, and how it was verified directly in the PR/MR description. See the [Change Design Gate](../../CONTRIBUTING.md#change-design-gate).

Start from [`0000-template.md`](0000-template.md). Keep only the sections the change needs—typically background and goals, outline, detailed design, rollout, verification, and (for multi-PR or agent-executed work) the execution plan—and delete the rest. Keep a plan `blocked` while a material decision is unresolved. Unknown owners and dates stay "unconfirmed".

The design sections match the `technical-design-docs` skill when installed; this repository does not copy those rules.

Retire the plan in its final delivery PR/MR following [`docs/AGENTS.md` §4](../AGENTS.md#4-retiring-a-plan) (see the [plan lifecycle](../../CONTRIBUTING.md#plan-lifecycle-and-retirement)).
