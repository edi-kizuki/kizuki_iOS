---
id: 022
title: "B11 Storage, avatars, project covers"
labels: [wayfinder:build]
status: open
blocked_by: [021]
assignee:
created: 2026-10-25
---

# B11 Storage, avatars, project covers

Map: [[2026-10-25-wayfinder-map]]. Concept: [[2026-10-25-architecture-concept-v2]], [[2026-10-25-architecture-concept-v2.1]].

## Goal

Private and public buckets with owner-prefix policies, client renditions and scoped image caching.

## Concept references

v2 §2.7; v2.1 §3.4 (B11).

## Exit criteria (tests that prove it)

- Buckets `avatars`, `user-media`, `taste-cards`; policies with `caller_ok`, block and hidden checks; path CHECKs; no upsert.
- Client renditions, HEIC conversion, EXIF strip; avatar upload; project cover.
- pgTAP storage policies; live tests: sign before/after block, deleting account cannot upload, 10-minute TTL behaviour.
- Every slice: tests start from an empty local DB with migrations up to this slice only (`scripts/test-prefix.sh <slice>`); fixture UI tests stay green; new UGC surfaces have Report; user-linked tables extend `private.freeze_account` and the FK matrix (v2.1 §3.3).

## Risk class

PRIVACY.

## Cross-model review

Required (playbook rule 1: changes 3+ files). Reviewer is the other model family (D45); max two review rounds.
