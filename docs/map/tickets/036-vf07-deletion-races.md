---
id: 036
title: "VF07 Deletion under races and crashes"
labels: [wayfinder:followup]
status: open
blocked_by: []
assignee:
created: 2026-10-25
---

# VF07 Deletion under races and crashes

Map: [[2026-10-25-wayfinder-map]]. Concept: [[2026-10-25-architecture-concept-v2]], [[2026-10-25-architecture-concept-v2.1]].

## Goal

Make account deletion finish correctly despite in-flight writes, uploads and crashes (F07, F21, F22).

## Concept references

v2 §4.3, §4.7; v2.1 §1.5; verification F07, F21, F22.

## Exit criteria (tests that prove it)

- Quiescence: freeze takes the profile lock that every write path shares; Storage reconciliation loop until empty after a grace window.
- FK outcomes for `filled_by`, `project_members.project_role_id`, `requests.conversation_id`, decline reasons, request and connection pair keys (nullable FK, set null).
- Apple: encrypted minimal revoke credential persisted before exchange advances, erased after confirmed revoke; fallback copy only when truly unavailable.
- Tests: paused upload across freeze, concurrent message during freeze, crash before/after exchange and after revoke, filled-seat member deletion, requests across two deleted projects.

## Risk class

DELETE + AUTH.

## Cross-model review

Required (playbook rule 1: deleting data; changes 3+ files). Reviewer is the other model family (D45); max two review rounds.
