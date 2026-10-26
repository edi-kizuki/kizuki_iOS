---
title: Hub build report
created: 2026-10-25
tags: [project/kizuki, hub, lane-report]
---

# Hub build report

Related: [[playbook]], [[2026-10-24-architecture-round-1-interview]], [[00-what-exists]]

Status: in progress. Written incrementally.

- Spec read: `docs/playbook.md` section 3 "Hub build spec" (steps 1-10) plus orchestration add-on item 3.
- `bun --version` = 1.3.13 (present). Node v24.7.0. No global tools installed.
- Bun has built-in `Bun.markdown`, so the hub has zero npm dependencies.

## Result: built, verified locally, not deployed

### Start

```
cd /Users/edisonabdiel/Projects/kizuki_iOS && bun hub/serve.ts
```

Prints the URL and PID. Default `http://127.0.0.1:4747/` (falls back to 4748-4750, then any free port; `PORT=` pins one). Binds to 127.0.0.1 only. Rebuilds the walkthrough on start; run `bun hub/build.ts` to rebuild without the server.

### Files created (all under `hub/`, plus report and two edits)

- `serve.ts`: Bun server. Serves `hub/` and renders any `.md` (frontmatter hidden, tables, code, `[[wikilinks]]` resolved to repo files, `?raw` for source). Serves repo `docs/` read-only at `/docs/` (one source of truth, nothing copied) and `AGENTS.md`/`CLAUDE.md` at `/repo/`. GET/HEAD only, traversal and dotfiles blocked, `serve.ts`/`build.ts`/`lib.ts`/`templates/` not served, `X-Robots-Tag: noindex` on every response.
- `lib.ts`, `build.ts`, `templates/walkthrough.template.html`: shared helpers; walkthrough generator (ledger parsed from the interview file).
- `index.html`: home page, built client-side from `cards.json`. Order: Needs your answer, Latest round (start here), Earlier rounds, then Design, Prototypes, Diagrams, Research, Map, Walkthrough.
- `cards.json`: the one place to edit card data (title, date, type, summary, status, href, round, section).
- `walkthrough.html`: generated. Chapters Research, Concept, Review, Diagrams, Prototype as placeholders; ledger with all 28 interview decisions marked decided (superseded rows flagged: #5 and #6 by #19, #14 by #21; #17 and #27 noted as user-side actions still pending) plus 4 open rows at the top; numbers strip.
- `decide/figma-access.html`, `decide/illustration-assets.html`, `decide/hub-deploy.html`, `decide/overnight-block.html`: lettered options, recommendation, answer box (open).
- `assets/hub.css`: neutral surface, one accent (#E95833), light and dark, phone-readable (ledger collapses to stacked cards under 640px).
- Empty subfolders with `.gitkeep`: `research/ concept/ reviews/ diagrams/ prototypes/ design/ rounds/`.
- Edited: `CLAUDE.md` and `AGENTS.md` (appended a `## Hub` section with start command and the standing rule; nothing else changed).

### Cards seeded

Needs you: 4 decision pages. Round "Architecture round 1": walkthrough, interview (decided), Figma walkthrough (also under Design), intake `00-what-exists`, Wayfinder map (`docs/map/2026-10-25-wayfinder-map.md`, seeded because it now exists), Supabase research (`docs/research/...`, draft). Round "iOS foundation" (earlier): foundation acceptance review, foundation coding report.

### Numbers strip

Sourced: 28 decisions (computed), 4 open (computed), 5 tabs (#19), 6 Figma pages and 111 phone-sized frames (Figma walkthrough), 10 illustration rasters (illustrations README). TBD: tests passing (coding report says verification pending), TestFlight date, screens built.

### Verification

- `bun --version` 1.3.13. No global tools installed. No npm dependencies (`Bun.markdown` is built in).
- Server started, PID 29669 (earlier run 29020). curl results: `/` 200; `/cards.json` 200; `/walkthrough.html` 200 (28 decided badges in the HTML); `/decide/figma-access.html` 200; `/docs/context/2026-10-24-architecture-round-1-interview.md` 200, rendered HTML with title, no frontmatter shown; `/docs/map/...wayfinder-map.md` 200; `/docs/.../home-feed-recommended.png` 200 image/png; `/repo/CLAUDE.md` 200; `/serve.ts` 404; `/docs/%2e%2e/CLAUDE.md` 404; POST 405; `X-Robots-Tag: noindex, nofollow` present.
- Playwright screenshots: home at 1100px wide (all sections render, 4 needs-you cards, rounds, standing sections) and walkthrough ledger at 390px wide (stacked rows, open items highlighted). One console error (favicon 404) found and fixed with a 204 route. Dark mode not checked visually.
- Server stopped by PID; post-stop request failed to connect, as expected.

### Not done / notes

- Step 9 (Vercel deploy): skipped as instructed. Pending user approval; see `hub/decide/hub-deploy.html`. When done it also needs a static build of the `.md` pages, since `serve.ts` renders them on request.
- Source doc quirk, not changed (outside my scope): the interview file's decision tables for rows 11 onward are not valid markdown tables (blank line, no header), so the rendered interview page shows those rows as plain text with pipes. The walkthrough ledger renders all 28 correctly. Fix by removing the blank lines or repeating the header row in the source.
- `CLAUDE.md` lines 11-13 still say the hub "does not exist at intake start". Left as is per "don't rewrite other content"; the new `## Hub` section supersedes it.
- Wayfinder map link: the map page itself was only checked to render (200, no unresolved wikilinks).
- Nothing committed. No changes to `ios/`, `supabase/`, `scripts/`, `project.yml`, `docs/reviews/*`, `docs/playbook.md`.
