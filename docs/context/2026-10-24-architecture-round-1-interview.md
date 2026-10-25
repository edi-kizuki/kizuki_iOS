---
title: Architecture round 1 — Phase 1 interview
created: 2026-10-24
tags: [project/kizuki, architecture-round, decisions]
status: in-progress
---

# Architecture round 1 — Phase 1 interview

Related: [[playbook]], [[00-what-exists]], [[2026-10-24-notion-source-extracts]], [[2026-10-24-figma-screen-inventory]].

Process: [[playbook]] section 5. User answers below override conflicting sources.

## User decisions (2026-10-24)

| # | Topic | Decision |
|---|---|---|
| 1 | Round destination | Core loop v0: sign-in → onboarding → Home/Discover → request → accept → chat, on real local data, on TestFlight. |
| 2 | Bottom navigation | Figma tabs win: Home, Search, Suki, Create, My Projects. Overrides Notion's Discover/Projects/People/Inbox/You. |
| 3 | Compensation matching | Paid seekers match Paid and Open-to-either projects. |
| 4 | Tooling | Install Archify + Pocock skills; build local project hub (section 3); Wayfinder map before research lanes. |
| 5 | Suki vs Create tabs | Suki = matches and requests. Create = new project/collaboration. (Supersedes earlier answer that Suki also creates.) |
| 6 | Chat + own profile | Top-bar icons on Home (Inbox, avatar). |
| 7 | Start-user landing | Home with a "Finish your project" card (onboarding v3.1). |
| 8 | Permissions | Location and notifications requested up front in onboarding (Figma flow). Overrides Notion's defer rule. |
| 9 | Avatars | Deterministic Blobatar fallback; uploaded photo overrides it. |
| 10 | Backend | Supabase `enosggckdxjiaqtxalhg` is production; develop locally. Bundle ID `club.kizuki.ios`. |

| 11 | Messaging gate | Chat opens only after a request is accepted. Figma "anyone can message" is not used. |
| 12 | Payments | None in v0. Compensation is a label only. |
| 13 | Sign-in | Apple + email in v0. Google later. |
| 14 | Taste capture | Taste cards deferred until rights, taxonomy and tagging owner are resolved. v0 matches on realm, roles, intent, compensation, city, availability. |
| 15 | Recommendations | Simple, transparent rule-based scoring in Postgres, with match reasons shown. Replaceable later. |
| 16 | Safety | Report + block in v0. Reports reviewed in Supabase dashboard. Appeals later. |
| 17 | Illustrations | User will grant the agent's Figma account editor access to `fLQY6jJbQ0adtsqjXd5jg2`. |
| 18 | Data | No real data in v0. Seeded mock data (users, projects, collab images, requests, chats) to test features and flows end to end. |
| 19 | Tab definitions (2026-10-25) | Home = feed of recommended projects + "People that you might like" (algorithm-ranked); settings gear + DMs icon top-right (Figma `Feed / Discovery Page`). Search = search bar, filter chips, 3-column grid of collaboration photos users uploaded on profiles. Suki = matches, requests, creating new projects/collabs. My Projects = drafts, published projects, past collaborations. Fifth tab = Profile. Supersedes #5 and #6. |
| 20 | Figma | Agent must fully navigate the Figma file before concept work. Walkthrough: [[2026-10-25-figma-full-walkthrough]]. |

Note on #19 vs #5: user restated Suki as including project/collab creation. Create-tab question resolved by #19 — there is no Create tab; the five tabs are Home, Search, Suki, My Projects, Profile.

## Taste and connectors (reopened 2026-10-25)

| # | Topic | Decision |
|---|---|---|
| 21 | Taste cards | In v0 with placeholder images. Image rights, facet taxonomy and tagging owner become launch-blocker tasks. Supersedes #14. |
| 22 | Taste data source | In-app favourites picker (films via TMDB, music via MusicBrainz). Research lane must verify TMDB/MusicBrainz terms and fit. |
| 23 | Profile widgets | v0: links + embedded players (YouTube, SoundCloud, Bandcamp, Letterboxd link; Instagram only if embed is feasible without blocking review). |

| 24 | Follows | None in v0. Requests only. |
| 25 | Comments | None in v0. Likes, saves, requests only. |
| 26 | Missing UI | Suki matches/requests and My Projects have no Figma frames; agent designs them in SwiftUI from existing components/tokens; user reviews in simulator. |
| 27 | Figma access | User will upgrade the connected account to a Dev/Full seat; then re-run screenshots + variables. Walkthrough: [[2026-10-25-figma-full-walkthrough]]. |
| 28 | Figma conflicts | Follow decisions over Figma: drop Apple/Google Pay; drop "anyone can message" and cold "New message"; Apple + email sign-in (not Google); reword event-style copy. |

