# Kizuki iOS

Native iOS app for Kizuki. SwiftUI, iOS 17+, Supabase backend.

Related: [[DEVELOPMENT]], [[AGENTS]].

## Requirements

- A Mac with full Xcode 26.0.1 and an iOS simulator runtime. CI uses iPhone 17 Pro.
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) 2.46.0 or newer.
- [Homebrew](https://brew.sh) for the installation command below, or install XcodeGen manually.
- For the optional local backend: Docker, Node.js 24 with npm/npx, and Python 3.10 or newer. The wrapper downloads Supabase CLI 2.122.0; a global CLI installation is unnecessary.

## Open and run

Clone the repository using a GitHub account with repository access. Run these commands from its root:

```sh
brew install xcodegen
./scripts/generate-project.sh
open ios/Kizuki.xcodeproj
```

Select **Kizuki-Local**, choose an iPhone simulator, and press **Run**. Debug launches show the sample-data prototype by default. This needs no backend, credentials, Apple Developer team, or private configuration. The first build needs internet access to resolve pinned Swift packages.

For real local Supabase, follow [local backend setup](DEVELOPMENT.md#local-backend). That setup includes the required database reset/bootstrap and client configuration steps. [Development setup](DEVELOPMENT.md) also covers tools, tests, troubleshooting, signing, and staging access.

## Layout

- `ios/App` – app target and entry point
- `ios/Packages/KizukiKit` – feature and core modules (Swift packages)
- `ios/Tests`, `ios/UITests` – unit and UI tests
- `supabase/` – migrations, pgTAP tests, local config
- `scripts/` – build, release and backend checks used by CI

## Environments

Local and staging only. Release builds refuse the production backend.

## Contribution and agent workflow

October 28 development, validation and remaining delivery gates: [[Development wrap-up 2026-10-28]] (`ios/Development wrap-up 2026-10-28.md`).

Agent-assisted commits use Edison Abdiel's GitHub identity, [@edisonabdiel](https://github.com/edisonabdiel). Teammates should keep their own identity for their own commits. Agents use:

```sh
git config --local user.name "Edison Abdiel"
git config --local user.email "43752457+edisonabdiel@users.noreply.github.com"
```

This changes future commit attribution, not historical commits, repository ownership, or the authenticated account used to push. GitHub has no configurable “main contributor” rank. The repository remains owned by `edi-kizuki`; the existing write-access invitation must be accepted by `edisonabdiel`.

Astra and Fable 5.1 alternate implementation and independent QA. One authors each substantive change; the other challenges its assumptions, reviews the actual diff, and validates relevant behavior. After the change clears QA, they swap roles for the next change. The author fixes findings; the other model re-checks the final code revision. Neither self-approves. Follow [[AGENTS]] for review evidence, quality criteria and escalation rules.

Assignments, October 28, 2026:

| Scope | Coding | Independent review / QA |
| --- | --- | --- |
| PR #8 branding and flush profile at `528c53e` | Astra | Fable 5.1: no blocking findings; required CI not passed |
| PR #8 weekly availability, floating profile cards and favourites removal | Fable 5.1 | Astra: independent local checks complete; final SHA and CI recorded in PR |
| PR #8 photo editing and CI runner-capacity workaround at `17ffd19` | Astra | Fable 5.1: no blocking code findings; required CI pending |
| Next substantive change after that review | Fable 5.1 | Astra |

Record subsequent assignments and reviewed SHAs in PRs/handoffs. This is an agent operating policy, not a server-enforced GitHub approval gate. Required CI must also pass; two-model agreement is not certification of production readiness. Agents receive explicit briefs and exchange results through handoffs and repository files, not automatic shared conversation memory. Claude's connected Notion work remains separate. Do not silently substitute another provider or model.

A T3 scheduled task, **Kizuki: Cline repairs failed PR checks**, checks current open-PR heads every 15 minutes and delegates new failed checks to Cline. It is a local T3 automation, not a GitHub-hosted workflow; it requires the configured T3 runtime, GitHub authentication and Cline provider. Its ID is `scheduled-task:4084eea7-023d-4179-abe3-5d8c133fbec1`.

- Ignore superseded commits and checks that have not failed.
- Deduplicate attempts and allow one active repair at a time.
- Modify a shared checkout only when its branch matches the affected PR and the tree is clean; otherwise report the blocker.
- Preserve user changes, tests and release guards. No force-push, automatic merge, deployment or ownership changes.
- Attribute fix commits to `edisonabdiel`, validate them, and push only if the PR head still matches the inspected revision.
- Cline fixes still require independent Astra or Fable QA. A pushed fix is not automatically approved, and CI repair does not rotate the feature-author assignment.
- Report provider failures honestly. Two initial Cline runs returned no output; if that repeats, pause the automation rather than retry indefinitely or switch providers.

Scheduling is configured; end-to-end Cline repair is not yet verified. Related: [[Header appearance experiment]].
