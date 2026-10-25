---
id: 037
title: "VF08 Environment bootstrap and runtime production barrier"
labels: [wayfinder:followup]
status: open
blocked_by: []
assignee:
created: 2026-10-25
---

# VF08 Environment bootstrap and runtime production barrier

Map: [[2026-10-25-wayfinder-map]]. Concept: [[2026-10-25-architecture-concept-v2]], [[2026-10-25-architecture-concept-v2.1]].

## Goal

Define the first-deploy bootstrap and the independent runtime production refusal (F08).

## Concept references

v2 §3; verification F08.

## Exit criteria (tests that prove it)

- First deploy: verify effective SQL and API identity (host, pooled endpoint, project ref from the database) before creating schema and the marker; marker enforced afterwards.
- `AppConfiguration` rejects `.production` independently of the build validator.
- Negative tests with no remote writes: unapproved host, override/link state, wrong pooled endpoint, redirects, unset or wrong marker, empty production.

## Risk class

ENV.

## Cross-model review

Required (playbook rule 1: environment safety; changes 3+ files). Reviewer is the other model family (D45); max two review rounds.
