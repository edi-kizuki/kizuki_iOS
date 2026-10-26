---
title: Supabase backend research for Kizuki v0
created: 2026-10-25
tags: [project/kizuki, research, supabase, backend]
status: complete
---

# Supabase backend research for Kizuki v0

Related: [[playbook]], [[2026-10-24-architecture-round-1-interview]], [[00-what-exists]]

Research lane. Recommends only. No app code, no migrations, no remote writes. Production project `enosggckdxjiaqtxalhg` was not touched. Local Docker is not running.

## 0. Evidence base and conventions

- User decisions (28, interview note) override Notion and Figma. Cited below as `D#`.
- Pinned SDK: supabase-swift **2.55.4**, revision `fee4bd78997f8b4e919c1c9711e0cfb346fd7a55` (`/Users/edisonabdiel/Projects/kizuki_iOS/ios/Package.resolved`; `exact: "2.55.4"` in `ios/Packages/KizukiKit/Package.swift`). Note: there is no `Package.resolved` under `ios/Packages/KizukiKit/`; the resolved file is `ios/Package.resolved`. SDK claims below were verified by reading the checked-out source at `.build/DerivedData/SourcePackages/checkouts/supabase-swift` (tag `v2.55.4`).
- Existing foundation (verified by reading): migration `20261024000100_own_profile_foundation.sql` creates `public.profiles` (id, handle citext, display_handle, avatar_path) and `public.profile_settings` (private `onboarding_state` jsonb), RLS on, `authenticated` has SELECT only on own rows, `auth.users` insert trigger provisions both. `config.toml`: storage, studio, edge_runtime, analytics disabled; `db.seed.enabled = false`; email confirmations on; Postgres 17. `SupabaseBackend.swift` uses PKCE, Keychain storage, `authStateChanges`, `signOut(scope: .local)`, one PostgREST read. No Apple sign-in, realtime, storage, or write code exists yet.
- Labels: **[docs]** primary vendor documentation (vendor claim about vendor product). **[source]** read from code. **[pg]** PostgreSQL documentation. **[design]** my recommendation, not a fact. **[unverified]** not confirmed from a primary source.
- Notion pages "Supabase Data Model & RLS", "Backend Functions & Jobs", "Recommendation & Taste Algorithm v1" were NOT read in this lane (Notion connector needs authorization here). `docs/context/00-what-exists.md` says they were not fetched in intake either. The model below is therefore designed from the product specs in `2026-10-24-notion-source-extracts.md`, not from the Notion data-model page. **Reconcile against that page before writing migrations.**

## 1. Data model and RLS

### 1.1 Principles

