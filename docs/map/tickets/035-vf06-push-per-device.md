---
id: 035
title: "VF06 Per-device, fenced push delivery"
labels: [wayfinder:followup]
status: open
blocked_by: []
assignee:
created: 2026-10-25
---

# VF06 Per-device, fenced push delivery

Map: [[2026-10-25-wayfinder-map]]. Concept: [[2026-10-25-architecture-concept-v2]], [[2026-10-25-architecture-concept-v2.1]].

## Goal

Model push delivery per token with fenced leases and final eligibility checks (F06).

## Concept references

v2 §2.9; verification F06.

## Exit criteria (tests that prove it)

- `push_deliveries(outbox_id, token, status, attempts, lease_generation)`; compare-and-set completion.
- Final checks: token still owned by the recipient, actor active and not moderated, preferences, connection active.
- Tests: two devices with mixed 200/410/429, token reassignment mid-flight, lost webhook, crash after APNs accept, stale lease completion.

## Risk class

ENV + PRIVACY.

## Cross-model review

Required (playbook rule 1: changes 3+ files). Reviewer is the other model family (D45); max two review rounds.

## From VF05 (2026-10-25)

See [[2026-10-25-vf05-reports-visibility]].
- Skip push when the recipient has a `reporter_hides` row for the sender/subject.
