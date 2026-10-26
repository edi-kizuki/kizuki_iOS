---
id: 040
title: "VF11 Public availability and reason allowlist tests"
labels: [wayfinder:followup]
status: open
blocked_by: []
assignee:
created: 2026-10-25
---

# VF11 Public availability and reason allowlist tests

Map: [[2026-10-25-wayfinder-map]]. Concept: [[2026-10-25-architecture-concept-v2]], [[2026-10-25-architecture-concept-v2.1]].

## Goal

Implement and test D51 and the people reason allowlist (F01, F10; concept resolved in v2.1 §4.2, §5.1).

## Concept references

v2.1 §4.2, §5.1.

## Exit criteria (tests that prove it)

- Schema plan for `profiles.availability_band` (public) and `profile_settings.work_mode` (private), ready for B02.
- pgTAP allowlist test: person reasons ⊆ people allowlist; no private values in params.
- ERD and privacy prose updated in the hub diagrams.

## Risk class

PRIVACY.

## Cross-model review

Required if the change touches 3+ files; otherwise recommended (privacy contract).
