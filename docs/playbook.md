---
title: "iOS build playbook for Edison (how Purse was built)"
type: note
created: 2026-10-24
updated: 2026-10-24
tags: [topic/ios, topic/process, topic/ai-design, domain/personal]
---

# From idea to a native iOS app on your phone: the playbook

Edison, this is the way of working behind Purse, the family finance app I showed you, rewritten so you
can run it on your own app. It took Purse from a loose idea to a native SwiftUI app on two phones via
TestFlight in about a week, with Claude doing most of the building and me making the decisions.

There are four pieces: a **map** of decisions (Wayfinder), an **architecture round** where Opus
researches overnight and draws the system with Archify, a **design round** where you pick the look on
purpose, and a **project hub**, a styled website where every round lands as cards so you can always
find everything in one place.

The one idea underneath it: **your attention is the bottleneck, not build capacity.** Agents can build
fast. What they can't do is decide what to build or what good looks like. So the process front-loads
decisions (a map of questions, grilling sessions, a taste intake), freezes them, and only then lets
agents build in parallel.

Drop this file into your repo as `docs/playbook.md` and point your `CLAUDE.md` at it.

---

## 1. One-time setup (about 30 minutes)

### Plugins and skills

Run these in Claude Code (inside T3 Code or a terminal). Each is a marketplace add, then an install.

```sh
# Matt Pocock's skills: wayfinder, grilling, to-spec, to-tickets, prototype, tdd, handoff…
claude plugin marketplace add mattpocock/skills
claude plugin install mattpocock-skills@mattpocock

# ~90 iOS skills: SwiftUI patterns, navigation, Liquid Glass, SwiftData, StoreKit,
# Swift concurrency, Swift Testing, simulator, App Store review, accessibility…
claude plugin marketplace add dpearson2699/swift-ios-skills
claude plugin install all-ios-skills@swift-ios-skills

# Compound engineering: plan → work → review loop, a Swift/iOS code reviewer, and
# ce-compound, which saves what you learned into the repo so the next session knows it
claude plugin marketplace add EveryInc/compound-engineering-plugin
claude plugin install compound-engineering@compound-engineering-plugin

# From Anthropic's official marketplace (already registered)
claude plugin install swift-lsp@claude-plugins-official        # Swift code intelligence
claude plugin install frontend-design@claude-plugins-official  # landing page / web design taste
claude plugin install code-review@claude-plugins-official
claude plugin install pr-review-toolkit@claude-plugins-official
```

Restart the session after installing so the skills load.

### MCP servers

```sh
# XcodeBuildMCP: lets the agent build, run, test, screenshot and debug in the Simulator
# Needs macOS 14.5+, Xcode 16+. (brew install is the alternative if you don't want Node.)
claude mcp add XcodeBuildMCP -- npx -y xcodebuildmcp@latest mcp

# Inspo: real production websites as design references (free, no key). Best for landing pages.
claude mcp add --transport http inspo https://inspomcp.dev/api/mcp

# Optional, for design references:
#   Mobbin MCP (paid): real app screens and flows. Best source for iOS screen references.
#   Palate (free tier, palatemcp.com/docs): site tokens + an "anti-slop" lint.
```

Also: `brew install xcodegen`. I generate the Xcode project from a `project.yml` so agents never
hand-edit `.pbxproj` files, which is where parallel agents otherwise collide.

### Diagram skills (for the architecture side)

```sh
# Archify: turns a description (or the real repo) into an interactive architecture, workflow,
# sequence, data-flow or state-machine diagram as one self-contained HTML page, light/dark,
# exportable to PNG/SVG. Validates its own layout. Needs Node 18+.
npx skills add tt-a1i/archify

# Mermaid with live preview: quick sketches mid-conversation before something earns an Archify page
claude plugin marketplace add veelenga/claude-mermaid
claude plugin install claude-mermaid@claude-mermaid
```

Archify is what you'll read the architecture through. Every concept round ends with a set of Archify
pages (system overview, main user flow, state machines, data model, build roadmap), so you review the
technical side as pictures you can click through, not as 900 lines of prose.

### One command in your repo

```sh
/setup-matt-pocock-skills
```

It asks where your issues live. **Pick local markdown** (one file per ticket in the repo) unless you
want agents reading Linear or GitHub Issues. Markdown in git is the simplest and every agent can read it.

---

## 2. Get your existing context in first (your step zero)

