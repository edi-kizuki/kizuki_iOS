---
id: 026
title: "B15 Favourites"
labels: [wayfinder:build]
status: open
blocked_by: [025]
assignee:
created: 2026-10-25
---

# B15 Favourites

Map: [[2026-10-25-wayfinder-map]]. Concept: [[2026-10-25-architecture-concept-v2]], [[2026-10-25-architecture-concept-v2.1]].

## Goal

Film and music favourites with display and matching consents.

## Concept references

v2 §2.13; v2.1 §4.1 (D48).

## Exit criteria (tests that prove it)

- `tmdb-proxy` (user JWT, throttle) with Deno tests; MusicBrainz client with 1.1 s queue and contact User-Agent.
- `favourites` + `show_favourites` + `favourites_for_matching` (picker and Settings toggle).
- pgTAP rarity population and consent-off removal; `shared_favourite` reason gated on display consent.
- Every slice: tests start from an empty local DB with migrations up to this slice only (`scripts/test-prefix.sh <slice>`); fixture UI tests stay green; new UGC surfaces have Report; user-linked tables extend `private.freeze_account` and the FK matrix (v2.1 §3.3).

## Risk class

ENV (function secret) + PRIVACY (consent).

## Cross-model review

Required (playbook rule 1: changes 3+ files). Reviewer is the other model family (D45); max two review rounds.
