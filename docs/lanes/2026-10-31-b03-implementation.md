# B03 environment pinning and bootstrap gateway

Related: [[014-b03-environment-pinning]], [[037-vf08-env-bootstrap]], [[2026-10-25-vf08-env-bootstrap]], [[2026-10-31-staging-connection-handoff]], [[2026-10-31-production-baseline]], [[013-b02-backend-backbone]], [[031-b20-staging-deploy-seed]], [[AGENTS]], [[README]].

Author: GPT-6 Astra. Reviewer: Claude Fable 5.1 (pending). Reviewed SHA: pending.

## Scope and decisions

The compiled app allowlist rejects production before URL/key parsing. The SDK client is created only after a successful marker probe. Its HTTP transport rejects other origins, denied references, redirects and mismatched response origins. Probe failure leaves auth storage untouched. Fixture and live composition reject invalid environments before creating repositories. The refusal screen has accessibility identifier `backend-refused`.

Production xcconfig has no URL or private include. The build validator always rejects Release/production. Staging requires the approved host. Static gates check pin drift, the single SDK factory, marker isolation, workflow credential policy and the remote command boundary.

The standalone marker is hash-pinned, singleton and immutable. It has no client grants. A migration supplies the public probe and private outbound URL guard. Local reset applies the local marker after normal migrations. B02 schema work and B20 deployment jobs are outside this change.

The gateway pins the staging API, tenant, database, pooler host, transaction port 6543 and session port 5432. SQL uses the session port. Static refusals exit 78 with a code. No target overrides, management tokens, proxies or conflicting link state are accepted. Bootstrap requires pristine state, the exact SQL hash, project-scoped credentials, a successful Admin API probe and the independent witness. It is refused in CI. Migration history must match a prefix of repository versions.

SQL driver: `psycopg[binary]==3.2.13`, installed from `scripts/remote/requirements.txt`. No host `psql` is required. Credentials remain in memory; passwords never become command arguments or files. Remote migration SQL and its history entry execute together in a transaction. The gateway never invokes the Supabase CLI, reads its credential store, or sets a management-token variable. The local stack continues using `npx --yes supabase@2.122.0`; local marker/tests use `psql` inside the local database container.

G10 and G17 follow the October 31 user decision: all management commands are offline dashboard checklists; every management token is refused. G17 proves the Tier-P path invokes neither CLI nor token store. The earlier design's dummy-token export is intentionally absent.

`seed` validates all records before a write and requires an in-process pipe handoff plus a fresh marker read. Direct loader execution is refused. B20 supplies `seed/staging.json` and any Storage-specific seed operations. An absent dataset produces `E_SEED_PENDING`.

The Edge Function wrapper checks configuration at cold start and request origin before probing. A successful marker result is cached for 60 seconds; failures are never cached. Failed guards return 503 with `environment_refused`. No consumer function is included.

## Validation evidence

- Python gateway: 16 tests, sockets patched to fail, fake Supabase/psql/npx/security commands on PATH. Static refusal cases invoke none of them. Child Python processes install the same socket tripwire.
- Python release configuration/artifact: 11 tests pass, including G16 and JWT reference binding.
- Python local guard: 2 tests pass.
- Deno F1–F7: 6 tests pass, with no network permission. Only the shared wrapper calls `Deno.serve`.
- Local reset passes. Local pgTAP: 52 assertions pass. Three additional pgTAP assertions execute the actual bootstrap body to prove double-run and non-pristine refusals. Local Auth/profile/RLS API checks pass.
- Pin, mutation and workflow policy gates pass. `actionlint` passes. Offline `doctor` passes.
- Non-Debug runtime guard: 4 cases pass.
- Final `./scripts/check-ios.sh`: 140 passed, 2 skipped, 0 failed on iPhone 17 Pro, iOS 26.0.1, arm64. Parameterized executions: 158 passed. A13 fixture/live refusal passed at accessibility XXXL. Result: `.build/Tests-20261031-164349.xcresult`.
- Staging build and artifact check pass. Release check passes by confirming unconditional production refusal in the configuration validator.
- Earlier parallel build attempts exhausted disk space. Generated build products were cleaned with `xcodebuild clean`; final sequential retries passed.

A1–A11 are in `EnvironmentGuardTests.swift`; A12 is the source gate; A13 is the fixture/live refusal UI test at accessibility XXXL size. G1–G15/G17 are in the gateway/static tests, G16 in release-config tests. E1–E4 are in pgTAP, E5 executes the bootstrap body from the actual pinned file, and E6 is the migration mutation scan.

## Pending and limits

- Fable's independent review and reviewed SHA.
- Production baseline: no read-only production MCP was exposed. No production connection was attempted. L6 remains pending.
- All B20 live proofs L1–L7, including the first user-witnessed staging bootstrap. Zero remote writes occurred during B03.
- Auth settings, function deployment and function secrets remain dashboard checklist steps. No Tier M support or staging CI deployment job is added.
- Realtime: source inspection of SDK 2.55.4 shows the shared session is supplied to RealtimeV2. WebSocket interception through URLProtocol is not proven. The validated origin is the construction guarantee; there is no Realtime consumer in this slice.
- Seed data and consumer functions are subsequent-ticket work.
- Two opt-in iOS local live smoke tests were skipped because those test modes were not enabled. Local backend Auth/profile/RLS integration checks passed separately.

## Reproducing checks

```sh
python3 -m venv .build/b03-checks
. .build/b03-checks/bin/activate
python3 -m pip install -r scripts/requirements-checks.txt
python3 scripts/test-remote-guard.py
python3 scripts/test-release-config.py
python3 scripts/test-local-guard.py
python3 scripts/check-env-pins.py
python3 scripts/check-remote-mutations.py
python3 scripts/check-workflow-policy.py
npx --yes deno@2.5.6 test --allow-read=supabase/functions supabase/functions/_shared/env_guard_test.ts
./scripts/remote/kz-remote.sh doctor
./scripts/supabase-local.sh start
./scripts/supabase-local.sh reset
./scripts/supabase-local.sh test
./scripts/check-ios.sh
./scripts/test-release-runtime-guard.sh
./scripts/check-release-build.sh Staging
./scripts/check-release-build.sh Release
```

The PostgreSQL driver is unnecessary for offline gateway tests. Install `scripts/remote/requirements.txt` in the operator's environment before the separately authorised B20 deployment. B03 does not run those remote commands.
