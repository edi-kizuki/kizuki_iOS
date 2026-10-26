---
id: 017
title: "B06 Projects + My Projects"
labels: [wayfinder:build]
status: open
blocked_by: [016,033]
assignee:
created: 2026-10-25
---

# B06 Projects + My Projects

Map: [[2026-10-25-wayfinder-map]]. Concept: [[2026-10-25-architecture-concept-v2]], [[2026-10-25-architecture-concept-v2.1]].

## Goal

Live projects with seats, members and the full project state machine, shown in My Projects.

## Concept references

v2 §4.6; v2.1 §3.3 (`on_project_left_published` v1), §3.4 (B06).

## Exit criteria (tests that prove it)

- `projects`, `project_roles`, `project_members`, all project RPCs with write-time invariants and VF04 lock sets; expiry job; onboarding Start draft created once.
- pgTAP state machine incl. illegal transitions and locked fields; race tests per VF04.
- Live Swift run: real app on a simulator with `-live` against the local Supabase stack, second user scripted; `.xcresult`, screenshots and a run note in `docs/lanes/` (v2.1 §3.5). Reviewer re-runs it. Flow: create → publish → expire (test clock) → renew; My Projects segments.
- Every slice: tests start from an empty local DB with migrations up to this slice only (`scripts/test-prefix.sh <slice>`); fixture UI tests stay green; new UGC surfaces have Report; user-linked tables extend `private.freeze_account` and the FK matrix (v2.1 §3.3).

## Risk class

PRIVACY (state machine, locks).

## Cross-model review

Required (playbook rule 1: changes 3+ files). Reviewer is the other model family (D45); max two review rounds.
