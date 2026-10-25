---
id: 014
title: "B03 Environment pinning + bootstrap"
labels: [wayfinder:build]
status: open
blocked_by: [037]
assignee:
created: 2026-10-25
---

# B03 Environment pinning + bootstrap

Map: [[2026-10-25-wayfinder-map]]. Concept: [[2026-10-25-architecture-concept-v2]], [[2026-10-25-architecture-concept-v2.1]].

## Goal

Make it impossible for a v0 build or script to reach anything but local or the approved staging project.

## Concept references

v2 §3; v2.1 §3.4 (B03); ticket 037 (VF08).

## Exit criteria (tests that prove it)

- `AppConfiguration`: exact staging host allowlist; `.production` refused at runtime; Swift tests incl. the unapproved-host probe.
- Validator refuses Production and unapproved staging hosts; Python tests.
- `Staging.xcconfig` → `club.kizuki.ios` + staging URL (D43); key stays in git-ignored private xcconfig.
- `scripts/remote/kz-remote.sh` with first-deploy bootstrap per VF08; negative tests (wrong ref, link state, pooled endpoint, redirect, empty production) run with no remote writes.
- CI fails if any other script contains remote mutation commands.

## Risk class

ENV.

## Cross-model review

Required (playbook rule 1: environment safety; changes 3+ files). Reviewer is the other model family (D45); max two review rounds.
