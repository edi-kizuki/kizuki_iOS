---
id: 038
title: "VF09 Live proof and contract pipeline"
labels: [wayfinder:followup]
status: open
blocked_by: []
assignee:
created: 2026-10-25
---

# VF09 Live proof and contract pipeline

Map: [[2026-10-25-wayfinder-map]]. Concept: [[2026-10-25-architecture-concept-v2]], [[2026-10-25-architecture-concept-v2.1]].

## Goal

Make the live Swift run and contract recordings reproducible and enforceable (F09).

## Concept references

v2 §8.4; v2.1 §3.5; verification F09.

## Exit criteria (tests that prove it)

- Local stack setup script for OrbStack; `KizukiLiveUITests` (or live mode) with a scripted second user.
- `scripts/contracts/record.sh` with normalisation; Linux CI re-records and fails on normalised diff; macOS replays committed files.
- Run-note template in `docs/lanes/`; deferred live cases listed as B20 blocking items.

## Risk class

3+ files (test infrastructure).

## Cross-model review

Required (playbook rule 1: changes 3+ files). Reviewer is the other model family (D45); max two review rounds.