You already have designs and notes, so don't start from a blank page. Do this before any planning.

1. **Collect everything into the repo**, raw: `docs/context/` for notes, specs and docs (export Notion
   or Google Docs to markdown); `docs/design/` for design exports as PNGs (Figma frames, screenshots,
   sketches). Agents read images fine. Name files so they sort: `2026-10-24-onboarding-v2.png`.
2. **Run an intake session.** Paste this:

   > Read everything in docs/context and docs/design. Write docs/context/00-what-exists.md: what the app
   > is, who it's for, the screens and flows that already exist in the designs, decisions that already
   > look made, and contradictions between sources. End with a list of open questions. Don't propose
   > solutions yet.

3. **Grill it.** Run `/grill-with-docs` on that file. It interviews you one question at a time and writes
   a `GLOSSARY.md` (your domain words, used consistently by every later agent) and ADRs for the
   decisions you lock. This is where your head becomes something agents can read.

Now you have a written starting point, and the map in step 4 starts from there.

---

## 3. The project hub: one styled site where every round lands

This is the piece that makes the whole thing livable. Purse and the software factory each have one: a
small password-protected website (purse.roadtriplabs.com, factory.roadtriplabs.com) that is the home
base for the project. Every round of work (research, concept, review, diagrams, prototypes, decisions)
adds cards to it. I never go looking for a file; I open the hub.

**What the home page shows, top to bottom:**

1. **Needs your answer**: the open decisions, each linking to a decision page with lettered options and
   the agent's recommendation. This is the first thing you see, and it's how you work through grilling
   from your phone.
2. **The latest round, "start here"**: the morning brief plus that round's cards.
3. **Earlier rounds**, newest first, each a block of cards.
4. **Standing sections**: Design (systems compared side by side, landing styles), Prototypes, Diagrams
   (the Archify pages), Research, the Wayfinder map, and a **walkthrough page**.

**The walkthrough page** is the one I actually read. It's a single illustrated page that walks through
the whole concept in chapters, with the Archify diagrams and prototype screens embedded, a **decisions
ledger** (every decision, its status, which ones need you now) and a **numbers that matter** strip.
It gets rebuilt after every concept version.

There's no template to copy. Your agent builds the hub from the spec below, so it fits your repo and
your stack. To start it, say: **"Read docs/playbook.md section 3 and build the hub."**

### Hub build spec (for the agent)

Build it in one session, in this order. Stop and ask only if something in the repo contradicts the
spec.

1. **Location.** Everything under `hub/` in the repo. `hub/index.html` is the home page. Agents write
   markdown and HTML into `hub/` subfolders (`research/`, `concept/`, `reviews/`, `diagrams/`,
   `prototypes/`, `design/`, `decide/`, `rounds/`); the hub picks them up.
2. **Server.** A small bun server, `hub/serve.ts`, that serves the folder and renders any `.md` file
   as styled HTML (headings, tables, code, links, and frontmatter hidden). Pick a free local port and
   print the URL.
3. **Cards.** Each card has a title, date, type (research / concept / review / diagram / prototype /
   decision / brief), a one-line summary, a status (needs you / to read / decided) and a link. Keep
   the card data in one place the agent edits (e.g. `hub/cards.json`, or frontmatter read at build time).
