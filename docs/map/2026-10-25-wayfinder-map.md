---
title: Kizuki v0 — Wayfinder map
labels: [wayfinder:map]
created: 2026-10-25
updated: 2026-10-25
---

# Kizuki v0 — Wayfinder map

Related: [[playbook]], [[2026-10-24-architecture-round-1-interview]], [[00-what-exists]], [[2026-10-25-figma-full-walkthrough]].

## Destination

Core loop v0 working end to end on mock data, native iOS on TestFlight: sign in (Apple or email) → onboarding (incl. taste cards) → Home feed → request → accept → chat, plus Search, Suki, My Projects and Profile. No target date; ship when it works.

## Notes

- **This map carries execution.** Once decision tickets close, build tickets graduate onto this map.
- Tracker: local markdown. Tickets live in `docs/map/tickets/NNN-<slug>.md`; frontmatter `labels`, `status` (open/closed), `blocked_by` (ticket ids), `assignee` (the claim).
- Frontier = open, unclaimed tickets whose `blocked_by` are all closed.
- Process: [[playbook]] sections 5 and 8, including the four add-on rules (cross-model Codex review for risky changes, named model + effort per agent, max two review rounds).
- Locked decisions live in [[2026-10-24-architecture-round-1-interview]]; user answers override Notion and Figma.

## Decisions so far

- [Phase 1 interview](../context/2026-10-24-architecture-round-1-interview.md): 28 decisions — 5 tabs (Home, Search, Suki, My Projects, Profile), request → accept → chat, no payments/follows/comments, Apple + email, permissions up front, taste cards with placeholders, favourites picker, profile embeds, mock data only.
- [[001-supabase-backend-research]]: ~35 tables with RLS, SQL `recommend` with reason codes, Postgres Changes chat, Apple + email auth, delete-account Edge Function, seed generator. Report: [[2026-10-25-supabase-backend-research]].
- [[002-ios-client-integrations-research]]: modules per tab, system TabView, Continue-only permission primers, YouTube/SoundCloud/Bandcamp embeds, TMDB proxy, privacy manifest needed. Report: [[2026-10-25-ios-client-integrations-research]].
- Research follow-ups (#29–36): staging Supabase project, email+password, organization Apple account, APNs push, owner invites, daily dashboard moderation.
- [[010-architecture-concept]] (closed): native SwiftUI app grown from the in-app prototype; all user-protecting rules in Postgres (RLS, definer RPCs with one lock order, pgTAP + race + live tests); three Edge Functions (delete-account, send-push, tmdb-proxy); SQL `recommend` (Notion v1 weights, privacy-safe reasons, cold start); Crew connections with generations and Remove from Crew; chat as Realtime envelopes + separately fetched bodies; staging `ankgfqkgflcalmlreetu` pinned, production refused in v0; 21 build slices, each provable from an empty DB plus a live Swift run for the core loop. Docs: [[2026-10-25-architecture-concept-v2]] + [[2026-10-25-architecture-concept-v2.1]], [[2026-10-25-concept-v2-changelog]].
- Decisions #37–57: canonical Figma copies, staging project, Apple enrolment deferred, Crew naming, public city and availability, D42/D49 retention, one app `club.kizuki.ios`, Wish to Collab / Join project, accept opens chat, Remove from Crew, media-only Search, Kizuki tab icons, Get discovered placement.

## Frontier (2026-10-25, after concept v2.1)

Build (B01–B21, label `wayfinder:build`): only [[012-b01-live-composition-seam]] is unblocked. Next to unblock: [[013-b02-backend-backbone]] (after 034), [[014-b03-environment-pinning]] (after 037).

Follow-ups (VF04–VF13, label `wayfinder:followup`), all unblocked and gating build slices:
- [[033-vf04-concurrency-readiness]] → gates 017, 018, 021, 028
- [[034-vf05-reports-visibility]] → gates 013, 021
- [[035-vf06-push-per-device]] → gates 029
- [[036-vf07-deletion-races]] → gates 028
- [[037-vf08-env-bootstrap]] → gates 014
- [[038-vf09-live-proof-pipeline]] → gates 015
- [[039-vf10-chat-reconciliation-matching-edges]] → gates 019, 025
- [[040-vf11-public-availability-reasons]] → gates 020, 024
- [[041-vf12-prototype-decisions]] → gates 018, 023, 024
- [[042-vf13-settled-decisions-release-gates]] → gates 028, 031, 032

Still open from earlier: [[005-container-runtime]] (Docker engine 29.8.2 responds; closes when B02 starts the local stack), [[007-taste-facets]], [[008-matching-weights]] (Notion v1 weights accepted as OD-1 default), [[009-suki-myprojects-prototype]] (prototype built, see [[2026-10-25-prototype-report]]), [[011-dont-stop-early-block]]. [[006-apple-developer]] is deferred (D39) and blocks 030 and 032.

Critical path: 012/013/014 → 015 → 016 → 017 → 018 → (019 ∥ 020) → 021 → 022 → 028 → 031 → 032.

## Not yet specified

- Design-token lock (needs Figma access, ticket 003) and the design round (playbook section 6).
- Hub deploy to Vercel behind a password.
- Moderation workflow for reports beyond dashboard review.

## Out of scope

- Payments, events, follows, comments, Made Together, Google sign-in, appeals tooling.
- Spotify and Letterboxd data import (API terms block recommendation use).
- Real user data and production Supabase writes.