1. Private data lives in separate tables, never in columns hidden by view tricks. The foundation already does this (`profile_settings`). Views bypass RLS by default unless `security_invoker = true` (PG15+) [docs: https://supabase.com/docs/guides/database/postgres/row-level-security].
2. Clients get SELECT on most tables and **no direct write** on state-machine tables (requests, conversations, blocks side effects). Writes go through `security definer` RPCs with `search_path = ''`. This extends the foundation's pattern (`revoke all ... grant select`).
3. Every policy names its role with `to authenticated`, wraps `auth.uid()` as `(select auth.uid())`, and every column a policy filters on is indexed [docs: same RLS page].
4. Never base authorization on `user_metadata`; users can edit it [docs: same page].
5. Postgres enums for closed sets (status machines, compensation, work mode, availability). Values can be added or renamed but never removed without recreating the type [pg: https://www.postgresql.org/docs/17/datatype-enum.html]. Lookup tables for taxonomies that will change (roles, project types, facets, cities).
6. Policy combination: permissive policies OR together, restrictive AND [pg: https://www.postgresql.org/docs/17/ddl-rowsecurity.html]. This is the key to "block hides both ways": one `as restrictive` policy per table, layered over permissive read policies.
7. Business rules that must hold even for a buggy client go in CHECK constraints, partial unique indexes [pg: https://www.postgresql.org/docs/17/indexes-partial.html], and triggers, not only in RPCs.

### 1.2 Enums

| Enum | Values | Notes |
|---|---|---|
| `realm` | film_video, music_sound, visual_arts, mixed | Spec O2. |
| `intent` | start, join, explore | Spec O3. Routing only; never gates (spec). |
| `compensation` | paid, unpaid, open_to_either, undecided | `undecided` allowed only on drafts (CHECK). Profile preference uses same enum minus `undecided` via CHECK. |
| `work_mode` | local, remote, either | Spec C2. |
| `availability_band` | under_5, five_to_10, over_10, varies | Spec C1. |
| `project_status` | draft, published, closed, past | D19 My Projects = drafts/published/past. Reason in `closed_reason`. |
| `closed_reason` | filled, owner_closed, expired, completed | Maps Notion's 8 statuses without 8 states. |
| `request_kind` | join_project, collab_person, invite_to_project | See 1.5. |
| `request_status` | pending, accepted, declined, withdrawn, expired | Per brief. |
| `conversation_kind` | direct, project_group | |
| `report_target` | profile, project, collab_photo, request, message | Notion safety list. |
| `report_reason` | spam, harassment, impersonation, inappropriate_content, underage, scam, other | Taxonomy owner open (see section 8). |
| `report_status` | open, reviewing, actioned, dismissed | Dashboard-reviewed (D16). |
| `link_kind` | website, youtube, soundcloud, bandcamp, letterboxd, instagram, spotify, tiktok, behance, other | D23 + Notion C3. |
| `link_relation` | made, admire, want_to_make | Notion C3. |
| `fav_source` / `fav_kind` | tmdb / musicbrainz ; film, artist, release | D22. |
| `card_rights` | placeholder, licensed, commissioned, first_party | D21 launch-blocker flag; see 1.4. |
| `feedback_kind` | like, save, hide, not_my_style, more_like_this, less_like_this | D25 likes/saves; Notion hide/less-like-this. |

### 1.3 Identity and profile tables

Keep `profiles` and `profile_settings` from the foundation; extend with additive migrations.

**`profiles`** (public to other signed-in, onboarded, non-blocked users). Existing: `id, handle citext unique, display_handle, avatar_path, created_at, updated_at`. Add: `display_name`, `bio` (<=280), `cover_path`, `primary_realm`, `work_mode`, `city_id`, `country_code`, `availability_band`, `compensation_pref` (hard-filter input), `primary_role_id`, `onboarding_completed_at`, `last_active_at` (coarse, day precision), `status` (`active|suspended|deactivated`; Figma "Need a break? Deactivate"). Avatar fallback: `avatar_path is null` means client draws Blobatar from `id` or handle (D9). Never store a generated Blobatar image.

**`profile_settings`** (private; existing). Extend: `serendipity` (stay_close/mix/surprise), `discovery_focus` (text[]), `notify_requests`, `notify_messages`, `discoverable`. Keep `onboarding_state` jsonb for resume.

**`profile_consents`** (private, append-only): `id, profile_id, terms_version, privacy_version, age_confirmed bool, accepted_at`. Insert via RPC only, so `accepted_at` is server time. See section 4 for the age gate.

**`device_tokens`** (private): `profile_id, token, environment (sandbox|production), updated_at`. Needed for push (D8); sending push is an Edge Function later.

**`handle_reservations`** (private, optional v0): old handle held 30 days (Notion Auth 2). Reserved-word list as a table checked in a trigger. Existing `handle_format` CHECK already enforces 3-24 chars, no `..`, start/end alnum. Note: the spec allows up to 24; Figma shows conflicting rules ("at least 5" vs "3-20", walkthrough conflict 12). Keep 3-24 (existing migration) unless the user says otherwise.

**`cities`** (public read): `id, name, country_code, lat, lon (city centroid only), population`. Seed with a small curated list for v0 (Berlin first). Real dataset choice and licence **[unverified]** (GeoNames is the usual candidate; licence not checked here). Store city-level only (Notion C2); do not persist device coordinates (see 8).

### 1.4 Taxonomy, roles, taste, favourites

- **`roles`** (`id, slug, label, realm null=cross, sort`). Public read. Seeded from Figma lists (walkthrough rows 283-284: Producer, Engineer, Vocalist, Photographer, Illustrator, Creative Technologist, ...). Taxonomy freeze is an open Notion task.
- **`profile_roles`** (`profile_id, role_id, is_primary, position`). PK (profile_id, role_id). Partial unique index `on (profile_id) where is_primary` gives exactly-one-primary. Max 3 roles (Notion O9) via constraint trigger.
- **`project_types`** (`id, slug, label, realm`); **`profile_project_type_interests`** (Join branch J1).
- **`taste_facets`** (`id, realm, group_slug, slug, label`).
- **`taste_cards`** (`id, realm, title, alt_text, image_path, rights card_rights, published bool, sort`). Spec: 12 cards shown per user, >=24 per realm. D21: placeholder images in v0. **Guard:** a CHECK/trigger that forbids `published = true` with `rights = 'placeholder'` in any environment where `app.environment = 'production'` is not enforceable at DB level, so instead gate in the release checklist and a pgTAP test "no placeholder card is published in the release seed" (see section 6). Cards are public read; the image bucket is public read-only (section 5).
- **`taste_card_facets`** (`card_id, facet_id, weight smallint`).
- **`taste_selections`** (`profile_id, card_id, selection_order`, 3-5 rows). Private to owner.
- **`taste_pair_choices`** (`id, profile_id, left_card_id, right_card_id, choice enum(left,right,neither,both), realm, created_at`). Do **not** store `response_ms` in v0 [design]: the spec stores it "for research only" and never ranks on it; skipping it removes a column of behavioural data and costs nothing now.
- **`profile_taste`** (`profile_id, facet_id, score real`): derived. Written only by an RPC (`submit_taste`) that also inserts selections and choices atomically, so facet deltas live in one place (Notion: weights "live in Taste Capture Strategy", page not read). Private to owner; matching reads it via `security definer`.
- **`favourites`** (`id, profile_id, source fav_source, kind fav_kind, external_id text, title text, year int, position`). Unique `(profile_id, source, external_id)`. Store ID plus a title/year snapshot so lists render offline and survive an API outage; **do not store poster URLs or images** in the DB. Visibility is controlled per profile: public read when `profile_settings.discoverable`, owner write. Cap 5 per kind by trigger [design]. Terms and fit of TMDB and MusicBrainz are in 1.8.

### 1.5 Projects, roles, requests

**`projects`**: `id, owner_id, title, description, realm, project_type_id, project_type_other (<=40), compensation, work_mode, city_id, country_code, starts_on, ends_on, flexible_timing bool, expires_at, status project_status default 'draft', closed_reason, cover_path, published_at, created_at, updated_at`.

Publish contract as DB constraint [design, from Notion "Canonical data contract"]:
`CHECK (status = 'draft' OR (title is not null and description is not null and compensation <> 'undecided' and project_type_id is not null and expires_at is not null and (work_mode = 'remote' or city_id is not null)))`. "At least one role" needs a trigger on status change (cannot be a CHECK across tables). Indexes: `(status, realm)`, `(owner_id, status)`, `(city_id)`, partial index `where status = 'published'` on `expires_at` for the expiry job.

**`project_roles`**: `id, project_id, role_id, slots int default 1, filled int default 0, note`. `filled <= slots`. A role with `filled = slots` is closed to new requests; when all roles filled, project moves to closed(`filled`).

**`project_members`** (`project_id, profile_id, project_role_id, joined_at`): rows appear only when a request is accepted (RPC). Drives group-chat membership and "Collaborators in this project" (Figma 1449:4691).

**`requests`**: `id, kind, sender_id, recipient_id, project_id null, project_role_id null, message text (<=500), status request_status default 'pending', expires_at default now()+14d, responded_at, created_at`.

- `join_project`: sender asks owner for a role. `recipient_id` = project owner. `project_id` and `project_role_id` required.
- `collab_person`: sender asks a person; `project_id` optional (Notion: must reference a project or state an idea; the `message` is the idea).
- `invite_to_project`: owner invites a person. Notion Flow 1 mentions invitations; D-list does not. **Open question** (section 8); include in schema, build later.
- Duplicate rule (Notion): unique partial index `on (sender_id, recipient_id, coalesce(project_id, '00000000-0000-0000-0000-000000000000'), coalesce(project_role_id, ...)) where status in ('pending','accepted')`.
- CHECK `sender_id <> recipient_id`.

State machine (enforced by a BEFORE UPDATE trigger plus RPCs; clients have no UPDATE grant):

| From | To | Actor | Side effect |
|---|---|---|---|
| pending | accepted | recipient | create `conversation` (direct) or add to project group; if join_project: insert `project_members`, increment `filled` |
| pending | declined | recipient | private optional reason (separate private column, never returned to sender) |
| pending | withdrawn | sender | none |
| pending | expired | system (pg_cron or lazy check) | none |
| any terminal | any | nobody | blocked by trigger |

Gate functions (`send_request`, `respond_request`, `withdraw_request`) also enforce: sender has `onboarding_completed_at`, verified email (Notion: sending a request requires verified email; Apple-relay emails count as verified by Apple **[unverified]**), no block either way, project is `published` and role has open slots, daily rate limit (count in last 24h, e.g. 20 [design]). Hard compensation filter is **not** enforced here: it hides results in discovery, not sending (a paid seeker may still deep-link an unpaid project) [design; confirm in section 8].

### 1.6 Conversations and messages (gated on acceptance)

- **`conversations`**: `id, kind, project_id null, request_id null unique, created_at, closed_at, closed_reason (blocked|project_closed|member_left)`.
- **`conversation_members`**: `conversation_id, profile_id, joined_at, left_at, last_read_at, muted`. PK `(conversation_id, profile_id)`; index `(profile_id)`.
- **`messages`**: `id uuid pk, conversation_id, sender_id, client_id uuid, body text (1..2000), created_at, edited_at, deleted_at`. Unique `(sender_id, client_id)` for retry idempotency. Index `(conversation_id, created_at desc)`.

Gate is structural: there is **no INSERT grant on `conversations`**; only `respond_request` (security definer) creates them, and only from an `accepted` request. `messages` INSERT policy requires membership of an open conversation. Result: no path to chat without an accepted request (D11). Unsend/edit policy: soft delete (`deleted_at`) by sender; body retained for reports until retention window [design; Notion says policy must be documented before beta].

Direct chat = one conversation per accepted request pair (reuse existing open conversation for same pair; `collab_person` after earlier accept should not create a second thread [design]). Group = one `project_group` conversation per project, created at first accepted join, members added as `project_members` rows appear.

### 1.7 Photos, links, feedback, safety

- **`collab_photos`** (the Search grid, D19; Figma "Post a collab" is a separate content type from Project, walkthrough open question 3 - **confirm**): `id, owner_id, project_id null, storage_path, width, height, caption (<=140), alt_text, realm, role_id null, tags text[] (lowercase, controlled), status (visible|hidden|removed), created_at`. Indexes: `(created_at desc)`, GIN on `tags`, btree `(realm)`, `(owner_id)`. Caption search: v0 `ilike` with `pg_trgm` GIN index **[design; not verified against Supabase extension availability on this project]**; move to `tsvector` if needed. Cap 24 photos per user by trigger [design].
- **`profile_links`**: `id, profile_id, kind link_kind, url, title, relation link_relation, show_on_profile bool default false, use_for_recs bool default false, embed_ref text null (provider id parsed from URL), link_status (unchecked|ok|unreachable|hidden), last_checked_at, position`. Defaults mirror Notion C3 (both consents off by default; Letterboxd default `admire`). `CHECK (url ~ '^https://')`. Host allow-list per kind enforced in the write RPC; the **client renders** embeds in a sandboxed web view from `embed_ref`; the database never fetches third-party pages (Notion: never scrape). Weekly recheck needs an Edge Function plus cron (section 2); **drop for v0** and ship `link_status = 'unchecked'`.
  Embed feasibility is outside this lane and was only partly checked: the SoundCloud widget is an iframe with the track URL in a query parameter (https://developers.soundcloud.com/docs/api/html5-widget; its API key and terms pages were not read); Instagram's oEmbed page says the endpoint is "only meant to be used for embedding Instagram content in websites and apps" with 1,000 requests/hour, but does not say whether an access token or app review is needed (https://developers.facebook.com/docs/instagram-platform/oembed) -> **unverified, treat Instagram embed as link-only in v0**; Bandcamp embed ID derivation was **not found** in the page checked -> **unverified**, so `embed_ref` must be nullable and every kind must fall back to a plain link (Notion: link/manual fallback for every source).
- **`item_feedback`**: `profile_id, target_kind (project|profile|collab_photo), target_id, kind feedback_kind, created_at`, PK `(profile_id, target_kind, target_id, kind)`. Polymorphic target, so no FK; a cleanup trigger or periodic delete handles orphans. Chosen over three tables to keep ranking SQL one join [design].
- **`blocks`**: `blocker_id, blocked_id, created_at`, PK `(blocker_id, blocked_id)`, CHECK `blocker_id <> blocked_id`, extra index `(blocked_id, blocker_id)`.
- **`reports`**: `id, reporter_id (on delete set null), target_kind, target_id, target_owner_id, reason, details (<=1000), snapshot jsonb (message body / caption / handle at report time), status default 'open', created_at, reviewed_at, reviewer_note`. Reviewers use the Supabase dashboard with the owner role (D16), so no reviewer RLS is needed. Appeals: out of v0.

### 1.8 Favourites sources: TMDB and MusicBrainz (only what shapes the schema)

- **TMDB** [vendor terms: https://www.themoviedb.org/api-terms-of-use]: the free licence "does not permit any commercial use"; commercial use needs a separate written agreement. Attribution with the TMDB logo and the "uses TMDB and the TMDB APIs but is not endorsed, certified, or otherwise approved by TMDB" notice is mandatory. Caching TMDB information for longer than 6 months is prohibited. Using TMDB data to train or validate ML systems is listed as commercial use. The terms also treat revenue-generating "recommend content" services as commercial. The developer FAQ [vendor: https://developer.themoviedb.org/docs/faq] says non-commercial use is free with credit and commercial licences go through sales@themoviedb.org. **Impact:** Kizuki is a free v0 but plans ads and premium (Notion roadmap), so assume a commercial licence is eventually needed. Store only `external_id + title + year` (a snapshot) and refresh from TMDB at most every few months; never store posters in Supabase Storage. Rule-based overlap on IDs is not ML training, but ask TMDB in writing before launch **[unverified legal reading; not legal advice]**.
- **MusicBrainz** [vendor: https://musicbrainz.org/doc/MusicBrainz_API/Rate_Limiting, https://musicbrainz.org/doc/About/Data_License]: core data is CC0; supplementary data (e.g. annotations) is CC BY-NC-SA. API limit is about 1 request/second per IP; every request needs a descriptive `User-Agent` with contact info; excess requests get HTTP 503. The rate-limit page does not address commercial use of the web service. **Impact:** call MusicBrainz **from the device** (each phone is its own IP), not through one Edge Function IP, or the 1 req/s ceiling hits immediately. Set `User-Agent: Kizuki/<ver> (contact)` in the URLSession. Artwork comes from Cover Art Archive **[unverified: not read here]**.
- Letterboxd API excluded (D-evidence in interview note); Letterboxd stays a profile link.

### 1.9 RLS matrix (design)

Roles: `anon` gets nothing (foundation already revokes it). `me` = `(select auth.uid())`. `visible(x)` = restrictive block policy from 1.10. "RPC" = write only through a `security definer` function; no table grant.

| Table | SELECT | INSERT | UPDATE | DELETE |
|---|---|---|---|---|
| profiles | own row always; others if `onboarding_completed_at is not null and status='active'` and `visible(id)` | trigger only (exists) | own row, column grants only on editable columns (no `id`, no `status`) | cascade from auth |
| profile_settings, profile_consents, device_tokens | owner | RPC (consents) / owner (tokens) | owner (settings) | owner (tokens) |
| cities, roles, project_types, taste_facets, taste_cards, taste_card_facets | all authenticated | none (migrations/seed) | none | none |
| profile_roles, favourites, profile_project_type_interests | owner, plus others if profile visible | owner (via visible profile) | owner | owner |
| taste_selections, taste_pair_choices, profile_taste | owner only | RPC `submit_taste` | none | owner (delete my taste data) |
| profile_links | owner; others only where `show_on_profile` and profile visible | owner | owner | owner |
| projects | owner always; others where `status='published'` and `visible(owner_id)` | owner, `status='draft'` only (WITH CHECK) | owner; status change via RPC `publish_project`/`close_project` | owner, drafts only |
| project_roles | follows parent project visibility | owner of parent | owner of parent | owner, if no accepted request |
| project_members | members of the project, and the owner | RPC | none | RPC (leave/remove) |
| requests | sender or recipient | RPC `send_request` | RPC only (`respond_request`, `withdraw_request`) | none |
| conversations, conversation_members | members | RPC only | `last_read_at`, `muted` own row only | none |
| messages | members of conversation, `deleted_at is null` for others | member, `sender_id = me`, conversation open, `client_id` supplied | sender, soft-delete/edit only | none |
| collab_photos | all authenticated where `status='visible'` and `visible(owner_id)`; owner sees own | owner (path must start with `me/`) | owner | owner |
| item_feedback | owner | owner | none | owner |
| blocks | blocker only (a blocked user must NOT learn they are blocked) | RPC `block_user` | none | blocker (`unblock`) |
| reports | reporter own rows | RPC `report` (captures snapshot) | none | none |

Index checklist [docs RLS page]: every `owner_id`, `sender_id`, `recipient_id`, `conversation_id`, `profile_id`, `project_id` used in a policy; `blocks (blocked_id, blocker_id)`.

### 1.10 Block hides both ways

Pattern [design; mechanics from Postgres and Supabase docs above]:

```sql
-- private schema is not in config.toml [api].schemas, so PostgREST does not expose it
create function private.is_blocked_pair(a uuid, b uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.blocks
                 where (blocker_id = a and blocked_id = b)
                    or (blocker_id = b and blocked_id = a));
$$;
create policy hide_blocked on public.profiles as restrictive for select to authenticated
  using ((select auth.uid()) = id or not private.is_blocked_pair((select auth.uid()), id));
```

- One restrictive policy per table keyed on its owner column (`profiles.id`, `projects.owner_id`, `collab_photos.owner_id`, `requests` both parties, `project_members.profile_id`, `favourites.profile_id`, ...). It ANDs with every permissive policy [pg: ddl-rowsecurity].
- The helper is `security definer`, because the blocked user has no right to read `blocks`; otherwise RLS on `blocks` would make the check one-directional. This is the reason the blocks table itself only shows the blocker their own rows.
- Side effects inside `block_user` RPC: set `closed_at` on direct conversations between the pair, withdraw pending requests between them, remove the blocked user from shared project groups' visibility (leave rows, hide via policy), delete `item_feedback` between them.
- Feed/matching function (section 2) must also exclude blocked pairs, because `security definer` functions bypass RLS. Recommend `security invoker` for read functions so the same restrictive policies apply automatically; use `definer` only for the narrow taste/score reads and re-apply the pair check explicitly.
- Cost: one indexed EXISTS per row. Fine at v0 scale. If feeds grow, materialize a per-viewer blocked-ID set in the query (`not in (select ...)`) rather than a per-row function call **[design]**.
- Unverified: whether the per-row function call is inlined by the planner (SQL-language `stable` functions can be, `security definer` ones are not). Check with `EXPLAIN` on 60-user seed; irrelevant at that size.

## 2. Rule-based matching (D3, D15)

### 2.1 Where to compute: Postgres, not an Edge Function

Recommendation: SQL functions called through PostgREST RPC. Reasons:

- Inputs are all relational (roles, enums, city, taste, favourites, blocks). Joins in one query beat N round trips from a function.
- RLS and block rules apply for free if the function is `security invoker` [docs: https://supabase.com/docs/guides/database/functions says "Prefer `security invoker`, which is also the default"]. A `security definer` function "can return rows the caller isn't allowed to read" and bypasses RLS when owned by `postgres` (same page), so use definer only for narrow helpers.
- Testable with pgTAP against a fixed `p_as_of` timestamp; no deployment surface; works in `supabase test db` offline.
- Edge Functions have a 2 s CPU limit, 256 MB memory, and 150 s (free) or 400 s (paid) wall clock [docs: https://supabase.com/docs/guides/functions/limits]. That is enough for scoring, but adds a hop, a Deno deploy path, and no benefit at this scale.
- Client call shape in supabase-swift: `supabase.rpc("name", params: [...]).execute().value` [docs: https://supabase.com/docs/reference/swift/rpc]. The existing `SupabaseBackend` already holds a `SupabaseClient`.
- Functions are executable by any role by default; revoke from `public`/`anon` and grant to `authenticated` per function [docs: functions page]. The foundation migration already does this for its triggers.

Keep Edge Functions for things SQL cannot do: account deletion (needs service role, see section 4), APNs push sending, link reachability checks, oEmbed lookups, and any future ML re-ranker.

### 2.2 Contract (what makes it replaceable)

One stable RPC, versioned implementation behind it:

```
recommend(kind text /* 'project'|'person' */, limit int default 20, offset int default 0,
          as_of timestamptz default now())
  returns table(target_kind text, target_id uuid, band text /* close|adjacent|stretch */,
                rank int, reasons jsonb /* [{code, params}] */, algo_version text)
```

- Client gets IDs, band, reasons, and rank; it then loads card data with a normal RLS-checked PostgREST `select ... in (...)`. Presentation never depends on the ranker.
- `recommend` dispatches to `private.recommend_v1(...)`. Swap to `recommend_v2` (SQL, pgvector, or a function that reads precomputed scores) by changing one config row (`app_config.recommender = 'v2'`). The client contract does not change.
- Do **not** return the numeric score or a percentage to the client (Notion: "No fake match percentage"). Keep it internal; expose it only in a debug-only function for the seed review.
- Reasons are **codes plus params**, not English strings: `{"code":"role_match","params":{"role":"cinematographer"}}`. Notion says copy is keyed strings so German can be added without layout change. The Swift side maps code to localized copy.
- Log impressions to `recommendation_impressions (profile_id, target_kind, target_id, rank, algo_version, created_at)` for later learning (Notion: "recommendation logging"). Optional in v0, cheap to add now, painful to backfill.

### 2.3 Eligibility (hard filters, in this order)

Viewer V, candidate project P:

1. P is `published`, `expires_at > as_of`, has at least one `project_roles` row with `filled < slots`. Drafts never (Notion C4).
2. Not V's own; no block either way (RLS restrictive policy from 1.10).
3. No existing `pending` or `accepted` request from V to P; not hidden or `not_my_style` by V in `item_feedback`.
4. **Compensation (D3):** if `V.compensation_pref = 'paid'`, require `P.compensation in ('paid','open_to_either')`. Otherwise no filter. Unpaid and open-to-either seekers match everything (Notion matching table). Note the conflict: Notion's confirmed-decision callout says paid seekers pair "only with collaborators hiring for paid work", while its table (and D3) include open-to-either. D3 wins; implement as in the table.
5. **Work mode (Notion):** remote matches remote and either; local matches same `city_id` with local or either; either matches both. Fallback (Notion C4): if fewer than N results in V's city, relax to remote-compatible and add reason `remote_fallback`.

Candidate person Q (People feed): `onboarding_completed_at` set, handle, primary realm, at least one role, `discoverable`, not blocked, not V. Compensation filter for people is **ambiguous** (open question): proposal is to hide Q only when Q wants paid work and every one of V's published projects is `unpaid`; if V has no published project, no filter [design].

### 2.4 Score (additive, integer, weights in a table)

Store weights in `ranking_weights (version, key, points)` so tuning is a data change and tests can pin them [design]. Starting values, all editable:

| Signal | Project candidate | Person candidate |
|---|---|---|
| Role fit | +40 if an open role matches V's primary role; +25 if matches another offered role | +40 if Q offers a role V's published project needs (reciprocal); +20 if matches V's own preferred-collaborator roles |
| Realm | +15 same realm; +5 adjacent (mixed) | same |
| Place | +15 same city and local-compatible; +10 remote-compatible | same |
| Availability | +10 compatible band (project `time_commitment` vs V's band); +5 if either is `varies` (neutral) | same, person vs person |
| Taste overlap | 0 to +15 from facet-vector overlap with the owner's `profile_taste` | 0 to +15 vs Q's `profile_taste` |
| Shared favourites | +5 per shared film/music ID, capped +10 | same |
| Freshness | 0 to +10, linear decay over 14 days from `published_at` | new-creator exposure floor +10 for 7 days after onboarding (Notion "exposure floor") |

- Needs one addition to `projects`: `time_commitment availability_band null` (Figma "Time Investment"). Not in 1.5 originally.
- Threshold: Notion points to a number "defined in Recommendation System" (page not read). Placeholder: show only `score >= 30`. **Unverified, confirm from Notion.**
- Bands: close >= 70, adjacent 50-69, stretch 30-49 [design]. Serendipity preference (O8) only changes the mix of bands; it never relaxes hard filters (Notion).
- Tie-break `(score desc, published_at desc, id)` so output is deterministic for tests and seeds.

### 2.5 Match reasons

- Build per-signal reason objects in the same query (`case when ... then jsonb_build_object('code','role_match','params',...)`), `jsonb_agg` the non-null ones ordered by their points, and keep the top 4. Minimum 2 where available, per Notion C4 ("2-4 plain-language reasons").
- Reason codes (v1): `role_match`, `reciprocal_role`, `same_realm`, `same_city`, `remote_ok`, `availability_fit`, `shared_taste` (params: top shared facet labels only, never raw vectors), `shared_favourite` (params: title), `new_creator`, `remote_fallback`, `fresh`.
- Privacy: `shared_taste` may name at most the top two shared facets. The helper that reads another user's `profile_taste` is a `security definer` function in `private` returning only those slugs plus a scalar. Other users' pairwise choices and card picks are never readable.

### 2.6 Performance at v0 scale

- Seed volume (60 users, 25 projects) makes every plan a sequential scan; run time is sub-millisecond to low milliseconds. Not measured here (no Postgres running). **Unverified until `supabase test db` and `EXPLAIN` run locally.**
- Cheap things to do now: compute V's taste vector and roles once in a CTE; keep facet vectors as `real[]` or a small `(profile_id, facet_id, score)` join (facet count is small, tens); index `projects(status, expires_at)` partial on published; `project_roles(project_id) where filled < slots`.
- pgvector (listed in the Notion stack) is **not** needed in v0: the facet space is small and explainability matters more. Reconsider when facet vectors exceed a few hundred dimensions or candidate sets exceed tens of thousands **[design]**.
- Pagination: return the top 60, let the client page locally; true cursor pagination needs a score snapshot, since scores drift with time. Revisit at real traffic.
- Precompute option later: a `pg_cron` job that refreshes `candidate_scores` hourly. pg_cron can run SQL jobs as often as every second, recommends at most 8 concurrent jobs and at most 10 minutes per job; history is in `cron.job_run_details` [docs: https://supabase.com/docs/guides/cron]. Not needed now.
- Expiry jobs use the same mechanism: `update projects set status='past', closed_reason='expired' where status='published' and expires_at < now()` and requests `pending -> expired`. Alternative with zero infrastructure: treat expiry lazily with `expires_at > now()` in every read and reconcile in a nightly job. Local `supabase start` includes pg_cron availability **[unverified]**.

## 3. Chat on Supabase Realtime (D11: only after acceptance)

### 3.1 Options compared

| | Postgres Changes | Broadcast from Database (`realtime.broadcast_changes`) | Client-to-client Broadcast |
|---|---|---|---|
| Authz | Table RLS, checked per subscriber per event [docs: https://supabase.com/docs/guides/realtime/postgres-changes] | Second policy set on `realtime.messages` using `realtime.topic()`, checked at join and on JWT refresh only [docs: https://supabase.com/docs/guides/realtime/authorization] | Same as left, plus clients can inject payloads; messages not persisted |
| Scale | RLS drops throughput from ~30-50k to ~3-4k msgs/s; one thread; docs advise Broadcast above ~3,000 concurrent subscribers [docs, same page] | Docs call it "the recommended method for scalability and security" [docs: https://supabase.com/docs/guides/realtime/subscribing-to-database-changes] | n/a |
| Setup | Add table to `supabase_realtime` publication; filter `conversation_id=eq.<id>` | Trigger + private channel + select policy | Not suitable for durable chat |
| Gaps | DELETE events are not RLS-filtered [docs]; avoid hard deletes (we soft-delete) | Delivery guarantees not stated in the docs; replay max 25 msgs, 72 h-4 d retention [docs: https://supabase.com/docs/guides/realtime/broadcast] | |
| Missed messages | Reconnect: refetch via PostgREST | Replay (private channels, `since` + `limit`<=25) or refetch | |

All three: **always treat the `messages` table as source of truth and refetch `created_at > last_seen` on (re)connect and on app foreground**. Realtime is a nudge, not storage.

### 3.2 Recommendation

- **v0: Postgres Changes** on `public.messages`, filter on `conversation_id`. One policy set (the table's RLS from 1.9) is the single authorization truth; nothing to drift; works in local `supabase start` and pgTAP-testable. At v0 volume the throughput caveat is irrelevant (free plan allows 200 concurrent connections, 100 msg/s; Pro 500 and 500 [docs: https://supabase.com/docs/guides/realtime/limits]).
- **Plan the swap, do not build it:** hide Realtime behind a Swift `ChatTransport` protocol (`messages(in:since:)`, `send(...)`, `updates(for:) -> AsyncStream`). Moving to Broadcast-from-DB later is a trigger plus a `realtime.messages` policy plus a transport implementation; the schema is unchanged.
- Counter-view: Supabase's own docs prefer Broadcast. Choose it now if the user expects thousands of concurrent chatters soon; for a Berlin private alpha it adds a second policy surface for no gain. **Unverified:** behaviour of Broadcast-from-DB on local `supabase start` and the `WarnSendingBroadcastMessage` note (docs say a WebSocket connection must exist for daily partitions; whether an insert with no listener errors is not stated).
- Sending: plain PostgREST `insert` into `messages` with a client-generated `client_id` (idempotent retry). Never send chat through client Broadcast, because it would bypass the membership/block checks in the INSERT policy.
- Group chat per project: same table; `conversation_kind = 'project_group'`; membership rows added by `respond_request`.

### 3.3 RLS interaction with Realtime (what to know)

- Postgres Changes authorizes each event against each subscriber's RLS (docs above). Filters are applied server-side; `in` filters allow max 100 values; only AND is supported (no OR) [docs: postgres-changes page].
- For old values on UPDATE you need `replica identity full`, and filtering DELETE needs it too [docs]. Not needed: we do not filter on DELETE, and message edits send the new row.
- Broadcast authorization is cached for the life of the connection; a revoked member keeps receiving until JWT expiry or a new JWT arrives [docs: authorization page: "will keep receiving messages until their JWT expires or a new one is sent"]. Local `config.toml` has `jwt_expiry = 3600`. This is another reason v0 prefers Postgres Changes: block/membership changes apply per event. With either transport, sends are gated by the `messages` INSERT policy, so a blocked user cannot produce new messages.
- RLS complexity affects join latency and join rates [docs: authorization page]. Keep the membership check a single indexed lookup on `conversation_members (conversation_id, profile_id)`.
- Inbox badge/unread: one user-level subscription with `conversation_id=in.(...)` is limited to 100 values; for more, fall back to refetch on foreground plus push. Push (APNs) for background delivery is an Edge Function job, **out of scope for the loop in D1** unless TestFlight needs it (open question).

### 3.4 supabase-swift 2.55.4 API (verified in source)

Source: `.build/DerivedData/SourcePackages/checkouts/supabase-swift/Sources/{RealtimeV2,Supabase}` at tag `v2.55.4`.

- Access: `supabase.realtimeV2` (`RealtimeClientV2`); convenience `supabase.channel(_:options:)` and `supabase.removeChannel(_:)` forward to it (`SupabaseClient.swift`).
- `channel(_ topic:, options: (inout RealtimeChannelConfig) -> Void)`; the server topic is `"realtime:<topic>"`. Config has `broadcast`, `presence`, and `isPrivate` ("Private channels enforce access control via RLS policies"); set `isPrivate = true` for the Broadcast option.
- Register listeners **before** subscribing, then `try await channel.subscribeWithError()`. `subscribe()` is deprecated in favour of it.
- Postgres Changes streams: `channel.postgresChange(InsertAction.self, schema: "public", table: "messages", filter: .eq("conversation_id", value: id))` returns `AsyncStream<InsertAction>`. Typed variants exist for `UpdateAction`, `DeleteAction`, `AnyAction`. `RealtimePostgresFilter` has `eq, neq, gt, gte, lt, lte, in, like, ilike, match, imatch, isDistinct, not, and` (`RealtimePostgresFilter.swift`).
- Broadcast: `channel.broadcastStream(event: "INSERT")` yields `JSONObject`; `broadcast(event:message:)` sends; `BroadcastJoinConfig` has `acknowledgeBroadcasts`, `receiveOwnBroadcasts`, `replay: ReplayOption(since:limit:)`, `replicationReady`. Replay is private-channel only and database-broadcast only [docs: broadcast page].
- Auth: `SupabaseClient` forwards each refreshed access token to `realtimeV2.setAuth(...)` (`SupabaseClient.swift`, auth-state handler). Per-channel `updateAuth(jwt:)` is deprecated; do not call it.
- Reconnection: `RealtimeLifecycleManager` (iOS) re-joins channels on foreground when the socket was torn down; `disconnectOnEmptyChannelsAfter`, `reconnectDelay`, `handleAppLifecycle` options exist in `RealtimeClientOptions`. Still refetch missed rows (3.1).
- Existing `SupabaseBackend` builds the client with PKCE and Keychain storage; nothing there must change for Realtime, but the shared instance should be reused so the socket gets the same refreshed token.
- Package.resolved pin: 2.55.4 confirmed in `/Users/edisonabdiel/Projects/kizuki_iOS/ios/Package.resolved`. (The path in the brief, `ios/Packages/KizukiKit/Package.resolved`, does not exist.)

### 3.5 Chat design details

- Table design is in 1.6. Policy sketch for INSERT on `messages`: sender = me; `exists (select 1 from conversation_members m join conversations c using (conversation_id) where m.conversation_id = messages.conversation_id and m.profile_id = me and m.left_at is null and c.closed_at is null)`; plus not blocked with any other active member for `direct` (restrictive policy, 1.10).
- Message length 1..2000, no attachments in v0 (Notion: text-first, no large files).
- Report from a message: RPC copies body into `reports.snapshot`, so the evidence survives sender soft-delete.
- Rate limit sends per sender per minute inside a `before insert` trigger [design]; no DB-level rate limiter exists out of the box **[unverified]**.

## 4. Auth, age gate, account deletion (D13)

### 4.1 Sign in with Apple (native id-token flow)

- Flow [docs: https://supabase.com/docs/guides/auth/social-login/auth-apple]: `ASAuthorizationAppleIDCredential` gives `identityToken` (JWT) then `supabase.auth.signInWithIdToken(credentials: .init(provider: .apple, idToken: ...))`. Verified in SDK 2.55.4 source (`AuthClient.swift`: `signInWithIdToken(credentials: OpenIDConnectCredentials)`; `OpenIDConnectCredentials` has `provider, idToken, accessToken, nonce`, `Types.swift`).
- Nonce: the doc's Swift sample omits it. SDK doc comment: "If the token contains a `nonce` claim you must supply the nonce used to obtain the ID token" [source]. Recommended pattern: random raw nonce, `SHA256(raw)` hex into `request.nonce`, raw nonce into `OpenIDConnectCredentials.nonce` (the Flutter sample on the docs page does this) [docs]. The foundation already pulls CryptoKit, per memory notes.
- Configuration: register the bundle ID `club.kizuki.ios` under **Client IDs** in the Apple provider. For a native-only app no Services ID, no OAuth secret, and no 6-month `.p8` secret rotation are needed [docs, same page]. Leave Apple server-to-server endpoint blank (not supported by Supabase) [docs].
- Full name arrives only on the first authorization; later sign-ins return null [docs]. Capture it from the credential immediately and write to `profiles.display_name` through an RPC only if the user confirms it. The foundation's `provision_profile` deliberately copies nothing from auth metadata; keep that.
- Apple "Hide My Email" relay addresses are stored as given (Notion Auth 1). Delivering Kizuki email (OTP, notices) to relay addresses needs the sending domain registered with Apple **[unverified, not read here]**; OTP sign-in does not apply to Apple users, so impact is limited to notifications.
- App Review: Apple 4.8 requires an equivalent privacy-preserving login option when a *third-party/social* login is the primary account. Kizuki offers Apple plus its own email system, so it is compliant [Apple: https://developer.apple.com/app-store/review/guidelines/ (4.8)]. Adding Google later (D13) is safe only while Apple stays.

### 4.2 Email: recommend 6-digit OTP for v0

| Option | For | Against |
|---|---|---|
| **Email OTP** (`signInWithOTP(email:)` then `verifyOTP(email:token:type:)`) | No deep links, no Associated Domains, no PKCE hash-template work, no password storage/reset/breach-list UI. Works when the mail app opens links in an in-app browser. Code entry is in-app. | Needs custom email template with `{{ .Token }}`; user switches to mail app and back. |
| Magic link | One tap. | Needs universal link or custom scheme registered in `additional_redirect_urls`; PKCE needs the template to send a token hash and a confirm endpoint [docs: https://supabase.com/docs/guides/auth/auth-email-passwordless]; breaks in mail-client in-app browsers; link/code expiry shared. |
| Password | Familiar; easiest for App Review demo account. | Needs 10+ chars + breach check (Notion), reset flow, email verify flow; Figma has only the old password screens; D13 says "email", not password. |

Facts from the docs: OTP and magic link share one implementation and differ only in template; codes are six digits, expire in 1 hour by default (same setting governs magic links), one request per 60 s per user, `shouldCreateUser` defaults to true [docs: auth-email-passwordless]. Auth endpoint limit is 30 requests per 5 minutes per IP for sign-in/OTP/verify [docs: https://supabase.com/docs/guides/auth/rate-limits]. Swift calls: `signInWithOTP` and `verifyOTP` exist at 2.55.4 (`AuthClient.swift`).

Hard dependency: the built-in email provider sends **2 emails per hour per project** [docs: rate-limits page]. TestFlight email sign-in will not work without **custom SMTP** (or a Send Email hook). Provider choice and sending domain `kizuki.club`(?) are open (section 8).

Partly verified locally (7.3): with default config a brand-new address calling the OTP endpoint receives the default magic-link email (type `magiclink`) containing a link and no code, so the template must be customised with `{{ .Token }}`. Still **unverified**: behaviour with the repo's `enable_confirmations = true` (may select "Confirm signup") and which `verifyOTP` type (`.email` vs `.signup`) applies to new users. Put `{{ .Token }}` in **both** templates until proven. Inbucket/mailpit is already enabled in `config.toml`.

App Review demo account: reviewers cannot receive OTP mail. Options: a password-enabled reviewer account created in the **production** project only at release (outside this lane), or a test OTP config. **Unverified** whether the CLI/local config supports fixed email test OTPs (the phone equivalent exists). Flag for the release checklist.

Account linking: if an Apple email equals an existing email account, Notion says never merge silently. Supabase auto-links identities with the same *verified* email by default **[unverified]**; check the Auth linking settings before launch.

### 4.3 Age 18+ gate storage (D-list: 18+, Notion Auth 3)

- Decision from specs: a checkbox "I'm 18 or older and agree to the Terms" (Notion Auth 3, Figma `1480:4256`). Figma App/draw once had a birthday picker (walkthrough conflict 11). Recommend **checkbox only, no date of birth**: data minimization, matches "Used to keep the community safe. Not public." Verification of age is not claimed.
- Store in `profile_consents` (private, append-only, server timestamp): `age_confirmed boolean`, `terms_version`, `privacy_version`, `accepted_at`. Written by RPC `accept_terms(terms_version, privacy_version, age_confirmed)`. `onboarding_completed_at` can be set only if the latest consent row has `age_confirmed = true` (trigger).
- Under-18 or unticked: Notion says "Do not store their entered data." The account row exists already after Apple/OTP sign-in, but `provision_profile` stores only the id. So: no insert into `profile_consents`; client calls the delete-account function (4.4) and signs out. Apple's account-creation rule means an account was created, so delete it.
- Apple's Declared Age Range API could add platform-level age signals **[unverified: not researched; mention only]**.
- Guideline 1.2 (user-generated content) requires a content filter, a report mechanism with timely response, a block mechanism, and published contact info [Apple: guidelines 1.2]. Report + block (D16) cover two; a text filter for captions/bios/handles and a support address are gaps to add (section 8).

### 4.4 Account deletion (Apple 5.1.1(v))

Requirement: "If your app supports account creation, you must also offer account deletion within the app" [Apple: https://developer.apple.com/app-store/review/guidelines/ (5.1.1(v))]. Figma has no delete-account screen (walkthrough gap 12); "Need a break? Deactivate" is not deletion.

What Supabase allows:
- The client SDK cannot delete its own auth user; the admin API `auth.admin.deleteUser` needs the secret key (`AuthAdmin.swift` `deleteUser(id:shouldSoftDelete:)`; docs say secret keys must stay server-side [docs: RLS page]). Deleting `auth.users` cascades to rows with `on delete cascade` [docs: https://supabase.com/docs/guides/auth/managing-user-data]; the foundation's `profiles.id references auth.users on delete cascade` already does this, and a pgTAP test proves private settings cascade.
- A user who **owns Storage objects cannot be deleted** until those are deleted or reassigned [docs: managing-user-data]. Deleting `storage.objects` by SQL orphans files; only the Storage API deletes them [docs: https://supabase.com/docs/guides/storage/management/delete-objects]. So deletion order is: Storage API remove (avatar, collab photos, project covers, taste uploads if any), then `deleteUser`.
- Existing access token stays valid until `exp` after deletion [docs: managing-user-data]. Mitigation: short JWT expiry; client signs out locally immediately.

Recommended design [design]: **Edge Function `delete-account`**, verifies the caller's JWT, then with the service role: (1) list and remove `avatars/<uid>/`, `collab/<uid>/`, `projects/<uid>/` via Storage API, (2) call `auth.admin.deleteUser(uid)`. Cascade removes profile, taste, favourites, links, projects (decide: owned projects cascade vs anonymize), requests, memberships, messages. Client then calls `signOut(scope: .local)` (already implemented) and clears Keychain.

Design questions that change the schema:
- `messages.sender_id`, `requests.sender_id`, and `project_members` need a rule: cascade (chat history disappears for the other person) vs `set null` + display "deleted user". Recommend `set null` for messages and requests so the counterpart's history stays coherent; cascade for everything private. Open question for the user.
- `reports.reporter_id` is `set null`; the reported user's data in `reports.snapshot` is kept for safety review. Retention period and legal basis are a user/legal decision (section 8).
- Sign in with Apple token revocation: Apple TN3194 says apps with Sign in with Apple expect to store the refresh token and call `/auth/revoke`; **if you don't have the token, you must still fulfil deletion and then (1) delete data, (2) direct the user to revoke access manually in Apple ID settings, (3) respond to the credential-revoked notification** [Apple: https://developer.apple.com/documentation/technotes/tn3194-handling-account-deletions-and-revoking-tokens-for-sign-in-with-apple]. Supabase's native flow uses only the identity token; whether Supabase persists an Apple refresh token is **unverified**. v0 plan: use Apple's documented fallback (in-app instructions + `ASAuthorizationAppleIDProvider.credentialRevokedNotification` handler). Full revocation (re-authenticate at delete time to get a fresh authorization code, exchange at `/auth/token`, revoke; needs a `.p8` key in Edge Function secrets) is a later hardening; a forum thread suggests this re-auth trick (https://developer.apple.com/forums/thread/707364 via search result; **unverified**).
- Without revocation, the user's next Apple sign-in skips the name/email consent sheet [Apple TN3194, Important note]. Expect "I deleted and re-signed in, my name is empty" support reports.
- Email users: no third-party token to revoke.

## 5. Storage (D9 avatars, D19 collab photo grid)

Local `config.toml` has `[storage] enabled = false`. Enabling it is a prerequisite for everything below (a config change, not done here).

### 5.1 Buckets

| Bucket | Visibility | Path | Written by | Limits (per bucket) |
|---|---|---|---|---|
| `avatars` | public | `<uid>/<uuid>.jpg` (new name each change, so old URLs and caches die) | owner | 1 MB, `image/jpeg`, `image/webp` |
| `collab-photos` | **private** | `<uid>/<photo_id>/thumb.jpg` and `.../full.jpg` | owner | 2 MB, `image/jpeg` |
| `project-covers` | **private** | `<uid>/<project_id>/<uuid>.jpg` | owner | 2 MB, `image/jpeg` |
| `taste-cards` | public | `<realm>/<card_slug>.jpg` | migrations/seed/dashboard only (no client write) | 1 MB |

- Why private for user content [design]: a public bucket serves any URL to anyone, so block, hide, and moderation removal do not revoke access until the object is deleted and the CDN `Cache-Control` (SDK default `3600` s [source: `Storage/Types.swift` `FileOptions.cacheControl`]) expires. Private buckets let the same visibility rules as `collab_photos` apply on read via signed URLs. Cost: signed URLs change, so the app needs an image cache keyed by object path, not URL.
- Avatars stay public: tiny, cache-friendly, Blobatar fallback covers absent photos (D9). Accept that a blocked user could fetch an avatar if they know the URL; the object name is a random UUID.
- Public bucket reads are not governed by RLS; the docs' public avatar example uses `storage.allow_any_operation()` so the bucket cannot be listed [docs: https://supabase.com/docs/guides/storage/security/access-control]. Use the same when making `avatars`/`taste-cards` public.
- Buckets can be created by inserting into `storage.buckets` in a migration, or via client libs with `public`, `fileSizeLimit`, `allowedMimeTypes` [docs: https://supabase.com/docs/guides/storage/buckets/creating-buckets]. Declaring them in `config.toml` (`[storage.buckets.*]`) is **unverified** (page read does not cover it).
- Global limit: Free plan capped at 50 MB per file, Pro up to 500 GB; bucket limits must be below it [docs: https://supabase.com/docs/guides/storage/uploads/file-limits]. Our caps are far below either.

### 5.2 RLS on `storage.objects`

Storage denies uploads without policies and is built on Postgres RLS [docs: access-control page]. Upload needs only INSERT; **upsert additionally needs SELECT and UPDATE** [docs]. Recommend no upsert (fresh UUID names), so no UPDATE policy at all.

Policy shapes [design], all `to authenticated`, role named, `auth.uid()` wrapped:

- INSERT `collab-photos`/`project-covers`/`avatars`: `bucket_id = '<b>' and (storage.foldername(name))[1] = (select auth.uid())::text`. The docs example compares the first folder to `(select auth.jwt()->>'sub')`, equivalent.
- SELECT `collab-photos`: owner always; others only if a visible `collab_photos` row references the object path and the block policy passes: `exists (select 1 from public.collab_photos p where p.storage_path_prefix = (storage.foldername(name))[1] || '/' || (storage.foldername(name))[2] and p.status = 'visible' and not private.is_blocked_pair((select auth.uid()), p.owner_id))`. Index `collab_photos(storage_path_prefix)`. Joins inside storage policies can be slow; fine at v0 scale **[unverified at scale]**.
- DELETE: owner (same folder check).
- UPDATE: none.
- Orphans: deleting `storage.objects` by SQL does not remove files; always use the Storage API [docs: https://supabase.com/docs/guides/storage/management/delete-objects]. Deleting a DB row (e.g. `collab_photos`) does not delete its objects. Client flow: remove objects through the API, then delete the row; plus a periodic reconcile job (Edge Function) later.
- A user who owns objects cannot be deleted from `auth.users` until they are removed [docs: managing-user-data] — see 4.4.

### 5.3 Image sizes and transforms

- supabase-swift 2.55.4 exposes `TransformOptions` (resize `cover|contain|fill`, format `origin|webp|avif`, width/height, quality) on `getPublicURL`, `createSignedURL`, and `download` [source: `Storage/StorageFileApi.swift`, `Storage/Types.swift`].
- **Vendor claim:** "Image Resizing is currently enabled for Pro Plan and above"; width/height 1-2500, source up to 25 MB, up to 50 megapixels, HEIC accepted as input only; billed at $5 per 1,000 origin images beyond a 100-image included quota on Pro and Team [docs: https://supabase.com/docs/guides/storage/serving/image-transformations]. Must also be enabled in the dashboard. Not checked: whether Free-plan transform calls error or return the original.
- Recommendation [design]: **do not depend on server transforms in v0.** Generate renditions on device before upload: `thumb` (about 400 px long edge, JPEG q0.7, tens of KB) for the 3-column grid and `full` (about 1600 px, q0.8) for the detail view. Convert HEIC to JPEG on device. Strip EXIF/GPS on device (privacy; Supabase does not state that it strips metadata **[unverified]**). Upgrade to transforms later by only changing URL construction.
- Upload API: `storage.from(bucket).upload(path, data:/fileURL:, options: FileOptions(contentType:, upsert: false))`; the `fileURL:` overload streams (`StorageFileApi.swift`).
- Grid fetch: for a page of 30 tiles, one batch signed-URL call (`createSignedURLs(paths:expiresIn:...)` exists in non-deprecated form at `StorageFileApi.swift:465` and `:529` [source]), TTL about 1 h. Removal API: `remove(paths:)` (`:595`).

### 5.4 Moderation gaps tied to storage

- Apple guideline 1.2 expects "a method for filtering objectionable material from being posted" [Apple guidelines]. Supabase Storage has no built-in image moderation **[unverified: not found in docs read]**. Options: on-device Apple Sensitive Content Analysis framework (iOS 17+, **unverified here**) before upload, a server moderation API called from an Edge Function (adds cost/vendor/DPA), or human review via `status = 'hidden'` from the dashboard. Report + block alone does not satisfy the "filtering" bullet. Open question for the user (section 8).

## 6. Mock data (D18: no real data, seeded end to end)

### 6.1 Approach: generated, committed `supabase/seed.sql` plus a local-only storage uploader

- Supabase's documented default is a hand-written `supabase/seed.sql`, "the simplest and most reliable approach"; seeds run the first time `supabase start` runs and on every `supabase db reset`, after migrations, and should contain only data inserts [docs: https://supabase.com/docs/guides/local-development/seeding-your-database]. `[db.seed]` currently has `enabled = false` in the repo; switching to `true` (default path `supabase/seed.sql`, or `sql_paths`) is a config change for the build lane.
- 60 users x many tables is too large to hand write. Recommend a small generator (`scripts/generate-seed.py`, stdlib Python, already used by the repo's scripts) that uses `random.Random(<fixed int>)` and writes `supabase/seed.sql`. Commit the output; CI regenerates and runs `git diff --exit-code` to catch drift. Python's seeded RNG is under our control.
- Why not `setseed()` in SQL: Postgres documents `random()` as deterministic after `setseed()` within a session, but does not promise the sequence is identical across versions or platforms [pg: https://www.postgresql.org/docs/17/functions-math.html]. Local, CI and a future major upgrade could diverge. Generated literal SQL avoids this.
- Snaplet Seed is described by Supabase as community-maintained with occasional fixes [docs: seeding page]; skip it (extra toolchain for no gain).
- Fixed UUIDs: derive with `uuid5(namespace, "user-17")` in the generator, so tests, screenshots, and bug reports can name `user-17` stably.
- `auth.users` seeding is not covered by the docs page read. Needed columns and whether an `auth.identities` row is required for OTP sign-in to an existing user are **unverified; confirm in Inbucket once Docker or the native runtime runs**. The existing `provision_profile` trigger will create `profiles`/`profile_settings` for each inserted user, so the seed then `update`s them.
- Dev sign-in as a seeded user: email OTP (code arrives in Inbucket, already enabled in `config.toml`), plus one local-only password user for UI tests. Never create a password user in production.
- Storage objects cannot be seeded by SQL (SQL-created `storage.objects` rows do not create files [docs: delete-objects page, same orphan logic]). Use `scripts/seed-storage.py`: resizes images to the two renditions and uploads through the local Storage API with the local service key from `supabase status`, reusing the existing loopback-only guard `scripts/local_backend.py::require_local_url` (refuses any URL except `http://127.0.0.1|localhost:54321`).

### 6.2 Volumes (proposal)

| Entity | Count | Notes |
|---|---|---|
| Users / profiles | 60 | 52 onboarded; 5 mid-onboarding (resume cases); 2 `deactivated`; 1 `suspended`. ~70% Berlin, rest Hamburg, Leipzig, remote-only. Realms: film 60%, music 20%, visual 15%, mixed 5% (matches the Berlin indie-film wedge, Notion). |
| Roles / project types / facets / cities | ~45 / ~30 / ~40 / ~12 | Taxonomies hand-written once; role names from Figma lists. |
| Projects | 25 | 12 published (incl. one unpaid, one open-to-either, one expiring tomorrow), 5 draft, 3 closed (filled), 3 past, 2 expired. 1-4 `project_roles` each. |
| Requests | 30 | All 5 states; at least one per kind; includes an accepted request with a chat, a duplicate-attempt fixture, and a pair that later blocked. |
| Conversations / messages | 6 / ~90 | 4 direct, 2 project groups; one closed by block; message lengths and timestamps varied for list sorting. |
| Collab photos | 90 | Two per user average, 1-8 per user, captions 20-120 chars, 12 tag values for filter chips (Figma chips: motion design, creators, painting). |
| Favourites | ~250 | 4-5 per user; fixed external IDs hand-picked and checked against TMDB/MusicBrainz once by the author, not fetched during seed. |
| Taste cards / selections / pair choices | 96 / ~180 / ~300 | 24 per realm (Notion minimum) plus cross-medium; selections 3-5 per onboarded user. |
| Blocks / reports | 4 / 5 | Block pairs include a mutual block; reports cover each target kind and status. |
| Profile links | ~120 | YouTube, SoundCloud, Bandcamp, Letterboxd, Instagram URLs pointing at **reserved or example targets** (never real accounts of real people). |

Total is small enough that `supabase db reset` seed time is seconds. The seed must exercise every state machine edge once (all `request_status` values, `project_status` values, blocked pair visibility, expired project) so UI and RLS tests have fixtures.

### 6.3 Images: licensed placeholder source

- **Collab photos: Pexels.** License: "All photos and videos on Pexels are free to use", attribution not required, modification allowed; not allowed: selling unaltered copies, redistributing on other stock/wallpaper platforms, implying endorsement, identifiable people shown "in a bad light or in a way that is offensive" [Pexels: https://www.pexels.com/license/ (page shows no revision date)]. Rule for the seed: pick **objects, places, gear, sets, screens, artworks; no identifiable people**, because pairing a stranger's portrait with a fictional persona is misleading and strains the "bad light" clause. Record photographer, URL, and retrieval date in a committed `supabase/seed-assets/MANIFEST.csv`; keep the image files out of git (`.gitignore`) so the repo does not become a redistribution of the photos.
- **Zero-risk alternative for painting/visual-arts tiles: The Met Open Access** (CC0): the Met "has waived all copyright and related or neighboring rights to this dataset"; no API key; 80 requests/second; per-object `isPublicDomain` flag (check each record, search has no such filter) [The Met: https://metmuseum.github.io/].
- Unsplash is also usable (free for commercial and non-commercial use, no attribution required) but forbids "compiling images from Unsplash to replicate a similar or competing service" [Unsplash: https://unsplash.com/license]. A photo-grid app is arguably close to that line. Prefer Pexels or Met.
- **Avatars: none.** Seeded users keep `avatar_path = null` so the app shows Blobatar (D9). This also exercises the fallback path.
- **Taste cards (D21):** placeholder art generated by the script (gradients and shapes, our own work, no third-party rights), each with `rights = 'placeholder'`, `alt_text` from its facets. The launch-blocker is a release checklist item: no `published` taste card may have `rights = 'placeholder'` (add as a pgTAP test on the release data set, not on the dev seed).
- All licence text above was read on 2026-10-25; licences can change. Re-check before shipping anything derived from them.

### 6.4 Keeping seeds out of production

Controls, strongest first [design unless cited]:

1. **Only migrations ship to production.** Seeds run on `supabase start` and `db reset` locally [docs]. The CLI can include seeds in a remote push: `supabase db push` has `--include-seed` ("Include seed data from your config") and also `--dry-run`, `--linked`, `--db-url` [docs: https://supabase.com/docs/reference/cli/supabase-db-push]. Never pass `--include-seed`; production pushes are a separate, human-approved release step (already stated in `00-what-exists.md`). The repo script `scripts/supabase-local.sh` deliberately contains no `link`, `db push`, or `--db-url`.
2. **Seed refuses non-empty real data.** First statement of `seed.sql`: abort unless `auth.users` is empty or contains only `@seed.kizuki.test` addresses. `.test` is reserved by RFC 2606 "for use in testing" [https://www.rfc-editor.org/rfc/rfc2606], so the domain should never resolve to a real mailbox (the RFC reserves the name; it does not itself guarantee mail behaviour).
3. **No schema flag for "seed" in production tables.** Seed identity is the email domain on `auth.users`, so production schema stays clean.
4. **CI guard:** a script greps `supabase/migrations/` for `insert into` on user-data tables and fails (taxonomy/lookups excepted via allow-list); a test asserts `config.toml [db.seed]` points only at `supabase/seed.sql`.
5. **Taxonomy vs mock data split:** lookup data that production needs (roles, project types, facets, cities, bucket definitions) goes in **migrations**; mock people/projects/photos go in **seed.sql**. Mixing them is the usual way mock rows reach production.
6. **Release checklist:** after the first production migration, run read-only checks (`select count(*) from auth.users where email like '%@seed.kizuki.test'` must be 0) through a human-run, read-only connection. Not run here: production is not touched in this lane.

## 7. Local development without Docker Desktop

### 7.1 State of this machine (measured 2026-10-25)

- macOS 26.3.1, arm64, 16 GB RAM. Free disk was about 13 GiB before this research and 8.7 GiB after (see 7.3).
- `/opt/homebrew/bin/docker` is the **Docker CLI only** (Engine client 28.5.1, context `default`, socket `/var/run/docker.sock`); no daemon, no Docker Desktop, OrbStack, Colima, or Podman installed (`/Applications`, `brew list`, `which`). `supabase` is not on PATH; the repo runs it as `npx supabase@2.122.0` (`scripts/supabase-local.sh`), which exits early with "Docker daemon unavailable".

### 7.2 Options

| Option | Notes | Status here |
|---|---|---|
| Docker-compatible runtime | Docs: "A container manager compatible with Docker APIs is a prerequisite for `supabase start`" [docs: https://supabase.com/docs/guides/local-development]. Lists OrbStack (macOS, recommended), Docker Desktop, Rancher Desktop, Podman; the getting-started page also lists Colima [docs: https://supabase.com/docs/guides/local-development/cli/getting-started]. Cheapest path with the least surprise: `brew install --cask orbstack` (or `brew install colima`; the existing Homebrew `docker` CLI works with Colima). Tradeoff: images are pulled via Docker (size **unverified**, not measured), disk is tight. | Not installed. User decision (installing software, licences: OrbStack/Docker Desktop terms **unverified**). |
| **Experimental native runtime** (`supabase start --runtime native`) | Runs Postgres, Auth, REST, Realtime, Storage, mail, etc. as host processes on Apple silicon with macOS 14+; no container engine [docs: https://supabase.com/docs/guides/local-development/docker-and-native-runtimes]. Docs call it experimental; flags and output may change; one project per machine is advised. | **Tried in a scratch directory outside the repo; worked (7.3).** |
| CI (`ubuntu-latest`) | The repo's `foundation.yml` `local-backend` job already runs `scripts/supabase-local.sh start/reset/test` with Docker. Supabase's own CI recipe is `supabase/setup-cli` + `supabase start` + `supabase test db` [docs: https://supabase.com/docs/guides/local-development/testing/overview]. | Exists. Results only on push/PR. |
| Remote hosted project | A separate **staging** project (free plan allows two free projects [docs: billing page]). Never production. | Not created; user decision (8.2 Q1). |
| Pure-SQL checks without any stack | Plain Postgres 17 via Homebrew for syntax and pgTAP only; no Auth/Storage/Realtime. | Not tried. |

### 7.3 What I verified with the native runtime

Scratch copy only (`/tmp`, since removed); the repo's `supabase/` directory and production were not touched. CLI `supabase@2.122.0` (same pin as the repo), `SUPABASE_EXPERIMENTAL_STACK=1 supabase init`, copied the repo's migration and pgTAP test, `supabase start --runtime native`.

- Artifacts resolved: Postgres 17.11.0.006, PostgREST v16.5, Auth v2.197.0, Realtime v2.147.1, Storage v1.84.19, imgproxy v3.26.0, Edge runtime v1.77.8, Studio, pgmeta, mailpit, analytics, pooler. First download took roughly 15 minutes on this connection and left **1.8 GB in `~/.supabase/cache`**. The first `start` attempt failed while artifacts were still downloading (`ExperimentalStackStartError: Owner response unavailable`); `supabase stack install --runtime native` first, then `start`, succeeded.
- Docs mention `supabase stack prepare`; in 2.122.0 the subcommand is `supabase stack install` (`prepare` is rejected). Minor docs/CLI drift.
- `start` applied `20261024000100_own_profile_foundation.sql` ("Applying migration ..."), and **`supabase test db --local` passed all 10 pgTAP tests** (`own_profile.test.sql`). So RLS/pgTAP work needs no Docker on this machine.
- Services are started lazily ("sleeping" until first request). After HTTP calls, `auth/v1/health`, `rest/v1/`, `realtime/v1/api/ping`, `storage/v1/status` each returned 200 through the gateway; database, rest, auth, realtime, storage, mail were `running`.
- Email OTP probe (settles part of 4.2): with the CLI default config (`enable_confirmations = false`), `POST /auth/v1/otp` for a **new** address sent the default "Your sign-in link" (type `magiclink`) email with **no 6-digit code**; so a custom template containing `{{ .Token }}` is required for OTP entry. Not tested with the repo's `enable_confirmations = true` (that could select the "Confirm signup" template) -> still **unverified** for the repo config.
- **Differences that break the repo's scripts:** the native stack uses random ports (API gateway `127.0.0.1:26333`, Postgres `27381`, mail UI `21030` in this run) instead of 54321/54322/54324; `scripts/local_backend.py::require_local_url` accepts only port 54321, `supabase-local.sh` checks `docker info` first, and `status --output json` is not supported (use `--output-format json`). Realtime WebSocket/Postgres Changes, Storage uploads, and Edge Functions were **not exercised**. Native `pg_cron` needs CLI >= 2.121.0 [docs], satisfied by 2.122.0.
- Cleanup done: `supabase stack stop` and `stack destroy`, no processes left. The 1.8 GB artifact cache remains (`~/.supabase/cache`); delete it to reclaim disk, or keep it to skip the 15-minute download. Network access to GitHub releases or `supabase-cli-artifacts.s3.us-east-1.amazonaws.com` is required [docs].

### 7.4 What is blocked until a stack runs (any runtime) and what is not

Blocked until a stack is running:
- Applying new migrations and running pgTAP (`supabase test db`) for the tables designed above.
- `scripts/test-local-api.py` and the `Local` scheme's integration tests against real Auth/PostgREST (the repo's guard expects port 54321).
- Verifying: email OTP template behaviour with repo config, Apple `signInWithIdToken` against a local Auth (needs Apple client ID config), Realtime Postgres Changes with RLS, Storage policies and signed URLs, signed-URL image grid, Edge Function `delete-account`.
- Seeding (`db reset` runs `seed.sql`) and EXPLAIN-based timing of `recommend_v1`.

Not blocked: Swift UI work with fixtures (the app has a fixture backend), writing migrations and tests as text, schema review, generating `seed.sql` text, CI runs.

Recommendation: install **OrbStack or Colima** if the user is willing (conventional path, matches CI, keeps ports at 54321 so existing scripts work); otherwise adopt the native runtime for local pgTAP and Auth/REST work and patch the port assumption in the scripts (a build-lane task). Either way keep CI as the arbiter.

## 8. Risks and open questions

### 8.1 Risks (ranked)

1. **Hosted environment for TestFlight is undefined (blocks D1 + D18).** D1 says the loop runs "on real local data, on TestFlight"; D10 says `enosggckdxjiaqtxalhg` is production and development is local; D18 says seeded mock data only. A TestFlight build cannot reach a laptop's `127.0.0.1:54321`. Either mock data reaches a hosted project (violating "seeds stay out of production") or TestFlight runs against an empty production project (nothing to see). Free plan includes two free projects [docs: https://supabase.com/docs/guides/platform/billing-on-supabase], so a second `kizuki-staging` project is cheap. Needs a user decision before any release plumbing.
2. **Account deletion is a multi-part feature, not a button.** Needs the project's first Edge Function (service-role secret, currently `edge_runtime.enabled = false`), Storage cleanup before user deletion (owners of objects cannot be deleted), cascade/anonymize decisions, and the Sign in with Apple revocation story (TN3194). Missing from Figma. App Review rejection risk if skipped (5.1.1(v)).
3. **Email sign-in cannot work at TestFlight scale on the built-in mailer**: 2 emails per hour per project [docs: rate-limits page]. Needs custom SMTP, a sending domain with SPF/DKIM, and an App Review demo-account plan.
4. **Schema built from specs, not from the Notion "Supabase Data Model & RLS" page.** That page and "Backend Functions & Jobs" exist (linked from the Development hub) but were not readable here. Drift risk; reconcile first.
5. **Block/visibility correctness.** `security definer` functions and views bypass RLS. Every read path (feed, search grid, profile, project, chat, favourites, storage signed URLs) needs a pgTAP case with a blocked pair in both directions. Nothing here has been run.
6. **UGC compliance (Apple 1.2):** needs objectionable-content filtering for posts (bios, captions, photos), timely report response, block, and published contact info [Apple: guidelines]. Report + block (D16) is only half.
7. **Third-party data terms:** TMDB commercial licence likely required once monetized; 6-month cache cap; attribution wording. MusicBrainz 1 req/s per IP, so device-direct calls (section 1.8).
8. **Local toolchain:** no running container runtime; 16 GB RAM and 8.7 GiB free disk after this research's 1.8 GB native-runtime cache (measured `df`, `du`). A Docker-based stack pulls its own images (size unverified). Native runtime works for DB tests but breaks the repo's fixed-port scripts (7.3).
9. **Production is empty but real.** `public` had no tables on 2026-10-24 (`00-what-exists.md`); other schemas, auth settings, storage, and project plan are unknown. A first `db push` is hard to undo. Use `--dry-run` and a human gate [docs: db-push flags].
10. **Realtime semantics unproven locally.** Postgres Changes with RLS, and the Broadcast option, have not been exercised against this schema. Chat reconnect behaviour must be tested with airplane-mode toggles.

### 8.2 Open questions for the user (decision needed)

1. TestFlight backend: create a separate staging Supabase project for mock-data alpha builds? Which plan is production on (Free pauses/limits vs Pro)?
2. Email sign-in method: confirm OTP code (recommended) vs password. Who owns the sending domain and SMTP provider?
3. Hard compensation filter on **People**: hide paid-seeking people from unpaid projects only, or no filter? (Spec only defines Join.)
4. Can a **project owner invite a person** (`invite_to_project`) in v0, or only people requesting? D-list says "request (to join a project/role or collaborate with a person)".
5. Is "Post a collab" (photo + caption) a separate content type from Project? (Figma open question 3.) Recommended: yes, `collab_photos`.
6. On account deletion: should a deleted user's sent messages and requests disappear (cascade) or remain as "Deleted user" (set null)? What report-retention period is acceptable (legal)?
7. Age gate: checkbox only (recommended) or date of birth? Is there legal/Apple pressure for stronger age assurance in Germany/EU? **Unverified; not legal advice.**
8. Photo moderation: on-device sensitive-content check, third-party moderation API, or human-only review in the Alpha? Who answers reports and within what time? Support/contact address and Terms/Privacy URLs?
9. Location: D8 asks permission up front, but specs store city-level only. Do we need device location at all in v0 (to pre-fill city, or "Near me" sort), and are coordinates ever stored? Recommended: use it once to suggest a city on-device, store nothing.
10. Handle policy: lengths (3-24 existing vs Figma 3-20/5+), reserved-word and profanity lists, 30-day rename, 30-day holding. Include renames in v0?
11. Seed realism: OK to use Pexels/Met images (section 6.3) and fictional Berlin names, and which cities/genres should the 60 users represent?
12. Notifications (D8): in-app only for TestFlight, or APNs push (needs Apple key, Edge Function, device token table) in this round?
13. Taste weights and score threshold: values in "Recommendation & Taste Algorithm v1" (unread). Use my placeholders until read?
14. Favourites: confirm TMDB commercial licence path and attribution placement (About screen), and MusicBrainz User-Agent contact.
15. Projects: keep four statuses (draft/published/closed/past) with `closed_reason`, or expose Notion's eight?

## 9. One-page recommendation: build / reuse / skip

### Build (in this order; each migration ships with pgTAP RLS tests)

1. Enums, taxonomy tables (roles, project types, facets, cities), and the `private` schema with `is_blocked_pair` plus `blocks`/`reports` **first**, so every later table gets its restrictive block policy and report path from day one.
2. Profile extension: public profile columns, `profile_consents` + `accept_terms` RPC (checkbox age gate, server timestamp), `profile_roles`, `profile_links`, `favourites`, `profile_settings` additions, handle rules.
3. Projects, `project_roles`, publish CHECK, `project_members`.
4. Requests + the three RPCs + transition trigger + duplicate partial index + rate limit; conversations/members/messages created only inside `respond_request`; messages INSERT policy.
5. `collab_photos` + buckets + `storage.objects` policies (private user buckets, two client-made renditions).
6. Taste: cards, facets, `submit_taste` RPC, `profile_taste`.
7. `recommend(kind, ...)` RPC, `recommend_v1` in SQL, `ranking_weights` table, reason codes, impression log.
8. `delete-account` Edge Function (service role; Storage cleanup, then `deleteUser`) and the Apple revocation fallback copy.
9. Seed generator (`scripts/generate-seed.py` -> `supabase/seed.sql`, CI drift check), `scripts/seed-storage.py`, MANIFEST of image sources.
10. Swift side later: `ChatTransport` protocol (Postgres Changes first), image cache keyed by object path, nonce'd Apple sign-in, email OTP screens.

### Reuse (already in the repo or the platform)

- Foundation migration pattern: separate private table, revoke-then-grant, `security definer` trigger with `search_path = ''`, cascade from `auth.users`, pgTAP style.
- `SupabaseBackend` single shared `SupabaseClient` (PKCE, Keychain, auto refresh); the SDK already forwards refreshed tokens to Realtime. supabase-swift 2.55.4 already contains Auth (`signInWithIdToken`, `signInWithOTP`, `verifyOTP`), Realtime V2, Storage (with `TransformOptions`), PostgREST `rpc`.
- CI job `local-backend` already runs `supabase start`, `db reset`, `test db` on `ubuntu-latest` (`.github/workflows/foundation.yml`): this gives DB tests a Docker-backed home while the laptop has none.
- `scripts/local_backend.py` loopback guard (reuse for the storage seed uploader), pinned CLI `supabase@2.122.0`, Inbucket for OTP mail.
- pg_cron for expiry (platform); `supabase test db` / pgTAP for RLS tests.

### Skip (for v0)

- pgvector and any Edge Function ranker (SQL is enough, replaceable via the `recommend` contract).
- Broadcast-from-Database chat (revisit past ~1k concurrent chatters or when presence/typing is wanted).
- Server image transforms (Pro-only [vendor claim]); client renditions instead.
- Password auth, date of birth, `response_ms`, server-side link scraping/recheck, appeals tooling, group-chat extras (attachments), cursor pagination, Snaplet, full-text search (use `ilike`/trigram).
- Any write to production; any `db push --include-seed`.

### The three decisions that gate the build

1. A staging Supabase project for TestFlight (or an explicit "no TestFlight until later" answer).
2. Custom SMTP + email OTP.
3. Reading the Notion Data Model/RLS and Backend Functions pages before the first migration.
