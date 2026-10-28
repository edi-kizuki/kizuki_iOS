# Kizuki iOS

Native iOS app for Kizuki. SwiftUI, iOS 17+, Supabase backend.

## Requirements

- Xcode 26 and an iOS simulator
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)
- Supabase CLI and a Docker engine (for the local backend)

## Setup

```sh
./scripts/generate-project.sh      # generate the Xcode project from project.yml
./scripts/supabase-local.sh start  # local Supabase stack
./scripts/check-ios.sh             # build and run the test suite
```

## Layout

- `ios/App` – app target and entry point
- `ios/Packages/KizukiKit` – feature and core modules (Swift packages)
- `ios/Tests`, `ios/UITests` – unit and UI tests
- `supabase/` – migrations, pgTAP tests, local config
- `scripts/` – build, release and backend checks used by CI

## Environments

Local and staging only. Release builds refuse the production backend.

## Contribution and agent workflow

Future assisted commits use Edison Abdiel's GitHub identity, [@edisonabdiel](https://github.com/edisonabdiel):

```sh
git config --local user.name "Edison Abdiel"
git config --local user.email "43752457+edisonabdiel@users.noreply.github.com"
```

This changes future commit attribution, not historical commits, repository ownership, or the authenticated account used to push. GitHub has no configurable “main contributor” rank. The repository remains owned by `edi-kizuki`; the existing write-access invitation must be accepted by `edisonabdiel`.

Astra and Fable 5.1 alternate implementation and independent QA. One authors each substantive change; the other challenges its assumptions, reviews the actual diff, and validates relevant behavior. After the change clears QA, they swap roles for the next change. The author fixes findings; the other model re-checks the final code revision. Neither self-approves. Follow [[AGENTS]] for review evidence, quality criteria and escalation rules.

Initial assignment, October 28, 2026:

| Scope | Coding | Independent review / QA |
| --- | --- | --- |
| Existing PR #8 | Astra | Fable 5.1, pending |
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
