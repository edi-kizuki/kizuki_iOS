---
id: 016
title: "B05 Onboarding live"
labels: [wayfinder:build]
status: open
blocked_by: [015]
assignee:
created: 2026-10-25
---

# B05 Onboarding live

Map: [[2026-10-25-wayfinder-map]]. Concept: [[2026-10-25-architecture-concept-v2]], [[2026-10-25-architecture-concept-v2.1]].

## Goal

Wire the prototype's onboarding to the live backend with resume, readiness and permission primers.

## Concept references

v2 §4.8, §5.1; v2.1 §3.4 (B05), §4.2.

## Exit criteria (tests that prove it)

- `set_handle`, `save_onboarding_step`, `missing_fields`, `complete_onboarding` with pgTAP for every readiness level.
- Location purpose string + reduced accuracy in Info.plist; denial paths never block.
- Live Swift run: real app on a simulator with `-live` against the local Supabase stack, second user scripted; `.xcresult`, screenshots and a run note in `docs/lanes/` (v2.1 §3.5). Reviewer re-runs it. Flow: three intent paths, resume after relaunch, permission denial.
- Every slice: tests start from an empty local DB with migrations up to this slice only (`scripts/test-prefix.sh <slice>`); fixture UI tests stay green; new UGC surfaces have Report; user-linked tables extend `private.freeze_account` and the FK matrix (v2.1 §3.3).

## Risk class

3+ files.

## Cross-model review

Required (playbook rule 1: changes 3+ files). Reviewer is the other model family (D45); max two review rounds.