4. **Home page order:** "Needs your answer" → "Latest round: start here" (the morning brief and that
   round's cards) → earlier rounds, newest first → Design, Prototypes, Diagrams, Research, Map.
5. **Decision pages** (`hub/decide/`): one per open decision. The question in plain language, lettered
   options, the recommendation and one or two lines of why. Link each from "Needs your answer". When I
   answer, mark it decided and record the answer on the page.
6. **Walkthrough page** (`hub/walkthrough.html`): chapters through the current concept, with the Archify
   diagrams and prototype screenshots embedded, a decisions ledger table (decision, status, needs me
   now?) and a "numbers that matter" strip. Rebuild it after every concept version.
7. **Style.** Clean and neutral for now: one accent on a neutral surface, readable on a phone, light
   and dark. When design tokens are locked, the hub switches to them.
8. **Seed it** with `docs/context/00-what-exists.md` as the first card, its open questions as decision
   pages, and the Wayfinder map once it exists.
9. **Deploy.** Static on Vercel behind a password: a Basic-auth middleware reading a `SITE_PASSWORD`
   env var that **fails closed** if the variable is unset, and an `X-Robots-Tag: noindex` header on
   every response. Keep the password out of git. After every deploy, check the **served** site:
   401 without the password, 200 with it. A green deploy log is not proof.
10. **Standing rule.** Add this to `CLAUDE.md`: *"Every round of work ends by adding its cards to the
    hub, moving decisions into or out of 'Needs your answer', rebuilding the walkthrough if the concept
    changed, and checking the rendered page in a browser."*

Done when: the hub serves locally, the home page shows the seeded cards and decision pages, the
deployed URL passes the 401/200 check, and the `CLAUDE.md` rule is in place.

---

## 4. The map: Wayfinder

`/wayfinder` is the core of the process. It turns "build my app" (too big and foggy for one session)
into a **map of decision tickets**:

- **Destination**: one or two lines naming what done looks like. Mine for Purse was "the whole v0 working
  end to end on real data, native iOS on both our phones via TestFlight, by Sunday 11 Oct." Make yours
  concrete and dated. Ambitious is fine; I said a one- or two-week slip was acceptable.
- **Tickets** are questions, not build tasks. Four types:
  - **grilling**: a conversation with you (the default). "Who sees what in a shared household?"
  - **research**: the agent goes and reads docs or APIs alone. "Which bank API covers German N26 accounts?"
  - **prototype**: build something rough to react to. "What should the home screen show first?"
  - **task**: manual work that unblocks a decision (sign up for a service, create the App Store record).
- **Blocked by** lines between tickets. The **frontier** is whatever's open and unblocked. Every
  session picks the next frontier ticket, resolves it, and adds a one-line gist to the map's
  "Decisions so far".
- **Not yet specified** holds the fog you can't ticket yet; **Out of scope** holds what you've ruled out.

By default Wayfinder only plans. I overrode that for Purse with a note on the map: *"This map carries
execution."* Once the decision tickets were done, build tickets graduated onto the same map. One file
showed what's decided, what's being built and what's blocked. I'd recommend the same for you.

Other Pocock skills you'll use along the way: `/grilling` (stress-test a plan), `/prototype`,
`/to-spec` (turn a conversation into a spec), `/to-tickets` (split a spec into tracer-bullet tickets
with blocking edges), `/tdd`, `/handoff` (compress a session so a fresh one can pick it up).

---

## 5. The architecture round: Opus researches overnight, you review in the morning

This is how the technical side gets decided without you reading code. One long session, usually
overnight: Opus orchestrates research lanes, an architect writes the concept, a fresh agent tears it
apart, the architect revises, and Archify draws it. You wake up to a walkthrough page and a morning
brief on the hub, and you give feedback on the architecture by looking at diagrams.

What Purse's first overnight round produced: four research lanes (needs, agent architecture, ledger and
bank feed, hosting and security), a concept with 25 decisions, an independent review that found 4
blockers and said the plan was about 3x too big, a v2 that fixed 51 of 60 findings, 9 Archify diagrams,
an iOS and a web prototype, and the walkthrough page. Round 2 the next night did the design systems,
a UX review, concept v3 and the real SwiftUI prototype.

| Stage | Who | Output (all into the hub) |
|---|---|---|
| Research lanes, one per open question (users and needs, existing products and build-vs-buy, technical approach, data/APIs, hosting/security/privacy, cost) | Sonnet, one agent per lane | One dated research note per lane |
| Architecture concept: how it works end to end, data model, v1 vs later, risks, open decisions, phased build plan, **diagram specs**, screen list (no look) | Opus (the architect) | Concept doc + diagram specs |
| Independent review: blockers / major / minor, by section | A fresh Opus that didn't write it | Review doc |
| v2 + change log: what each finding became (fixed / partly / rejected, why) | The architect | Concept v2 |
| Verification of v2 against the review | Another fresh agent | Verification note |
| Archify diagrams: system overview, main user flow, key state machines, data model, build roadmap | Sonnet, **one agent per diagram** | `hub/diagrams/*.html` |
| Walkthrough page, morning brief, hub cards, decisions into "Needs your answer" | Opus | The page you read first |

**Paste-ready prompt** (adapt the last line). This is the one I gave Max for his own ideas, extended
for an existing project and the hub:

