---
id: 041
title: "VF12 Apply prototype decisions"
labels: [wayfinder:followup]
status: open
blocked_by: []
assignee:
created: 2026-10-25
---

# VF12 Apply prototype decisions

Map: [[2026-10-25-wayfinder-map]]. Concept: [[2026-10-25-architecture-concept-v2]], [[2026-10-25-architecture-concept-v2.1]].

## Goal

Apply D52–D57 to the prototype and specs: copy, accept-to-chat, media-only Search with video, Kizuki tab icons, Get discovered (F11, F13, F14, F26).

## Concept references

v2.1 §4.3–4.7.

## Exit criteria (tests that prove it)

- Copy "Wish to Collab" / "Join project"; accept routes to chat in the fixture backend; prototype tests updated (incl. the old block/unblock expectation).
- Answer the video open questions (v2.1 §4.5) with the user: duration, audio, autoplay, Free-plan limits.
- Get discovered card on own Profile; chooser keeps two options.
- Replace traced tab icons with designer vector originals when exported; screenshots on iOS 26 and iOS 17.

## B01 review R-06 transfer (2026-10-26)

- Owns the deferred iOS 17 half of [[012-b01-live-composition-seam]] tab regression criterion. `xcrun simctl list runtimes` lists only iOS 26.0 (26.0.1, 23A8464). About 7 GB is free. The user explicitly prohibited downloading a runtime and directed this transfer.
- Exit test: on an installed iOS 17 simulator, run `PrototypeFlowUITests.testDebugDefaultAndTabBarAccessibilityScreenshots`; retain all five selected/unselected tab screenshots and verify VoiceOver labels, selection, contrast and clipping.
- Keep the iOS 26 evidence in B01. This transfer does not claim iOS 17 compatibility was verified.

## Risk class

3+ files (UI).

## Cross-model review

Required (playbook rule 1: changes 3+ files). Reviewer is the other model family (D45); max two review rounds.
