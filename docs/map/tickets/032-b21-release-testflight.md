---
id: 032
title: "B21 Release plumbing + TestFlight"
labels: [wayfinder:build]
status: open
blocked_by: [031,006,042]
assignee:
created: 2026-10-25
---

# B21 Release plumbing + TestFlight

Map: [[2026-10-25-wayfinder-map]]. Concept: [[2026-10-25-architecture-concept-v2]], [[2026-10-25-architecture-concept-v2.1]].

## Goal

First internal TestFlight build against staging.

## Concept references

v2 §8.2 (K20); v2.1 §4.1 (D46).

## Exit criteria (tests that prove it)

- Privacy manifest, export compliance key, purpose strings and entitlements complete, App Store age rating 18+.
- App Store Connect record, privacy answers, review notes, demo account.
- Staging on Pro before external testers (D46); legal confirmation of D49 before public launch.
- Archive validates; internal TestFlight install on a device.

## Risk class

ENV.

## Cross-model review

Required (playbook rule 1: changes 3+ files). Reviewer is the other model family (D45); max two review rounds.
