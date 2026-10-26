---
id: 042
title: "VF13 Settled decisions and release gates"
labels: [wayfinder:followup]
status: open
blocked_by: []
assignee:
created: 2026-10-25
---

# VF13 Settled decisions and release gates

Map: [[2026-10-25-wayfinder-map]]. Concept: [[2026-10-25-architecture-concept-v2]], [[2026-10-25-architecture-concept-v2.1]].

## Goal

Carry D46–D49 into build and release gates (F15).

## Concept references

v2.1 §4.1; verification F15.

## Exit criteria (tests that prove it)

- `reports.closed_at` and the D49 erase path specified for B17.
- Release checklist: Pro before external testers (D46), SMTP/support/legal configuration (OD-15), provider and placeholder-rights gates, accepted image-safety checks, D49 legal confirmation before public launch.
- Confirm no locked v0 feature is deferred; split oversized tickets instead.

## Risk class

DELETE (retention) + ENV (release).

## Cross-model review

Required (playbook rule 1: retention of user data; changes 3+ files). Reviewer is the other model family (D45); max two review rounds.
