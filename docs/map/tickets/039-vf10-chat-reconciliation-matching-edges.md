---
id: 039
title: "VF10 Chat gap recovery and matching edge goldens"
labels: [wayfinder:followup]
status: open
blocked_by: []
assignee:
created: 2026-10-25
---

# VF10 Chat gap recovery and matching edge goldens

Map: [[2026-10-25-wayfinder-map]]. Concept: [[2026-10-25-architecture-concept-v2]], [[2026-10-25-architecture-concept-v2.1]].

## Goal

Guarantee no lost messages beyond the 5-minute overlap and define the last band edge cases (F23, F24).

## Concept references

v2 §2.6, §2.10; v2.1 §2.3, §5.2; verification F23, F24.

## Exit criteria (tests that prove it)

- Pick and document: enforced statement/transaction timeout on `send_message` shorter than the overlap, or a commit-aware cursor with full gap recovery; unread semantics compatible with late lower `seq`.
- Tests: delayed commit beyond 5 minutes, equal timestamps, reconnect, late lower-seq unread.
- Hand-computed goldens: favourites-only viewer, disjoint bridge, one-sided taste.

## Risk class

PRIVACY (chat) / minor (matching).

## Cross-model review

Required (playbook rule 1: changes 3+ files). Reviewer is the other model family (D45); max two review rounds.
