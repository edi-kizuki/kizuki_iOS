---
id: 033
title: "VF04 Concurrency sets and idempotent operations"
labels: [wayfinder:followup]
status: open
blocked_by: []
assignee:
created: 2026-10-25
---

# VF04 Concurrency sets and idempotent operations

Map: [[2026-10-25-wayfinder-map]]. Concept: [[2026-10-25-architecture-concept-v2]], [[2026-10-25-architecture-concept-v2.1]].

## Goal

Finish the multi-party locking protocol and atomic operation-ID admission (F03, F25).

## Concept references

v2 §4.5, §2.4; v2.1 §1.5; verification F03, F25.

## Exit criteria (tests that prove it)

- Written lock-set rules: every affected row discovered, sorted, locked, re-read; profile-lock upgrades; deadlock/serialization retry policy.
- Accept re-validates the actual seat filler's join readiness and hidden-account policy.
- `op_results` reservation: unique (caller, op_id), parameter hash, conflict on reuse with different input; concurrent identical calls return the same committed result.
- Race tests: two blocks over the same two projects, concurrent deletions, role removal vs accept, identical concurrent op_ids.

## Risk class

PRIVACY (concurrency).

## Cross-model review

Required (playbook rule 1: state integrity; changes 3+ files). Reviewer is the other model family (D45); max two review rounds.

## From VF05 (2026-10-25)

See [[2026-10-25-vf05-reports-visibility]].
- Include the `file_report` lock protocol in the global lock order.
