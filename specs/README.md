# Product Specifications

Active Specs define interactions, scope, failure behavior, compatibility, and acceptance scenarios. Pair each product Spec with a detailed Plan for the same deliverable. Split only for independently demonstrable outcomes.

Start from [`0000-template.md`](0000-template.md). Use `Draft`, `Accepted`, or `Superseded`. Give acceptance scenarios stable IDs and use Given/When/Then where useful. Link them to tests. No separate BDD document or framework is required. Technical decisions and the detailed execution plan belong in the paired Plan.

Follow the [SDD lifecycle](../CONTRIBUTING.md#sdd-workflow-and-document-lifecycle): migrate lasting behavior to tests and current-state docs before deleting completed Specs and Plans in the final delivery PR. Keep unfinished work active.
