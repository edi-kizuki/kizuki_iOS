---
id: 015
title: "B04 Email auth + eligibility + deletion v1"
labels: [wayfinder:build]
status: open
blocked_by: [012,013,014,038]
assignee:
created: 2026-10-25
---

# B04 Email auth + eligibility + deletion v1

Map: [[2026-10-25-wayfinder-map]]. Concept: [[2026-10-25-architecture-concept-v2]], [[2026-10-25-architecture-concept-v2.1]].

## Goal

Real email/password accounts with code verification and recovery, the 18+/Terms gate first, and a working minimal account deletion.

## Concept references

v2 §2.8, §4.7; v2.1 §3.3 (`freeze_account` v1), §3.4 (B04).

## Exit criteria (tests that prove it)

- Sign-up, verify code, sign-in, sign-out, recovery by code; templates with `{{ .Token }}`; `passwordRecovery` handled.
- `accept_terms`, `decline_eligibility`, `caller_ok()` enforced; pgTAP shows an ineligible caller reads nothing of others.
- `begin_account_deletion`, `freeze_account` v1, auth-only `delete-account`, `purge-abandoned-signups`; deletion pgTAP.
- Live API suite: sign-up → Mailpit code → verify → recovery → old password rejected.
- Live Swift run: real app on a simulator with `-live` against the local Supabase stack, second user scripted; `.xcresult`, screenshots and a run note in `docs/lanes/` (v2.1 §3.5). Reviewer re-runs it. Flow: sign-up → code → eligibility → recovery; under-18 deletes the account.
- Contract recordings for auth repositories committed. Every slice: tests start from an empty local DB with migrations up to this slice only (`scripts/test-prefix.sh <slice>`); fixture UI tests stay green; new UGC surfaces have Report; user-linked tables extend `private.freeze_account` and the FK matrix (v2.1 §3.3).

## Risk class

AUTH + DELETE.

## Cross-model review

Required (playbook rule 1: auth and deleting data; changes 3+ files). Reviewer is the other model family (D45); max two review rounds.

## From PR #2 review round 2 (2026-10-26)

See [[2026-10-25-pr2-b01-review-claude]].
- F-01: recovery marker needs an abort path (failed/abandoned recovery must not force the next sign-in into Set new password).
