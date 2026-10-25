---
title: VF08 Staging bootstrap and runtime production barrier
created: 2026-10-25
tags: [project/kizuki, architecture-round, design, environment, safety]
status: final-for-build
resolves: [F08]
ticket: 037
amends: 2026-10-25-architecture-concept-v2.1
---

# VF08 Staging bootstrap and runtime production barrier

Related: [[2026-10-25-architecture-concept-v2.1]], [[037-vf08-env-bootstrap]], [[2026-10-25-concept-v2-verification-codex]]

See also: [[2026-10-25-architecture-concept-v2]] (section 3), [[2026-10-24-architecture-round-1-interview]] (#10, #29, #38, #43, #46), [[2026-10-25-wayfinder-map]], [[014-b03-environment-pinning]] (owner), [[031-b20-staging-deploy-seed]] (executes the first deploy), [[013-b02-backend-backbone]], [[2026-10-25-vf05-reports-visibility]].

## 0. Scope and how to read this

- Amendment to v2 section 3 (items 4 and 5, "Seeding staging", "Staging auth and secrets configuration") and the v2.1 B03 and B20 rows. Where this file and v2/v2.1 disagree, this file wins for those items.
- Resolves F08: the circular marker precondition, the missing runtime `.production` refusal, and the negative tests.
- **No code, `ios/`, `supabase/` or `scripts/` files are changed here.** SQL, Swift and Python snippets are sketches. Names, codes and checks are binding; bodies may be tightened by B03.
- Tags: **[design]** = my call. **[unverified]** = platform behaviour I could not confirm; the test that proves it is named.
- Facts used: staging `ankgfqkgflcalmlreetu` (Free, mock data, publishable key not yet supplied); production `enosggckdxjiaqtxalhg` untouched in v0; one bundle `club.kizuki.ios` (D43); TestFlight builds point at staging; agents reach staging through the MCP server `supabase-staging` (pinned to that ref), production MCP is read-only.

### 0.1 What goes wrong today (baseline, read from the repo)

| Gap | Where |
|---|---|
| `.staging` accepts any `*.supabase.co` except production | `AppConfiguration.swift`, `validate-release-config.py` |
| `.production` is accepted at runtime when the host is the production host | `AppConfiguration.swift` (`case .production`) |
| `Staging.xcconfig` has no URL and the old bundle id | `ios/Configuration/Staging.xcconfig` |
| `Production.xcconfig` carries the production URL | `ios/Configuration/Production.xcconfig` |
| The existing release test asserts that the production config is **valid** | `scripts/test-release-config.py::test_valid_public_configuration` |
| No remote gateway, no marker, no function-side guard | v2 section 3 is a plan only |

---

## 1. Principles

1. **Two independent layers per surface.** Build-time config is one layer. A compiled-in allowlist plus a server-side answer is the second. Neither reads the other's inputs.
2. **Fail closed, before any I/O.** Static checks run before a socket opens. A refusal never sends a key, a token or a row.
3. **A token that can reach production is never in scope.** Agents and CI hold only project-scoped credentials for staging. A management token is accepted only if it cannot see production.
4. **The marker is the permanent gate; bootstrap is the only door without it.** The door opens once, for one command, after identity is proven from two channels.
5. **One source of truth for the pins.** One constants block, mirrored in four places, with a drift test (section 9.5).

---

## 2. Credential tiers (answers "CI or agents run it without a production-capable token")

| Tier | Credential | Reach | Where it may live | Used by |
|---|---|---|---|---|
| **P** project-scoped | Staging DB password (user `postgres.ankgfqkgflcalmlreetu`); staging secret key (Admin API, Storage) | Staging only. Cannot address another project | macOS Keychain item `kizuki-staging-db` and `kizuki-staging-secret` on the operator machine; GitHub Environment `staging` (only for a manual deploy job, section 7) | bootstrap, migrations, Vault SQL, seed loader, read-only verify |
| **M** management | Supabase personal access token (`sbp_...`) | **Everything the owning account can see**, including production [unverified: no project-scoped PAT exists] | Only a token whose account is a member of **no organisation that contains production** (see below). Never CI | auth-config push, `functions deploy`, `secrets set` |
| **MCP** | Held by the `supabase-staging` MCP server | The pin is enforced by the server, not by the token behind it [unverified] | Operator's MCP config | agents: read-only inspection and the witness (section 8) |

**Tier M rule [design].** `kz-remote.sh` Tier-M commands first call `GET /v1/projects` with the token. If the list contains any ref other than `ankgfqkgflcalmlreetu` (in particular `enosggckdxjiaqtxalhg`), the command exits `E_TOKEN_SCOPE` before doing anything. So a Tier-M token works only if it is staging-only. How to get one: put staging in its own organisation and create the token from a separate account that is invited only to that organisation [unverified: organisation membership limits what a PAT sees]. If that is not possible, Tier-M commands are not run by tools in v0; they become the dashboard checklist in section 6 step 5-6, verified read-only afterwards.

**Never in scope for agents or CI:** a production DB password, a production secret key, a Tier-M token that can see production, a stored CLI login. Concretely:

- No production secret exists in the repo, CI or any agent environment. v0 never needs one.
- `SUPABASE_ACCESS_TOKEN` is unset by `scripts/supabase-local.sh` (already) and **refused** by `kz-remote.sh` for every Tier-P command (`E_TOKEN_PRESENT`). For Tier-P commands the gateway also exports a dummy `SUPABASE_ACCESS_TOKEN` so a token left by `supabase login` in the OS keyring cannot be used [unverified: env var takes precedence over the keyring; test G17 in section 9.2].
- Recommendation (user action, not enforced by this repo): run `supabase logout` once; add agent permission deny rules for a bare `supabase`/`npx supabase` outside `scripts/`.
- CI: every workflow asserts `test -z "$SUPABASE_ACCESS_TOKEN"` and contains no production string. PR workflows (including forks) never reference the `staging` environment (test G13).

---

## 3. The pins: one constants block

Four mirrored files. `scripts/check-env-pins.py` parses all four and fails on any difference (test G12).

| Constant | Value | Mirrors |
|---|---|---|
| `STAGING_REF` | `ankgfqkgflcalmlreetu` | `BackendAllowlist.swift`, `scripts/remote/kz_guard.py`, `supabase/functions/_shared/env_guard.ts`, `Staging.xcconfig` |
| `STAGING_API_HOST` | `ankgfqkgflcalmlreetu.supabase.co` | same four |
| `DENIED_REFS` | `[enosggckdxjiaqtxalhg]` | same three code files (not xcconfig) |
| `STAGING_DIRECT_DB_HOST` | `db.ankgfqkgflcalmlreetu.supabase.co` | `kz_guard.py` |
| `STAGING_POOLER_HOST` | `aws-N-<region>.pooler.supabase.com` **[needs the user: region]** | `kz_guard.py` via `scripts/remote/staging.pin` |
| `LOCAL_API` | `127.0.0.1:54321` and `localhost:54321` | app, `local_backend.py` |

`Staging.xcconfig` becomes `KIZUKI_BUNDLE_ID = club.kizuki.ios`, `SUPABASE_URL = https:/$()/ankgfqkgflcalmlreetu.supabase.co`, key in git-ignored `Staging.private.xcconfig` (D43). `Production.xcconfig` gets `SUPABASE_URL =` (empty) and no private include, so the repo carries no way to build a working production target in v0. The pooler host is committed in `staging.pin` through a reviewed PR, never learned at run time.

---

## 4. The marker and the bootstrap (fixes the circle)

### 4.1 Why it was circular

v2 says every remote write requires the marker, but B02 creates the marker table in a migration and a later bootstrap inserts the row. A pristine staging cannot pass the precondition for the migration that creates the marker.

### 4.2 Resolution [design]

1. **The marker is not a migration.** It lives in its own schema `kizuki_env`, created by a standalone file `supabase/bootstrap/env_marker.sql`. Migrations never create or modify it and never depend on it at create time.
2. **Three gateway states**, decided by one read-only query:

| State | Condition | Allowed commands |
|---|---|---|
| **S0 pristine** | `to_regclass('kizuki_env.environment_marker') is null` **and** no user tables in `public`, `private`, `kizuki_env` **and** `supabase_migrations.schema_migrations` absent or empty | `bootstrap`, `verify` only |
| **S1 staging** | marker row `environment='staging'` and `project_ref='ankgfqkgflcalmlreetu'` | all commands |
| **S2 wrong** | marker present with anything else, or table present without exactly one row, or S0 conditions partly true (not pristine, no marker) | **nothing** (`E_MARKER_WRONG` / `E_NOT_PRISTINE`) |

3. **The first-deploy exception is exactly one command**: `kz-remote.sh bootstrap`. It runs the pinned file in **one transaction** and nothing else. It is allowed only in S0 and only after the identity proof (section 5.3).
4. **After bootstrap, the marker is enforced on every command** (S1 required). There is no `--force`, no `--adopt`, no skip flag. A non-pristine unmarked project is repaired by recreating the project, not by relaxing the gate.

### 4.3 The file (sketch)

```sql
-- supabase/bootstrap/env_marker.sql  (sha256 pinned in kz_guard.py; the gateway refuses any other content)
begin;
do $$ begin
  if to_regclass('kizuki_env.environment_marker') is not null then
    raise exception 'already_bootstrapped' using errcode = 'P0001';
  end if;
  if exists (select 1 from pg_tables where schemaname in ('public','private')) then
    raise exception 'not_pristine' using errcode = 'P0001';   -- covers the MCP path too
  end if;
end $$;
create schema kizuki_env;
revoke all on schema kizuki_env from public, anon, authenticated;
create table kizuki_env.environment_marker (
  singleton boolean primary key default true check (singleton),
  environment text not null check (environment in ('local','staging')),
  project_ref text,
  api_host text,
  bootstrapped_at timestamptz not null default now(),
  bootstrapped_via text not null check (bootstrapped_via in ('cli','mcp','local')),
  bootstrap_sha256 text not null,
  check ((environment = 'staging' and project_ref = 'ankgfqkgflcalmlreetu'
                                   and api_host = 'ankgfqkgflcalmlreetu.supabase.co')
      or (environment = 'local' and project_ref is null))
);
alter table kizuki_env.environment_marker enable row level security;   -- no policies, no grants
revoke all on kizuki_env.environment_marker from public, anon, authenticated, service_role;
-- immutable: block UPDATE, DELETE, TRUNCATE
create function kizuki_env.deny_change() returns trigger language plpgsql as
  $$ begin raise exception 'marker_immutable'; end $$;
create trigger no_change before update or delete on kizuki_env.environment_marker
  for each row execute function kizuki_env.deny_change();
create trigger no_truncate before truncate on kizuki_env.environment_marker
  for each statement execute function kizuki_env.deny_change();
insert into kizuki_env.environment_marker (environment, project_ref, api_host, bootstrapped_via, bootstrap_sha256)
values ('staging', 'ankgfqkgflcalmlreetu', 'ankgfqkgflcalmlreetu.supabase.co', :'via', :'sha');
commit;
```

- The local variant is the same file with `environment='local'`, applied by `scripts/supabase-local.sh reset` **after** `db reset` (local gets its marker the same way; B02 no longer ships a marker migration, see section 10).
- **Public read paths [design]** (shipped as a normal migration `b03_environment_probe.sql`, safe because plpgsql binds late):
  - `public.kizuki_environment() returns jsonb` (`security definer`, `set search_path = ''`, EXECUTE to `anon`, `authenticated`, `service_role`): returns `{"environment": ..., "project_ref": ...}` or `{"environment":"unmarked"}` if the table is missing. Nothing else.
  - `private.url_allowed_for_environment(url text) returns boolean`: staging marker accepts only `^https://ankgfqkgflcalmlreetu\.supabase\.co(/|$)`; local marker accepts `http://kong:8000`, `http://host.docker.internal:54321`, `http://127.0.0.1:54321`; no marker → false. Every trigger or job that calls `net.http_post` (B18 push fast path, `resume-deletions`) must call it first and skip with a logged `env_refused` if false.
- The marker row is created by **role `postgres`** over the staging pooled session, using Tier-P credentials, run by the operator (or an agent on the operator's machine). It is never created by CI, never by a migration, never by `seed`.

### 4.4 Why this satisfies F08

- Identity is verified (section 5.3) **before** schema and marker exist, by checks that do not need the marker.
- The marker is then the permanent, in-database proof; every later command re-reads it.
- An empty production target passes "pristine" but fails the identity proof; it can never be bootstrapped or seeded (test G9).

---

## 5. `scripts/remote/kz-remote.sh` (the single staging-locked remote script)

`kz-remote.sh` is a thin wrapper around `scripts/remote/kz_remote.py` and `kz_guard.py`. Every remote effect in the repo goes through it (v2 section 3 item 4 stands). Sketch of the SQL driver: libpq `psql` or `psycopg`, behind a `SqlDriver` interface so tests inject a fake.

### 5.1 Commands

| Command | Tier | Needs state | Effect |
|---|---|---|---|
| `doctor` | none | none | Offline: runs all static checks (5.2); opens no socket |
| `verify` | P | S0 or S1 | Read-only: identity checks, marker, `schema_migrations` vs repo files, `/auth/v1/settings` flags |
| `bootstrap --witness <value>` | P | **S0 only** | Runs `env_marker.sql` in one transaction (`via=cli`) |
| `migrate` | P | S1 | `supabase db push --db-url <built internally>` (never `--include-seed`) |
| `vault-set <name>` | P | S1 | `vault.create_secret` over SQL; value from Keychain or stdin; never printed |
| `seed` | P | S1 | Runs `seed/load_staging.py` (section 5.5) |
| `auth-config` | M | S1 | PATCH hosted auth settings from `supabase/config.toml` values, or print the dashboard checklist |
| `functions-deploy`, `secrets-set` | M | S1 | Deploy / set function secrets |

`CI=true` or `GITHUB_ACTIONS=true` plus `bootstrap` exits `E_CI_BOOTSTRAP` (the first-deploy exception is operator-gated).

### 5.2 Static checks (run first, offline, for every command; any failure exits before a socket opens)

| # | Check | Code |
|---|---|---|
| 1 | Argument list contains none of `--project-ref`, `-p`, `--db-url`, `--linked`, `--local`, `link`, `--password`, `--workdir`, `--experimental`; subcommand is in the table above | `E_OVERRIDE` |
| 2 | Environment has none of `SUPABASE_PROJECT_ID`, `SUPABASE_DB_URL`, `DATABASE_URL`, `PGHOST`, `PGHOSTADDR`, `PGSERVICE`, `PGSERVICEFILE`, `PGOPTIONS`, `PGPASSFILE`, `HTTP_PROXY`, `HTTPS_PROXY`, `ALL_PROXY` (any case); `SUPABASE_ACCESS_TOKEN` absent for Tier P | `E_OVERRIDE` / `E_PROXY` / `E_TOKEN_PRESENT` |
| 3 | `supabase/.temp/project-ref`, if it exists, equals `STAGING_REF`; `supabase/.temp/pooler-url`, if it exists, names `STAGING_POOLER_HOST` with user `postgres.<STAGING_REF>`. Anything else: refuse (the gateway never deletes it) | `E_LINK_STATE` |
| 4 | The string in `DENIED_REFS` appears nowhere in argv, environment values, `supabase/.temp/*`, `~/.pgpass` entries for the pinned hosts, or the built URLs | `E_REF_DENIED` |
| 5 | **Built DSN** (the gateway builds it from pins plus the Keychain password; callers cannot pass one): host exactly `STAGING_POOLER_HOST` or `STAGING_DIRECT_DB_HOST`; user exactly `postgres.ankgfqkgflcalmlreetu` (pooler) or `postgres` (direct host); port 5432 (session mode; 6543 refused); db `postgres`; no query parameters other than `sslmode=require`; host is not an IP literal | `E_POOLER` |
| 6 | **API base URL** exactly `https://ankgfqkgflcalmlreetu.supabase.co` (scheme https, no userinfo, port, path, query, fragment; host compared case-sensitively after lowercasing, no trailing dot) | `E_HOST_NOT_ALLOWED` |
| 7 | HTTP client: no redirects followed (custom opener whose redirect handler raises), no proxy, TLS verification on, response `url` host re-checked | `E_REDIRECT` |
| 8 | Hash of `supabase/bootstrap/env_marker.sql` equals the pinned sha256 (bootstrap only) | `E_BOOTSTRAP_FILE` |

### 5.3 Identity proof before the first write (`bootstrap`)

All must hold, otherwise exit with the named code and **no write**:

1. Section 5.2 passes.
2. **Credential binding.** Login succeeds with the Keychain staging password at the pinned host and tenant user. That password is staging-only by procedure: it was generated fresh by the user in the staging project's dashboard and was never set on production.
3. **API channel.** `GET https://ankgfqkgflcalmlreetu.supabase.co/auth/v1/admin/users?per_page=1` with the staging secret key returns 200; if the secret key is a legacy JWT its `ref` claim equals `STAGING_REF`. (A key only validates on its own project.)
4. **State S0** (section 4.2).
5. **Witness [design].** The gateway prints the fingerprint it sees over SQL, `pg_postmaster_start_time()::text`, and requires `--witness "<value>"` obtained over a **second channel pinned to staging**: the `supabase-staging` MCP `execute_sql` (`select pg_postmaster_start_time()::text`) or the staging dashboard SQL editor. Equal values prove that the CLI session and the pinned second channel talk to the same server. Wrong or missing: `E_WITNESS`. A production MCP or a production CLI session returns a different value. (The witness proves that the operator did not aim at a different server; it is not an authentication factor.)
6. `--witness` is accepted only by `bootstrap`. `verify` prints the fingerprint so the witness can be rehearsed without writing.

Then the gateway opens one transaction, runs the file with `via='cli'` and the file hash, commits, and re-reads the row. A mismatch after commit exits `E_MARKER_WRONG` loudly (nothing else can follow).

### 5.4 Every command after bootstrap

After 5.2: read the marker; require S1 (`E_MARKER_ABSENT`, `E_MARKER_WRONG`). `migrate` re-reads the marker inside its own connection immediately before `db push`; a race with a changed marker is impossible because the row is immutable, but the re-read also guards against reconnecting to a different server mid-run.

### 5.5 Seed loader

`seed/load_staging.py` imports `kz_guard` and refuses to run outside `kz-remote.sh` (`E_NOT_VIA_GATEWAY`: it checks a per-run token the gateway passes through a file descriptor, not the environment). Order of calls inside it: (1) static checks, (2) read marker, (3) first write. Every seeded email must end `@seed.kizuki.test`; every URL host must equal `STAGING_API_HOST`; a mismatch aborts the whole run before the first write (the check runs over the full generated list up front).

---

## 6. First-deploy order (executed by B20; rehearsed offline by B03)

Order and reason:

| Step | Command | Why here | Credentials |
|---|---|---|---|
| 0 | `kz-remote.sh doctor` and the offline test suite | Nothing reaches the network until the guard is green | none |
| 1 | `kz-remote.sh verify` | Read-only: prove identity channels, detect S0, print the witness fingerprint | P |
| 2 | **Witness** over `supabase-staging` MCP (or dashboard), then `kz-remote.sh bootstrap --witness ...` | **Marker first.** Everything after is gated | P (+ MCP read) |
| 3 | `kz-remote.sh verify` again | Marker read back; state S1 | P |
| 4 | `kz-remote.sh migrate` | Schema, RLS, functions, cron entries. Contains no URLs, keys or user rows (existing CI grep) | P |
| 5 | `kz-remote.sh auth-config` (Tier M) **or** dashboard checklist | Auth settings must exist before the first sign-up or seeded user: email confirmations on, min password 10, OTP-code templates (`{{ .Token }}`) for signup and recovery, JWT expiry, site URL, linking per D47, SMTP once OD-15 lands. Free-tier default mail is rate-limited **[unverified limit]**; the smoke needs custom SMTP or a prior seed login path | M or human |
| 6 | `kz-remote.sh functions-deploy`, `secrets-set` (Tier M) **or** dashboard / `supabase-staging` MCP `deploy_edge_function` of the repo files | Functions after schema (they call RPCs); function secrets before Vault so the two copies of each shared secret come from one generated value | M or human |
| 7 | `kz-remote.sh vault-set push_function_url`, `vault-set job_secret`, ... | Vault entries for the push trigger and the cron drain. URL value must pass `private.url_allowed_for_environment` | P |
| 8 | `kz-remote.sh seed` | Last: needs auth settings (min password, confirm flags), Storage buckets from migrations, and the marker | P |
| 9 | `kz-remote.sh verify` plus smoke checklist | B20 exit | P |

The staging publishable key is needed for the **app**, not for the deploy. It can be taken from the dashboard or from `supabase-staging` MCP `get_publishable_keys` once that server is authorised, and goes into git-ignored `Staging.private.xcconfig`. The validator checks its format only.

### 6.1 Hosted auth settings

- `supabase config push` and the Management API `PATCH /v1/projects/{ref}/config/auth` can set most of the fields above **[unverified for CLI 2.122.0 and for this plan]**. B20 proves it or falls back to the checklist.
- Verification without Tier M: `GET /auth/v1/settings` (public, with the publishable key) must show `mailer_autoconfirm == false`, `disable_signup == false`, `external.email == true`. Password minimum and OTP template are proven behaviourally in the B20 smoke: a 9-character password sign-up returns `weak_password`; the sign-up email contains a numeric code and no link.

---

## 7. How CI and agents run it

| Actor | May run | May not run | Credentials |
|---|---|---|---|
| **CI (PR and main)** | `doctor`, `scripts/test-remote-guard.py`, `check-env-pins.py`, `check-remote-mutations.py`, Swift and Deno guard tests, pgTAP for the marker file against the **local** stack | Any command that opens a connection to a remote host | none |
| **CI manual job `staging-verify`** (added by B20, `workflow_dispatch` only, environment `staging` with required reviewer, `main` only) | `verify`, later `migrate`, `seed` | `bootstrap`, Tier M | Tier-P secrets from the environment; asserts `SUPABASE_ACCESS_TOKEN` unset |
| **Agents (Codex/Claude on the operator machine)** | Everything in 5.1 except Tier M unless a staging-only token exists; MCP read-only calls and the witness | Direct `supabase ... --project-ref`, `supabase link`, MCP `apply_migration`, write `execute_sql`, production MCP anything but read | Tier-P from Keychain (read by the gateway, never by the agent), no token in env |
| **Operator (Edison)** | Dashboard steps in 5-6 if no staging-only token; resetting the staging DB password | | |

Repo gate (extends v2): `scripts/check-remote-mutations.py` fails CI if any file other than `scripts/remote/*` contains `db push`, `functions deploy`, `secrets set`, `supabase link`, `--db-url`, `--project-ref`, `config push`, `api.supabase.com`, or the denied ref; it scans `.github/workflows/`, `scripts/`, `docs/` runbooks excluded.

---

## 8. MCP path versus CLI path

| Concern | CLI path (`kz-remote.sh`) | MCP path (`supabase-staging`) |
|---|---|---|
| Role | **Canonical writer** | Observer and witness |
| Writes | bootstrap, migrations, Vault, seed | **None in v0.** No `apply_migration`: it stamps its own version into `supabase_migrations`, so a later `db push` sees remote-only versions. No write `execute_sql`: it skips the marker gate |
| Reads | `verify` | `list_tables`, `list_migrations`, `get_advisors`, `get_logs`, select-only `execute_sql`, `get_project_url`, `get_publishable_keys` |
| Identity | Pins + credential binding + marker | The server pin (a second, independent channel); used for the witness |
| Production | Impossible by 5.2 | Production MCP is read-only; used only to record the baseline (L6) and compare after B20 |
| Fallback if no staging DB password is ever supplied | none (the plan needs it) | **MCP bootstrap fallback [design]:** the agent runs the byte-identical `env_marker.sql` via `execute_sql` with `via='mcp'`. The file's own `not_pristine` and `already_bootstrapped` guards still apply and the hash is recorded; identity is then the MCP pin only. After that every other step still needs Tier P |

`supabase-staging` currently needs OAuth authorisation by the user before any of this works.

---

## 9. Runtime production refusal

### 9.1 App at launch (`KizukiCore`, `KizukiInfrastructure`)

New file `BackendAllowlist.swift` holds the section 3 constants. It is **not** read from xcconfig or Info.plist. Order of checks, each throwing a distinct error before the next runs:

1. `AppConfiguration.init`: `environment == .production` → `ConfigurationError.productionDisabled`, always, before URL parsing, with any URL and key. (`AppEnvironment.production` stays as a parsed value so the error is explicit; no code path constructs a working production configuration.)
2. Host check, `.staging`: URL parsed with `URLComponents`; scheme `https`; `host` lowercased equals `BackendAllowlist.stagingHost` exactly; no userinfo, port, query, fragment, path beyond `/`; no `$(`. Also: the absolute string contains no denied ref. Failure: `ConfigurationError.backendDenied`. `.local`: scheme `http`, host in {`127.0.0.1`, `localhost`}, port 54321.
3. Key check: unchanged format check (publishable or anon, never secret/service role). New: if the key is a JWT with a `ref` claim, it must equal the staging ref (`backendDenied` otherwise). Opaque `sb_publishable_` keys cannot be checked locally; step 5 covers them.
4. **One client factory.** `GuardedSupabase.makeClient(_ config:)` is the only place `SupabaseClient(` is called (CI grep, test A12). It passes a `URLSession` whose delegate/`URLProtocol` (a) rejects any request whose URL host is not the configuration host, (b) rejects any URL containing a denied ref, (c) cancels every redirect, (d) rejects a response whose `url.host` differs from the request. Realtime's WebSocket URL is derived from the same validated `supabaseURL` **[unverified: whether the injected session also covers the Realtime socket; test A11]**.
5. **Server identity probe.** Before enabling any sign-in, sign-up, session restore or RPC, the app calls `POST /rest/v1/rpc/kizuki_environment` once with the publishable key and no session. The response must be exactly `environment == <expected for this build>` and `project_ref == STAGING_REF` (local build: `environment == "local"`). Timeouts, non-200, unknown shape, `unmarked`, `production`, a different ref: state `.backendRefused`. This is independent of every build setting: a staging-looking URL that points at a project without the marker (for example an empty production) fails.

**Failure behaviour (app).** The root shows the existing non-crashing setup screen with copy "This build can't connect to its server" (accessibility id `backend-refused`), no retry that bypasses the check; a "Try again" re-runs only the probe. Zero auth, REST, Storage or Realtime requests are sent; no Keychain session read or write (the session key is derived only after the probe passes); one log line `backend_refused code=<E_...>` with no URL and no key. No crash, no `fatalError`, in Debug and Release. Offline at launch: same screen with an "offline" variant; sign-in stays disabled. Cached probe success is valid for the process lifetime only.

**Build time (kept, not relied on).** `validate-release-config.py`: `Release` (production) **fails unconditionally** with "Production builds are disabled until the release ticket"; `Staging` requires the exact staging host. `Production.xcconfig` carries no URL. TestFlight archives use the `Staging` configuration.

### 9.2 Scripts

`scripts/remote/kz_guard.py` is the single implementation of 5.2, imported by `kz_remote.py`, `seed/load_staging.py` and `validate-release-config.py` (host rules). Failure behaviour: print `refused: <CODE>` (code only, no URL, no key) on stderr; exit status **78**; no socket opened, no subprocess for the Supabase CLI started, no file written. `local_backend.require_local_url` stays for local-only scripts. The existing local scripts keep `unset SUPABASE_ACCESS_TOKEN`.

### 9.3 Edge Functions

`supabase/functions/_shared/env_guard.ts` is imported by `_shared/serve.ts`; **`Deno.serve` appears only there** (lint test F7). Every function (`delete-account`, `send-push`, `tmdb-proxy`) is started with `serveGuarded(handler)`.

Checks, in this order, at cold start and again for each request (positive result cached 60 s per isolate; failure never cached):

1. `SUPABASE_URL` (platform-injected) parsed; host lowercased must be in `ALLOWED_API_HOSTS = ["ankgfqkgflcalmlreetu.supabase.co"]` or, for the local edge runtime only, `["kong", "host.docker.internal", "127.0.0.1", "localhost"]`. A denied ref anywhere in `SUPABASE_URL` → refuse.
2. The request URL host (`new URL(req.url).hostname`) must be in the same allowlist or in `functions` host variants of the staging ref (`ankgfqkgflcalmlreetu.functions.supabase.co`).
3. Marker: call `public.kizuki_environment()` with the service client; require `staging`+ref, or `local` when check 1 matched a local host. Any error or mismatch refuses (fail closed).
4. Outbound destinations other than Supabase (APNs, TMDB) are fixed constants in their function; none can be set from a secret.

**Failure behaviour (functions).** Respond `503` `{"error":"environment_refused"}` with no stack and no detail; make **no** database, Storage or Auth call (the stubbed client call counter stays 0 in tests); `console.error("environment_refused", code)` with the code only. A function deployed to production by mistake therefore answers 503 to every request, including the cron/job-secret path.

### 9.4 Database-side outbound guard

`private.url_allowed_for_environment(url)` (section 4.3) is called by every `net.http_post` trigger/job (B18 owns push; B17 owns `resume-deletions`) before sending. Failure: skip, insert nothing into the outbox as `sent`, log `env_refused`. Test E4, and B18 repeats it against the real trigger.

### 9.5 Drift protection

`scripts/check-env-pins.py` (test G12) parses `BackendAllowlist.swift`, `kz_guard.py`, `_shared/env_guard.ts`, `Staging.xcconfig`, `staging.pin` and asserts equal refs, hosts and denied refs. `Production.xcconfig` must contain no `.supabase.co` string.

---

## 10. Failure codes (shared vocabulary)

| Code | Surface | Meaning |
|---|---|---|
| `E_OVERRIDE` | script | Forbidden flag, subcommand or env override |
| `E_PROXY` | script | Proxy variable present |
| `E_TOKEN_PRESENT` / `E_TOKEN_SCOPE` | script | Management token in a Tier-P run / token can see another project |
| `E_LINK_STATE` | script | `supabase/.temp/*` names another project or pooler |
| `E_REF_DENIED` | script, app (`backendDenied`), function | Denied ref found in any input |
| `E_HOST_NOT_ALLOWED` | all | Host not in the allowlist |
| `E_POOLER` | script | Wrong DSN host, user, port, parameters |
| `E_REDIRECT` | script, app | Redirect attempted |
| `E_MARKER_ABSENT` / `E_MARKER_WRONG` / `E_NOT_PRISTINE` | script, function | Marker state not S1 / non-pristine without marker |
| `E_WITNESS` / `E_BOOTSTRAP_FILE` / `E_CI_BOOTSTRAP` | script | Bootstrap preconditions |
| `E_NOT_VIA_GATEWAY` | seed | Loader invoked directly |
| `productionDisabled`, `backendDenied`, `backendRefused` | app | Configuration or probe refusals |
| `environment_refused` | function | HTTP 503 body |

---

## 11. Tests (the exit criteria of ticket 037; also the proof for B03 and B20)

"No remote writes": every Python test patches `socket.socket.connect` and `getaddrinfo` to fail the test if called, and runs the wrapper with a fake `supabase` and `psql` on `PATH` that record argv. Asserting an empty record is the proof.

### 11.1 Swift (`KizukiCoreTests`, B03)

| ID | Test | Expected |
|---|---|---|
| A1 | `.production` with the production URL and a valid key | `productionDisabled`; zero requests |
| A2 | `.production` with the staging URL | `productionDisabled` |
| A3 | `.staging` with each of: production host; `unapproved-review-probe.supabase.co`; `ankgfqkgflcalmlreetu.supabase.co.evil.test`; `ENOSGGCKDXJIAXALHG` uppercase; trailing-dot host; userinfo trick `https://ankgfqkgflcalmlreetu.supabase.co@enosggckdxjiaqtxalhg.supabase.co`; port `:443`; `http`; path; query; IDN homoglyph | each throws `backendDenied` or `invalidURL` |
| A4 | `.staging` exact URL, publishable key | succeeds; `sessionStorageKey` unchanged format |
| A5 | Legacy anon JWT with `ref` = production, with `ref` = staging; secret key; service-role JWT | denied / ok / `invalidClientKey` / `invalidClientKey` |
| A6 | `.local` with the staging URL; `.local` with `127.0.0.1:54321` | throws / ok |
| A7 | Guarded session: request to a non-allowlisted host; URL with the denied ref in path or query | throws before the `URLProtocol` stub sees it (stub counter 0) |
| A8 | Redirect 302 from the staging host to production, and to the same host | both cancelled; counter shows no follow-up request |
| A9 | Response whose `url.host` differs from the request host | rejected |
| A10 | Probe: staging answer ok / production answer / different ref / `unmarked` / 404 / malformed / timeout | ok → ready; all others → `.backendRefused` and the count of requests to `/auth/v1` is 0 and no Keychain call (fake store) |
| A11 | Realtime socket URL host check | derived URL equals the config host; **[unverified]** whether the injected session covers the socket, test documents the observed behaviour and the construction check is the guarantee |
| A12 | Source scan (Swift test or script): `SupabaseClient(` appears only in `GuardedSupabase.swift`; the denied ref string appears only in `BackendAllowlist.swift` | pass |
| A13 | Fixture and live-composition roots with a refused config | `AppSession` starts in the setup screen state; no repository is constructed |

### 11.2 Python (`scripts/test-remote-guard.py`, `scripts/test-release-config.py`, B03)

| ID | Test | Expected |
|---|---|---|
| G1 | argv with `--project-ref`, `-p`, `--db-url`, `--linked`, `link`, `--workdir` | `E_OVERRIDE`, exit 78, fake `supabase` never called |
| G2 | env with each of `SUPABASE_PROJECT_ID`, `SUPABASE_DB_URL`, `DATABASE_URL`, `PGHOST`, `PGOPTIONS`, `HTTPS_PROXY`; and `SUPABASE_ACCESS_TOKEN` for a Tier-P command | matching code, no connect |
| G3 | `supabase/.temp/project-ref` = production, = another ref, = staging; `pooler-url` naming production | refused / refused / allowed / refused |
| G4 | DSN variants: wrong host, `.evil.test` suffix, IP literal, user `postgres.enosggckdxjiaqtxalhg`, user without tenant on the pooler host, port 6543, `sslmode=disable`, `?host=` parameter, `options=` | each `E_POOLER`, zero connects |
| G5 | Redirecting loopback server through the gateway HTTP opener (test-only base URL injection) | `E_REDIRECT`, 0 followed |
| G6 | Marker states with a fake `SqlDriver`: pristine+`migrate`; pristine+`bootstrap` ok; staging marker ok; `production`; staging with another ref; `local` marker against remote; table present but zero rows; non-pristine without marker | refuse / allow / allow / refuse x5 |
| G7 | `bootstrap` without witness; wrong witness; right witness; run twice | `E_WITNESS` / `E_WITNESS` / one transaction `begin ... insert ... commit` in order / second run `E_MARKER_*` no write |
| G8 | Edited `env_marker.sql` (hash differs) | `E_BOOTSTRAP_FILE` |
| G9 | **Empty production target:** pristine fake DB, but DSN user or API host names production | refused in static stage, zero driver calls |
| G10 | Tier M with fake Management client listing {staging}, {staging, production}, {production}, {} | ok / `E_TOKEN_SCOPE` x3 |
| G11 | `CI=true` + `bootstrap` | `E_CI_BOOTSTRAP` |
| G12 | `check-env-pins.py` on the repo; on a copy with one file altered | pass / fail |
| G13 | Workflow lint: no `SUPABASE_ACCESS_TOKEN`, no production string, no `environment: staging` under `pull_request`, `staging` only on `workflow_dispatch` | pass; each violation fixture fails |
| G14 | `check-remote-mutations.py` positive and negative fixtures including `.github/workflows` | pass / fail |
| G15 | Seed loader: email not `@seed.kizuki.test`; host mismatch; call log order | refuse before first write; first logged call is the marker read |
| G16 | `validate-release-config.py`: Release+production always fails (even a perfect configuration); Staging exact host passes; every A3 host fails; the current `test_valid_public_configuration` is inverted | all as stated |
| G17 | Gateway Tier-P invocation sets a dummy `SUPABASE_ACCESS_TOKEN` for the CLI subprocess | recorded in the fake CLI's env **[unverified]**: also run once by hand with a real stored login before B20 |

### 11.3 Deno (`supabase/functions/_shared/env_guard_test.ts`, B03 ships the module and tests; the first function consumes it in B04)

| ID | Test | Expected |
|---|---|---|
| F1 | `SUPABASE_URL` = production host | 503 `environment_refused`; stubbed client calls = 0 |
| F2 | staging `SUPABASE_URL` and staging request host | handler runs |
| F3 | staging `SUPABASE_URL`, request host = production | 503 |
| F4 | `SUPABASE_URL` = `http://kong:8000` | allowed (local); same with a `staging` marker answer → 503 (mismatch) |
| F5 | marker RPC fails, returns `production`, `unmarked`, other ref | 503; failures are not cached; success cached 60 s |
| F6 | `SUPABASE_URL` contains the denied ref in any position | 503 |
| F7 | Lint: `Deno.serve(` occurs only in `_shared/serve.ts` | pass |

### 11.4 pgTAP (`supabase/tests/b03_env_marker.sql`, local stack)

| ID | Test | Expected |
|---|---|---|
| E1 | After `env_marker.sql` (local variant): one row, singleton; second insert fails; CHECK rejects `environment='production'`, wrong ref, `local` with a ref | as stated |
| E2 | UPDATE, DELETE, TRUNCATE on the marker | `marker_immutable` |
| E3 | `anon`, `authenticated`, `service_role` cannot `select` the table; all can call `public.kizuki_environment()`; it returns only the two keys | as stated |
| E4 | `private.url_allowed_for_environment`: staging marker accepts exactly the staging https host; rejects production, `ankgfqkgflcalmlreetu.supabase.co.evil`, `http`, a lookalike; local marker accepts `http://kong:8000`; no marker rejects | as stated |
| E5 | Run `env_marker.sql` twice; run it after creating `public.x` | `already_bootstrapped`; `not_pristine`; no row change (this proves the MCP path is guarded by the file itself) |
| E6 | Migrations dir contains no statement touching `kizuki_env` | grep passes |

### 11.5 Live and staging (B20; B03 only prepares the commands)

| ID | Test | Expected |
|---|---|---|
| L1 | Before bootstrap: `verify` on pristine staging; witness taken from `supabase-staging` MCP | state S0; fingerprints equal |
| L2 | `bootstrap` ; `verify` ; `bootstrap` again | marker row as in 4.3; second run `E_MARKER_*` and `bootstrapped_at` unchanged |
| L3 | `migrate`; MCP `list_migrations` | versions equal the repo's migration filenames exactly |
| L4 | `verify` shows `/auth/v1/settings` flags; smoke: 9-char password rejected; sign-up email carries a numeric code | as stated |
| L5 | Staging build on the simulator: probe passes, sign-in works. Then point the same build at a local stub answering `production` / `unmarked`: `backend-refused` screen, no auth request | as stated |
| L6 | Production baseline via the **read-only production MCP**: recorded before B03 starts (migrations list, table list, auth user count) at `docs/lanes/<date>-production-baseline.md`; re-read after B20 | identical; no production contact in gateway logs |
| L7 | Gateway log of the B20 run | every connection host is the pinned pooler/direct/API host; zero refusals other than the deliberate negatives |

---

## 12. Changes this design asks of other tickets

- **014 (B03)** owns: `BackendAllowlist.swift`, `GuardedSupabase`, probe, `productionDisabled`; validator + tests; xcconfigs; `scripts/remote/{kz-remote.sh,kz_remote.py,kz_guard.py,staging.pin}`, `supabase/bootstrap/env_marker.sql`, migration `b03_environment_probe.sql`, `_shared/env_guard.ts` + `_shared/serve.ts`, check scripts, CI jobs, tests A/G/F/E.
- **013 (B02)**: the marker is no longer a migration. B02 must **not** create `private.environment_marker`; `scripts/supabase-local.sh reset` applies the local marker. B02's migration grep must additionally reject `kizuki_env`.
- **031 (B20)** executes section 6 and tests L1-L7.
- **028 (B17) and 029 (B18)**, the `net.http_post` users: call `private.url_allowed_for_environment` before every outbound HTTP from SQL.
- **v2 section 3** items 4-5 and the K03/K19 rows (v2.1 B03/B20 rows) are superseded by this file for the points above.

## 13. Unverified, accepted risks

- Whether a Supabase PAT can be limited to one organisation by account membership (Tier M).
- Whether `SUPABASE_ACCESS_TOKEN` env overrides a stored CLI login (G17).
- Whether `supabase config push`/Management API sets every auth field on Free (B20 fallback: checklist).
- Whether the injected `URLSession` covers the Realtime WebSocket (A11; construction check is the guarantee).
- Free-tier built-in mail rate limit affects the B20 sign-up smoke.
- The witness proves intent, not authentication; credential binding and the pins are the authentication.
- Opaque publishable keys carry no ref; the launch probe is the check for them.
