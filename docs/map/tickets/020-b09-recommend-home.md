---
id: 020
title: "B09 recommend + Home (core loop complete)"
labels: [wayfinder:build]
status: open
blocked_by: [018,040]
assignee:
created: 2026-10-25
---

# B09 recommend + Home (core loop complete)

Map: [[2026-10-25-wayfinder-map]]. Concept: [[2026-10-25-architecture-concept-v2]], [[2026-10-25-architecture-concept-v2.1]].

## Goal

The SQL recommender with privacy-safe reasons feeding the live Home tab.

## Concept references

v2 §2.10; v2.1 §5.1–5.2, §3.4 (B09).

## Exit criteria (tests that prove it)

- Weights table, Stage 0 incl. request/connection exclusions, Stage 2 with neutral taste, cold start, band null rules.
- Golden fixtures (v2 §2.10 list plus v2.1 §5.2) and the people reason allowlist test (VF11).
- Home sections, see-more lists, feedback RPCs, C4 preview.
- Live Swift run: real app on a simulator with `-live` against the local Supabase stack, second user scripted; `.xcresult`, screenshots and a run note in `docs/lanes/` (v2.1 §3.5). Reviewer re-runs it. Flow: seeded Home results, Join project from a Home card through to chat.
- Every slice: tests start from an empty local DB with migrations up to this slice only (`scripts/test-prefix.sh <slice>`); fixture UI tests stay green; new UGC surfaces have Report; user-linked tables extend `private.freeze_account` and the FK matrix (v2.1 §3.3).

## Risk class

PRIVACY (definer read of private settings).

## Cross-model review

Required (playbook rule 1: definer code reading private data; changes 3+ files). Reviewer is the other model family (D45); max two review rounds.
