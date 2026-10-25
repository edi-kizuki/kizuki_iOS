---
id: 018
title: "B07 Requests + Crew"
labels: [wayfinder:build]
status: open
blocked_by: [017,033,041]
assignee:
created: 2026-10-25
---

# B07 Requests + Crew

Map: [[2026-10-25-wayfinder-map]]. Concept: [[2026-10-25-architecture-concept-v2]], [[2026-10-25-architecture-concept-v2.1]].

## Goal

Requests both ways, Crew connections with generations, Remove from Crew, minimal block, accept opens the chat.

## Concept references

v2 §4.4–4.5; v2.1 §1 (whole), §3.4 (B07), §4.3–4.4.

## Exit criteria (tests that prove it)

- Tables `requests`, `request_decline_reasons`, `crew_connections`, `conversations`, `conversation_participants`; RPCs send/respond/withdraw/`remove_from_crew`, minimal `block_user`/`unblock_user`; outbox enqueue triggers; cooldown; `can_view_profile` v2; `on_project_left_published` v2.
- v2.1 §1.6 T1–T9 as pgTAP + race harness (accept/accept, accept/close, accept/remove, remove/remove, send/withdraw).
- UI copy "Wish to Collab" / "Join project" (D52); accept navigates to the conversation (D53).
- Live Swift run: real app on a simulator with `-live` against the local Supabase stack, second user scripted; `.xcresult`, screenshots and a run note in `docs/lanes/` (v2.1 §3.5). Reviewer re-runs it. Flow: Join project → owner accepts → app lands in chat (T11); Remove from Crew shows read-only history.
- Every slice: tests start from an empty local DB with migrations up to this slice only (`scripts/test-prefix.sh <slice>`); fixture UI tests stay green; new UGC surfaces have Report; user-linked tables extend `private.freeze_account` and the FK matrix (v2.1 §3.3).

## Risk class

PRIVACY (definer RPCs, locks, multi-party state).

## Cross-model review

Required (playbook rule 1: core state machine, 3+ files; changes 3+ files). Reviewer is the other model family (D45); max two review rounds.
