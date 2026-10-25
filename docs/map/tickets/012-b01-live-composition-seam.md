---
id: 012
title: "B01 Live composition seam"
labels: [wayfinder:build]
status: open
blocked_by: []
assignee:
created: 2026-10-25
---

# B01 Live composition seam

Map: [[2026-10-25-wayfinder-map]]. Concept: [[2026-10-25-architecture-concept-v2]], [[2026-10-25-architecture-concept-v2.1]].

## Goal

Let the existing prototype switch between fixture and live data at the composition root, and give the live path a correct session lifecycle.

## Concept references

v2 §2.2 (session lifecycle, `SessionScope`); v2.1 §3.2–3.4 (B01).

## Exit criteria (tests that prove it)

- `Dependencies.live(...)` and `.fixture` selectable by launch argument; Debug default stays fixtures; `KizukiTestSupport` stays `#if DEBUG` with a release-build symbol check.
- `AppSession.refreshProfile()`, derived root phases (entry, verifyEmail, passwordRecovery, eligibility, onboarding, main, deleted), `SessionScope` cancels tasks and channels on sign-out and account switch: unit tests.
- Swift contract-replay harness reads `ios/Tests/Contracts/*.json` (empty set allowed).
- Tab bar regression (v2.1 §4.6): VoiceOver labels and screenshots on iOS 26 and iOS 17 simulators.
- Live run reaches the signed-out entry against the local stack.
- All 27 existing Swift tests and 6 UI tests still pass.

## Risk class

3+ files (iOS composition, session).

## Cross-model review

Required (playbook rule 1: changes 3+ files). Reviewer is the other model family (D45); max two review rounds.