```text
I want to take this project through a deep architecture round, the kind where I come out the other
end with research, an architecture concept, diagrams I can click through, a prototype and an honest
review of what's weak. Start from what's already here: docs/context/, GLOSSARY.md, the ADRs and the
Wayfinder map. Work in three phases and don't skip ahead.

PHASE 1 — INTERVIEW ME (no research, no writing yet)
Ask questions until you understand what's still open. Small batches of 3–5, each with lettered
options plus "other", your recommended answer and one line on why. Plain language. Push back on vague
or contradictory answers and name the contradiction. Keep a running "what I know so far" summary at
the top of each turn. Stop when I agree your summary is right, then show me the plan for Phases 2–3
and wait for my go.

PHASE 2 — RESEARCH (I'll likely be asleep; run unattended)
- Split the open questions into research lanes, one subagent per lane, at most 3 agents at once.
  Sonnet for research lanes. One dated research note per lane in hub/research/.
- Primary sources. Label vendor claims as vendor claims on the line where they appear. Every number
  that drives a decision carries its source.
- End with a one-page recommendation: what to build, what to buy or reuse, what to skip.

PHASE 3 — CONCEPT, REVIEW, DIAGRAMS
1. Architecture concept (you, Opus): problem, users, the recommended design, how it works end to end,
   data model, v1 vs later, risks, open decisions, phased build plan, plus a spec for each diagram.
   Do not choose colours or fonts; that comes later in a separate design round.
2. Independent review: a fresh agent that did NOT write the concept, given the concept but not your
   reasoning, lists problems by severity (blocker / major / minor) with the section each hits.
3. Concept v2 plus a change log of what each review item became (fixed / partly fixed / rejected, why).
   Then a second fresh agent verifies v2 against the review.
4. Diagrams with the archify skill, one subagent per diagram, one HTML page each: system overview, main
   user flow, key state machines, data model, build roadmap. Validate each with archify's validator.
5. A clickable prototype of the hero screens with realistic invented data (SwiftUI if it's the app).
6. Add everything to the hub as cards under a new round. Build or update the walkthrough page:
   chapters with the diagrams and screens embedded, a decisions ledger, numbers that matter. Put every
   decision I need to make into "Needs your answer" with your recommendation. Write a morning brief
   as the round's "start here" card.

Rules:
- Name files YYYY-MM-DD-<topic>-<what-it-is>.md, lowercase.
- Every agent writes its file incrementally, after the first section, so a cut-off loses little.
  Tell each agent: "Your file is the report; your final chat message may never reach me."
- Look at every rendered page yourself in a browser before calling it done.
- If a usage limit hits, start a background sleep until just past the reset time so you wake up and
  continue. Don't stop for the night.
- Lead with one confident recommendation, not a menu. Flag what you're least sure of.

The project, in a sentence or two, and what this round should settle: <describe it here>
```

How to give feedback on the technical side: open the walkthrough page and the diagrams, then write
your reactions as plain notes (voice dictation is fine) into a `round-N-feedback.md`. The next round
starts from that file, and **your feedback wins over the concept**. On Purse, each round's feedback
file was the first thing the next round's agents read.

---

## 6. Design: decide the look on purpose

The biggest lesson from Purse: **I let an agent pick the look by default, inside a behaviour spec, and
the first version came out generic.** Don't skip these stages:

| # | Stage | What you get | Rule |
|---|---|---|---|
| 1 | **Structure** | Screen list, navigation, your 2–3 hero flows. Grey boxes. | No colour, no fonts yet |
| 2 | **Taste intake** (15–20 min, live) | 3 apps you love in this category, 3 you dislike, a one-word "soul", a banned list ("no pill buttons", "no purple gradients") | Before **any** visual generation |
| 3 | **References** | Mobbin screens per hero screen; you cut it down | The agent sorts, you cut. Taste stays yours |
| 4 | **Design systems side by side** | 5–7 candidate systems, each rendering **the same real components** of your app in light and dark, on one comparison page | If they look alike, rebuild them to differ on named axes: light or dark first, tint, one accent or two, density, glass or flat |
| 5 | **Lock it** | One `tokens.json` that generates both `Theme.swift` and CSS, with the same role names (canvas, card, ink, accent…) | Frozen. No more system shopping after this |
| 6 | **Landing page styles** | One fixed copy file, then the same landing page rendered in 5–10 styles (use Inspo/Palate for references), picked side by side | Keep copy lean; one accent colour on a neutral surface |

Purse ended up on a periwinkle-and-teal look ("Mercury-soft") with a glassier variant as a theme switch.
Because the token role names match, switching themes is a one-file change.

