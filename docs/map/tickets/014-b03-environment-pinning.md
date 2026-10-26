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

## From VF08 (2026-10-25)

Design: [[2026-10-25-vf08-env-bootstrap]]. Test IDs (A, G, F, E) are defined in its section 11 and are this slice's exit criteria; ticket [[037-vf08-env-bootstrap]] lists them.

- App: `BackendAllowlist.swift` (not read from xcconfig); `.production` always `productionDisabled`; exact staging host; denied ref; `GuardedSupabase.makeClient` as the only `SupabaseClient(` call site; launch probe `kizuki_environment` before any auth call; `backend-refused` screen. Tests A1-A13.
- Config: `Staging.xcconfig` (D43, exact URL); `Production.xcconfig` with empty URL and no private include; validator fails Release/production unconditionally; invert `test_valid_public_configuration`. Tests G16.
- Gateway: `scripts/remote/{kz-remote.sh,kz_remote.py,kz_guard.py,staging.pin}` with commands `doctor`, `verify`, `bootstrap --witness`, `migrate`, `vault-set`, `seed`, `auth-config`, `functions-deploy`, `secrets-set`; static checks 5.2; states S0/S1/S2; exit 78 and codes. Tests G1-G11, G15, G17 with sockets patched and fake `supabase`/`psql`.
- SQL: `supabase/bootstrap/env_marker.sql` (hash pinned), `supabase/migrations/*_b03_environment_probe.sql` (`public.kizuki_environment`, `private.url_allowed_for_environment`), pgTAP `b03_env_marker.sql` (E1-E6). Local variant applied by `scripts/supabase-local.sh reset` after `db reset`.
- Functions: `_shared/env_guard.ts`, `_shared/serve.ts` (only place `Deno.serve` appears), Deno tests F1-F7. First consumer is `delete-account` (B04).
- CI: `check-env-pins.py` (G12), `check-remote-mutations.py` (G14), workflow lint (G13), no `SUPABASE_ACCESS_TOKEN` in any job.
- Before starting: record the **production baseline** through the read-only production MCP at `docs/lanes/<date>-production-baseline.md` (migrations, tables, auth user count). Needed for L6.
- Inputs needed from the user: staging pooler host (for `staging.pin`); Keychain items are not needed for B03 tests.

## From PR #2 review round 2 (2026-10-26)

See [[2026-10-25-pr2-b01-review-claude]].
- F-05: keep the release artifact denylist current as modules are added.
- F-04 (optional): app-level live UI smoke proving app-to-stack path.
