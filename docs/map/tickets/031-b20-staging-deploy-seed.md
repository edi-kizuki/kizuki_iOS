---
id: 031
title: "B20 Staging deploy + seed + smoke"
labels: [wayfinder:build]
status: open
blocked_by: [012,013,014,015,016,017,018,019,020,021,022,023,024,025,026,027,028,029,042]
assignee:
created: 2026-10-25
---

# B20 Staging deploy + seed + smoke

Map: [[2026-10-25-wayfinder-map]]. Concept: [[2026-10-25-architecture-concept-v2]], [[2026-10-25-architecture-concept-v2.1]].

## Goal

Staging carries the full schema and fictional data, and every flow passes a smoke run against it.

## Concept references

v2 §3; v2.1 §3.4 (B20), §3.5 (deferred live cases).

## Exit criteria (tests that prove it)

- Marker bootstrap and migrations/functions/secrets/auth config through `kz-remote.sh` only.
- Staging loader (Admin API users, Storage uploads) with ref and marker checks.
- Smoke checklist: every flow on a simulator against staging; Apple and device-push items listed as deferred if ticket 006 is open.
- No production contact (validator and gateway logs).

## Risk class

ENV.

## Cross-model review

Required (playbook rule 1: remote environment; changes 3+ files). Reviewer is the other model family (D45); max two review rounds.
