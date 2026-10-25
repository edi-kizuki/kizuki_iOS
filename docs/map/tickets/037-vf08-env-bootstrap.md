---
id: 037
title: "VF08 Environment bootstrap and runtime production barrier"
labels: [wayfinder:followup]
status: closed
blocked_by: []
assignee:
created: 2026-10-25
---

# VF08 Environment bootstrap and runtime production barrier

Map: [[2026-10-25-wayfinder-map]]. Concept: [[2026-10-25-architecture-concept-v2]], [[2026-10-25-architecture-concept-v2.1]].

## Goal

Define the first-deploy bootstrap and the independent runtime production refusal (F08).

## Concept references

v2 §3; verification F08.

## Exit criteria (tests that prove it)

Design: [[2026-10-25-vf08-env-bootstrap]]. Test IDs below are defined there (section 11). "No remote writes" = sockets patched to fail the test, fake `supabase`/`psql` on PATH record argv, empty record asserted.

- First deploy identity before schema/marker: G6, G7, G8, G9 (pristine fake DB; witness missing, wrong, right; second run; edited bootstrap file; empty production target refused in the static stage with zero driver calls).
- Marker enforced afterwards: G6 (pristine + `migrate` refused; `production`, other ref, `local`, zero-row, non-pristine-unmarked all refused), E1-E3, E5 (pgTAP: singleton, immutable, no grants, double-run guarded).
- `AppConfiguration` rejects `.production` independently of the validator: A1, A2, A10 (server probe), A12, A13.
- Unapproved host / lookalike / userinfo / port / scheme: A3, G16 (Python mirror).
- Override and link state: G1, G2, G3.
- Wrong pooled endpoint: G4.
- Redirects: A8, A9, G5.
- Unset or wrong marker at runtime: A10, F5, E4.
- Empty production: G9, A10, L6.
- Functions refuse production at runtime: F1-F7. Scripts: exit 78 with a code (G1-G4). App: `backend-refused` screen, zero requests (A10, A13).
- CI/agents hold no production-capable token: G2, G10, G13, G14, G17.
- Drift between the four pin files: G12.
- Staging first deploy proofs (run in B20, ticket 031): L1-L7.

## Risk class

ENV.

## Cross-model review

Required (playbook rule 1: environment safety; changes 3+ files). Reviewer is the other model family (D45); max two review rounds.

## Resolution

Closed 2026-10-25. Design: [[2026-10-25-vf08-env-bootstrap]] (amends v2 section 3 items 4-5 and the v2.1 B03/B20 rows). No code, `ios/`, `supabase/` or `scripts/` files changed.

- (a) Circle broken: the marker is **not a migration**. `supabase/bootstrap/env_marker.sql` (schema `kizuki_env`, singleton, immutable, no grants, sha256 pinned) is run by exactly one gateway command, `kz-remote.sh bootstrap`, only in state S0 (pristine, no marker), as role `postgres` over the staging pooled session with the project-scoped staging DB password. After it, every command requires state S1 (marker = staging + exact ref). No force flag.
- (b) Identity before the first write: static pins (exact API host, pooler host and `postgres.<ref>` user, no overrides, no link state, no proxy, no redirects, denied ref nowhere), credential binding, Admin API probe with the staging secret key, and a **witness**: `pg_postmaster_start_time()` read over a second channel pinned to staging (the `supabase-staging` MCP or dashboard) must equal the CLI session's value.
- (c) Order: doctor, verify, witness + bootstrap (marker first), migrate, auth settings, functions + function secrets, Vault, seed, verify + smoke.
- (d) No production-capable token in scope: Tier P (staging DB password, staging secret key) for all writes; Tier M (PAT) only if `GET /v1/projects` shows no other project, else dashboard checklist; CI never bootstraps and never holds a PAT; PR workflows never see the `staging` environment.
- (e) MCP vs CLI: CLI is the sole writer. MCP is read-only plus the witness; `apply_migration` and write `execute_sql` are forbidden (version drift, gate bypass). Documented MCP-bootstrap fallback runs the identical self-guarded SQL file.
- (f) Runtime production refusal, independent of xcconfig: compiled-in `BackendAllowlist`; `.production` always throws `productionDisabled`; one guarded client factory (host check, denied ref, no redirects); a launch **server probe** `public.kizuki_environment()` that must answer `staging` + exact ref before any auth call; scripts exit 78 with a code before any socket; Edge Functions answer 503 `environment_refused` after checking `SUPABASE_URL` host, request host and the marker; SQL `net.http_post` callers check `private.url_allowed_for_environment`.
- Build tickets: [[014-b03-environment-pinning]] and [[031-b20-staging-deploy-seed]] updated; [[013-b02-backend-backbone]] must not ship a marker migration (note appended there).

Needs the user (defaults taken, none blocking the design):
1. Staging **pooler host** (region), for `staging.pin`. Dashboard Connect panel. B03 cannot finish its pin test without it.
2. Staging **DB password**: reset it in the staging dashboard (fresh, never reused anywhere) and store it in the macOS Keychain item `kizuki-staging-db`; also the staging secret key as `kizuki-staging-secret`.
3. Staging **publishable key** and authorising the `supabase-staging` MCP (agents can then read it with `get_publishable_keys`).
4. Tier M: is a staging-only organisation / account for a management token acceptable? If not, auth settings and function secrets are dashboard steps in v0.
5. Run `supabase logout` and consider agent deny rules for bare `supabase` commands.

Unverified until run: PAT scope by organisation membership, env token overriding keyring login (G17), hosted auth config push, Realtime socket coverage by the injected session (A11), Free-tier mail limits for the B20 sign-up smoke.