Two practical tips:
- **Native means SwiftUI.** My first screens felt like a web app on a phone. Build the prototype in
  SwiftUI from the start (the iOS skills help a lot here: `swiftui-patterns`, `swiftui-navigation`,
  `swiftui-liquid-glass`, `swiftui-animation`).
- **Review rendered pixels, never source.** Every design check happens on screenshots, by an agent
  that didn't make the design, and then by you.

---

## 7. Clickable prototype → real app

**Prototype first, with fake data.** A SwiftUI app with a `Fixture.swift` of invented data and no
backend. Add a **launch-argument router** so any screen opens directly:

```sh
xcrun simctl launch booted com.you.app -screen home -theme dark
```

Then a small script loops over every screen id and screenshots it. That gives you (and the reviewer
agents) a gallery of every screen in seconds, and it's how I reviewed 60+ screens from my phone.
XcodeBuildMCP can do the build/launch/screenshot part for the agent directly.

**Then the real build, in waves:**

- **Wave 0, contracts.** Before anyone builds in parallel, freeze the interfaces: data models, API shapes,
  the protocol the iOS app talks to (I used a `PurseAPI` protocol with a `FixtureAPI` and a `LiveAPI`
  implementation). Plus one shared set of invented fixtures. An independent agent checks the contracts
  before anything starts.
- **Wave 1+, parallel lanes.** One lane per area with **no overlapping files** (iOS, backend, web…).
  Each lane gets its own git worktree (in T3: launch the thread with a worktree, or `delegate_task` with
  `isolation: "worktree"`). The orchestrator merges each lane and re-runs all tests on `main`.
- **Grow the real app from the prototype**, don't start the iOS code over.
- **TestFlight early.** A script that archives and uploads. Getting it onto your own phone changes what
  you notice.

---

## 8. Orchestration: how to run long sessions

- **Opus 5.5 orchestrates** at effort `high`. It owns the map, writes the briefs, merges, and checks
  results. It doesn't build.
- **Sonnet 5.5 builds** the lanes: `medium` for well-specified tickets, `high` for contracts and tricky
  logic. If a lane fails twice, escalate it to Opus.
- **Haiku 5.5** only for mechanical, checkable jobs: build and test runs, renames, boilerplate from a precise spec.
- **Max 3 agents at once.** About 8 at once hit the usage limit twice in an hour for me and lost an
  overnight run.
- **The agent that built something never verifies it.** A fresh agent checks it, and it gets the claims
  and the files, not the builder's reasoning.

**Every lane brief includes:**

1. One deliverable. Four questions means four agents. Big briefs are the ones that go silent without reporting.
2. Exact scope, with the files it may touch and named anti-patterns (agents add unrequested tests and files).
3. "Write your report to `docs/lanes/YYYY-MM-DD-<lane>-report.md` incrementally, after the first item.
   **The file is the report**; your chat reply may never arrive." This one saved a lot of work when sessions hit limits.
4. "Do the work yourself, don't spawn subagents."
5. Clean-up: delete screenshots and temp files, stop your own dev servers by PID, remove merged worktrees.
6. For audio/video features: launch the simulator muted.

**Overnight runs:** hand Opus the map plus "work the frontier, max 3 lanes, merge what passes, leave a
morning summary in `docs/`". Read the summary and the merged screenshots in the morning, then answer the
grilling tickets it parked for you. That's the daily loop.

**Compound at the end of each session** with `/ce-compound`: lessons go into `docs/solutions/` in the
repo, and the next session reads them before starting.

---

## 9. Your first sessions

1. **Setup + intake + hub** (sections 1–3): plugins, MCPs, Archify, `/setup-matt-pocock-skills`,
   collect context, intake file, `/grill-with-docs`, then build the hub and seed it.
2. **Map**: `/wayfinder` with your dated destination. Grill the first few frontier tickets with it.
3. **Architecture round** (section 5): kick it off in the evening, read the walkthrough and diagrams
   in the morning, write your feedback file.
4. **Taste intake + structure**: before any new visuals, then the side-by-side design systems page.

After that the map tells you what's next.

---

## Things that bit me

- Agents decide the look if you let them. Taste intake comes first.
- "Done" from an agent means nothing until you've seen it rendered. Check the screenshot yourself.
- A ticket that says something is outstanding is a snapshot. Check git log before redoing work.
- Long briefs + many parallel agents = silent agents and lost work. Small briefs, max 3, report files.
- Keep real personal data out of the repo; agents and cloud runners build against invented fixtures.