Evidence (2026-10-25, web search; verify in research lane):
- Letterboxd API is by request only and excludes "data-analysis, visualization or recommendation projects" ([letterboxd.com/api-beta](https://letterboxd.com/api-beta/)). Not usable for matchmaking.
- Spotify Web API extended access since 2025-05-15 reserved for established businesses ([Spotify blog](https://developer.spotify.com/blog/2025-04-15-updating-the-criteria-for-web-api-extended-access)); 250k MAU figure and 2026 dev-mode limits are from secondary sources ([dev.to](https://dev.to/leemartin/the-state-of-spotify-web-api-report-2025-4gh3)). Not usable for launch.
- Figma illustrations file `fLQY6jJbQ0adtsqjXd5jg2`: still "no edit access" on 2026-10-25.

## Out of v0

Made Together outcomes, Google sign-in, payments, appeals/admin tooling, events, Spotify/Letterboxd data import, real user data.

## Research follow-up decisions (2026-10-25)

From [[2026-10-25-supabase-backend-research]] and [[2026-10-25-ios-client-integrations-research]].

| # | Topic | Decision |
|---|---|---|
| 29 | TestFlight backend | New separate **staging** Supabase project, mock data only. User creates it. Production untouched. Refines #10/#18. |
| 30 | Email sign-in | Email + password (plus Apple). Gives App Review a demo account. |
| 31 | Permission primers | Single "Continue" button before each system prompt (Apple rule). Denial never blocks; manual city fallback. Refines #8. |
| 32 | Tab bar | System `TabView`, icon-only. Not a pixel-matched custom bar. |
| 33 | Apple Developer account | Organization (Kizuki entity). Needs legal entity, D-U-N-S, website. |
| 34 | Moderation | User reviews reports daily in Supabase dashboard (24h target), plus auto-hide after several reports. No paid moderation API. |
| 35 | Notifications | Real APNs push for new request, acceptance, message. Needs Apple push key + Edge Function. |
| 36 | Invites | Project owners can invite a person; same request → accept → chat flow, both directions. |

### Defaults taken by the agent (user may override)

- Instagram and Letterboxd: link-out only in v0. YouTube, SoundCloud, Bandcamp: embedded players.
- Suki AI assistant (Figma settings copy): out of v0.
- Music favourites: text-only tiles (no Cover Art Archive hotlinks) until rights are clear.
- Age gate: "I am 18 or older" checkbox with server timestamp; App Store rating 18+.
- Location: used once on-device to suggest a city; coordinates never stored.
- Collab photos (photo + caption) are their own content type, separate from projects.
- Projects: four statuses (draft, published, closed, past) with `closed_reason`.
- Handles: 3–20 chars; rename rules deferred.
- Account deletion: messages/requests remain as "Deleted user"; report retention period pending legal input.
- Mock seed: fictional Berlin-first creators; Pexels / Met Open Access images with a source manifest.
- TMDB/MusicBrainz: non-commercial terms acceptable for TestFlight; commercial licensing is a launch blocker.

## Access and environment updates (2026-10-25)

| # | Topic | Decision |
|---|---|---|
| 37 | Canonical Figma files | Use the copies in the user's Kizuki team (Full seat, verified: metadata, screenshot, variables all succeed). App: `nPqXTMCtd3OVZTSU7Y2uN3` ([Kizuki App (Copy)](https://www.figma.com/design/nPqXTMCtd3OVZTSU7Y2uN3/Kizuki-App--Copy-)). Illustrations: `dPirB4bC1bB7KcxaacOVHG` ([Kizuki illustrations (Copy)](https://www.figma.com/design/dPirB4bC1bB7KcxaacOVHG/Kizuki-illustrations--Copy-)). Originals `XIe9K1RrE3wgLnlBJ59p1i` / `fLQY6jJbQ0adtsqjXd5jg2` are superseded for agent work. Supersedes #17, #27. |
| 38 | Staging Supabase | `https://ankgfqkgflcalmlreetu.supabase.co` (project ref `ankgfqkgflcalmlreetu`). Mock data only. Publishable key not yet supplied. Implements #29. |
| 39 | Apple Developer enrolment | Deferred by user; not a current task. |

Figma variables returned for Feed / Discovery Page (`1467:4643`): Kizuki Baby Blue Backgrounds `#C6CEDF`, Charcoal `#1A1A1A`, Cream `#F2EEE7`, Grey `#333333`, Kizuki Baby Blue icons `#B7C4DF`, Kizuki Blue `#3F7BE2`.

## Concept v1 open decisions (2026-10-25)

From [[2026-10-25-architecture-concept-v1]] section 7.

| # | Topic | Decision |
|---|---|---|
| 40 | Suki "Matches" (OD-14) | Accepted connections (active collaborations). Pending requests in/out sit alongside. |
| 41 | City on profile (OD-4) | Public city label only (e.g. "Berlin, DE"); no coordinates. Overrides Notion's private-city rule. |
| 42 | Deleted user's messages (OD-7) | Shown as "Deleted user"; text kept 30 days for safety review, then erased. Supersedes the earlier agent default. |
| 43 | Staging app identity (OD-5) | One app, bundle ID `club.kizuki.ios`; TestFlight builds point at staging. `Staging.xcconfig` must change from `club.kizuki.ios.staging`. |

### Agent recommendations accepted by default (user may override)

OD-1 Notion v1 scoring formula in SQL · OD-2 direct (1:1) chats only · OD-3 6-digit email verification code after sign-up · OD-6 auto-hide after 3 distinct reporters · OD-8 likes private, no public counts · OD-9 OrbStack or Colima for local runtime · OD-10 no message edit/unsend in v0 · OD-11 image safety = report + auto-hide + daily review · OD-12 hide paid-seekers only from viewers whose projects are all unpaid · OD-13 projects expire after 30 days, renewable.

Pending from user: OD-15 email sending domain, mail provider, support address.

## Later decisions (2026-10-25)

| # | Topic | Decision |
|---|---|---|
| 44 | Naming: accepted connections | Called **Crew** in the UI, never "Matches". Applies to the Suki tab, copy, and code names where user-facing (e.g. `CrewView`). Internal matching/scoring terms may stay technical. Refines #40. |
| 45 | Agent rotation | Alternate Codex and Claude agents and models by task complexity, type and daily/weekly usage (playbook section 8, rule 2). |
| 46 | Staging plan (OD-16) | Supabase Free while building; upgrade staging to Pro before external testers. |
| 47 | Apple/email collision (OD-17) | Accept Supabase automatic identity linking; tell the user immediately, with Undo. |
| 48 | Favourites in matching (OD-18) | On by default, visible toggle in settings. |
| 49 | Reported messages of deleted users (OD-20) | Text kept until the open report closes, then erased. Legal confirmation needed before public launch. |
| 50 | Availability / work mode visibility (OD-19) | Owner-only for now; revisit in the design round (Figma shows an availability card). |

## Prototype review decisions (2026-10-25)

From [[2026-10-25-prototype-report]].

| # | Topic | Decision |
|---|---|---|
| 51 | Availability visibility | Shown on every profile, always (public). Supersedes #50 and the owner-only rule for availability. Work mode follows the concept unless the user says otherwise. |
| 52 | Request wording | From a person's profile: **"Wish to Collab"** (allowed without a project). From a project: **"Join project"**. |
| 53 | Accept → chat | Accepting opens the chat immediately. |
| 54 | Remove from Crew | Separate "Remove from Crew" action, distinct from Block. |
| 55 | Search content | Photos or short videos only; no people results. |
| 56 | Tab bar | Keep the iOS 26 floating tab bar, with Kizuki's own icons (icon sheet attachment `37fb3c48-...-06dd828a-...jpg`, Figma Playground (Copy) `3po5ynomzdPNe2mcO7IKRw` node `614:260`, page "Kizuki \| Moodboard", frame "concept_8.6"). Agent chooses which icon fits each tab. App icon and logos come from the same source. |
| 57 | "Get discovered" placement | Agent places it where it fits best for UX (not necessarily Profile > Edit); document the reasoning. |

## Website (2026-10-25)

| # | Topic | Decision |
|---|---|---|
| 58 | Landing page | Scrollytelling, minimal text, smooth animations; keep the FAQs and the waitlist CTA. Use characters and backgrounds from Illustrations (Copy) `dPirB4bC1bB7KcxaacOVHG` and the website designs ("Final version" `8:2214`; App (Copy) page "Tablet and Iphone website" `8:690`). Any animation tech. |
| 59 | Website repo | New repo `kizuki_web` at `/Users/edisonabdiel/Projects/kizuki_web` (local first; GitHub remote created only with user OK). |
| 60 | Waitlist storage | Production Supabase `enosggckdxjiaqtxalhg`, one isolated `waitlist` table, insert-only RLS. First deliberate production write; apply the migration only after showing it to the user. |
| 61 | Website hosting | Vercel. |
| 62 | Remove from Crew cooldown | 30 days before the removed person can send a new request; old chat stays readable. |
| 63 | Search video length | Max 15 s, 720p, 15 MB. |
| 64 | Search video playback | Autoplay muted in the grid; tap for sound. |
| 65 | Website domain / repo | https://kizuki.club; GitHub `edi-kizuki/kizuki_web` (public). |
