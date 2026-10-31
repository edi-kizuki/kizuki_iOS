# Engineering workflow

Related: [[README]], [[Header appearance experiment]].

## Alternating implementation and independent QA

- Use GPT-6 Astra and Claude Fable 5.1 as the engineering pair. Do not substitute another model without user approval.
- Assign one author and the other model as the independent reviewer for each substantive change. Alternate authors between accepted changes. Documentation-only edits and fixing review findings do not rotate ownership.
- Record author model, reviewer model, reviewed commit SHA, acceptance criteria, findings and actual validation in the PR or handoff. Consult the initial assignment in README until the first paired cycle completes.
- The author owns implementation and regression fixes. The reviewer independently examines the diff, surrounding code and tests, challenges assumptions, and attempts relevant failure cases. The author cannot approve their own change.
- Give reviewers the requirements, exact revision and known constraints, not just an author-written success summary. A shared-checkout reviewer must not edit files or drive a simulator concurrently with the author.
- Review findings need severity, file/line, a concrete failure or risk, and a proposed validation. Separate required fixes from preferences. Do not invent objections to prolong debate.
- Address findings, then request an independent re-check of the revised commit. Use a new review task for each re-check. After two unresolved rounds, present the disagreement and trade-offs to the user rather than looping or silently accepting a blocker.
- Do not label work reviewed or ready to merge until independent QA is complete, blocking findings are resolved, and required checks pass for the final code revision. Missing tools, unavailable models, empty agent results and unrun tests must be reported as pending or blocked, never as success. Never merge without user authorization.

## Quality criteria

- Prefer small, focused changes and existing conventions. Remove unnecessary complexity without speculative abstractions or unrelated rewrites.
- Keep product/domain logic separate from external providers and agent tooling. Use existing interfaces; isolate new integrations at boundaries when needed. Do not add model-specific dependencies to application behavior.
- Cover relevant success and failure paths with regression tests. Check authorization, input validation, error handling, persistence/migrations, concurrency and recovery where affected.
- For UI changes, check accessibility, Dynamic Type, safe areas, interaction targets and representative simulator states. Report tested devices and sizes; screenshots alone are not full QA.
- Preserve privacy, consent, secrets handling, release guards and dependency/license obligations. Do not weaken tests or bypass CI to obtain a pass.
- Check performance, maintainability and diagnostics where relevant. Identify applicable standards explicitly when a task requires compliance; do not claim enterprise readiness or certification merely because two models agree.

## CI repair and attribution

- Cline is a bounded CI-repair specialist, not a replacement for the alternating pair. Its fixes require independent Astra or Fable review before being considered ready to merge.
- Preserve the existing automation safeguards. Never overwrite user work, force-push, silently change providers, or auto-merge.
- Attribute future assisted commits to Edison Abdiel <43752457+edisonabdiel@users.noreply.github.com>. Record model roles separately; do not rewrite historical attribution.
- New documentation files must include related Obsidian backlinks.
