---
id: 031
title: "B20 Staging deploy + seed + smoke"
labels: [wayfinder:build]
status: open
blocked_by: [012,013,014,015,016,017,018,019,020,021,022,023,024,025,026,027,028,029,042]
assignee:
created: 2026-10-25
---

# B20 Staging deploy + seed + smoke

Map: [[2026-10-25-wayfinder-map]]. Concept: [[2026-10-25-architecture-concept-v2]], [[2026-10-25-architecture-concept-v2.1]].

## Goal

Staging carries the full schema and fictional data, and every flow passes a smoke run against it.

## Concept references

v2 §3; v2.1 §3.4 (B20), §3.5 (deferred live cases).

## Exit criteria (tests that prove it)

- Marker bootstrap and migrations/functions/secrets/auth config through `kz-remote.sh` only.
- Staging loader (Admin API users, Storage uploads) with ref and marker checks.
- Smoke checklist: every flow on a simulator against staging; Apple and device-push items listed as deferred if ticket 006 is open.
- No production contact (validator and gateway logs).

## Risk class

ENV.

## Cross-model review

Required (playbook rule 1: remote environment; changes 3+ files). Reviewer is the other model family (D45); max two review rounds.

## From VF08 (2026-10-25)

Design: [[2026-10-25-vf08-env-bootstrap]] sections 5-8 and 11.5. Execute the first deploy in this order: `doctor`, `verify`, witness over the `supabase-staging` MCP + `bootstrap`, `verify`, `migrate`, auth settings (Tier M or dashboard checklist), functions + function secrets, Vault (`vault-set`), `seed`, `verify` + smoke.

- Prerequisites from the user: staging pooler host in `staging.pin`, staging DB password and secret key in Keychain, publishable key in `Staging.private.xcconfig`, `supabase-staging` MCP authorised.
- Exit adds tests L1-L7: pristine `verify` + equal witness; bootstrap then `verify`, second bootstrap refused with `bootstrapped_at` unchanged; `list_migrations` equals repo versions; `/auth/v1/settings` flags, 9-char password rejected, numeric sign-up code; staging build probe passes and a stub answering `production`/`unmarked` gives `backend-refused` with no auth request; production baseline unchanged (read-only production MCP) and gateway log shows only pinned hosts.
- Add the manual CI job `staging-verify` (`workflow_dispatch`, environment `staging` with required reviewer, `main` only, Tier-P secrets, `verify` then `migrate`/`seed`; never `bootstrap`, never a PAT). G13 must still pass.
- If no staging-only management token exists: auth settings and function secrets are the dashboard checklist; record the checklist result in the lane note.
- Free-plan built-in mail is rate-limited **[unverified]**; plan the sign-up smoke around it (seeded users or custom SMTP, OD-15).
