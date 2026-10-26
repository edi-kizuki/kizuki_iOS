---
id: 024
title: "B13 Profile, links/embeds, Get discovered"
labels: [wayfinder:build]
status: open
blocked_by: [022,040,041]
assignee:
created: 2026-10-25
---

# B13 Profile, links/embeds, Get discovered

Map: [[2026-10-25-wayfinder-map]]. Concept: [[2026-10-25-architecture-concept-v2]], [[2026-10-25-architecture-concept-v2.1]].

## Goal

Live own/other profiles with public availability, consented links/embeds and the Get discovered card.

## Concept references

v2 §2.12; v2.1 §4.2, §4.7.

## Exit criteria (tests that prove it)

- Own/other profile, edit, availability shown on every profile, `portfolio_sources` + host trigger, `KizukiEmbeds` parser/facade/player.
- Get discovered card on own Profile + one-time Home nudge (v2.1 §4.7).
- Parser unit tests incl. hostile URLs; consent visibility pgTAP; provider smoke checklist (device when available).
- Every slice: tests start from an empty local DB with migrations up to this slice only (`scripts/test-prefix.sh <slice>`); fixture UI tests stay green; new UGC surfaces have Report; user-linked tables extend `private.freeze_account` and the FK matrix (v2.1 §3.3).

## Risk class

3+ files.

## Cross-model review

Required (playbook rule 1: changes 3+ files). Reviewer is the other model family (D45); max two review rounds.
