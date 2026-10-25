---
id: 034
title: "VF05 Report privileges and subject visibility"
labels: [wayfinder:followup]
status: open
blocked_by: []
assignee:
created: 2026-10-25
---

# VF05 Report privileges and subject visibility

Map: [[2026-10-25-wayfinder-map]]. Concept: [[2026-10-25-architecture-concept-v2]], [[2026-10-25-architecture-concept-v2.1]].

## Goal

Resolve the invoker/definer grant path for reports, enforce subject liveness before relationship exceptions, and persist reporter hides for every subject (F18, F19, F20).

## Concept references

v2 §2.3, §2.11; verification F18–F20.

## Exit criteria (tests that prove it)

- Owner, grants and revoke-default rules for `submit_report` and `private.file_report`; callee re-checks identity, subject and limits.
- Subject predicate (not suspended, not deleting, exists) evaluated before any relationship branch, in RLS, descendants and `recommend`.
- Persisted reporter hide for profiles, projects, posts, requests, messages and embeds across REST, Realtime and signed media.
- Tests: inaccessible subject, forged inputs, helper calls rejected, counterpart hidden/suspended/deleting/gone, relaunch visibility.

## Risk class

PRIVACY.

## Cross-model review

Required (playbook rule 1: authorization; changes 3+ files). Reviewer is the other model family (D45); max two review rounds.
