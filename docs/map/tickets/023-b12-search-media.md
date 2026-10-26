---
id: 023
title: "B12 Search media + Post a collab"
labels: [wayfinder:build]
status: open
blocked_by: [022,041]
assignee:
created: 2026-10-25
---

# B12 Search media + Post a collab

Map: [[2026-10-25-wayfinder-map]]. Concept: [[2026-10-25-architecture-concept-v2]], [[2026-10-25-architecture-concept-v2.1]].

## Goal

Search shows only photos and short videos posted by creators (D55).

## Concept references

v2.1 §4.5; v2 §5.6.

## Exit criteria (tests that prove it)

- `collab_posts` (photo/video), `user-video` bucket with MIME and size limits, `duration_ms` CHECK.
- On-device video export (H.264 720p MP4, poster frame), upload, muted looping playback in the post viewer.
- Grid, chips, query; no people results.
- Live: post a photo and a video, both appear; oversize or wrong MIME rejected by Storage; auto-hide removes a post.
- Every slice: tests start from an empty local DB with migrations up to this slice only (`scripts/test-prefix.sh <slice>`); fixture UI tests stay green; new UGC surfaces have Report; user-linked tables extend `private.freeze_account` and the FK matrix (v2.1 §3.3).

## Risk class

3+ files (new media pipeline).

## Cross-model review

Required (playbook rule 1: changes 3+ files). Reviewer is the other model family (D45); max two review rounds.
