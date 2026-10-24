# Project instructions

## Local workspace

The existing project root is `/Users/edisonabdiel/Projects/kizuki_iOS`.
Run project commands and write project files in this directory. Set the working directory explicitly when the thread starts in a T3 scratch folder.
Verify the Git origin is `https://github.com/edi-kizuki/kizuki_iOS.git` before repository operations.
The user confirmed `kizuki_iOS` as the folder name. Keep this path; do not rename it to `kixuki_iOS`.

Read [[playbook]] at `docs/playbook.md` before work.
Read [[00-what-exists]] at `docs/context/00-what-exists.md` for verified context and source access.
Related: [[CLAUDE]].

- Keep responses concise. Link every new Markdown note to related notes with `[[wikilinks]]`.
- Native iOS and Supabase project `enosggckdxjiaqtxalhg` are user decisions.
- Purse examples in the playbook are not Kizuki requirements.
- Complete source intake before proposing implementation or architecture. Label unknowns and access failures explicitly.

Read [[2026-10-24-ios-build-readiness]] at `docs/2026-10-24-ios-build-readiness.md` for verified tooling and remaining prerequisites. XcodeBuildMCP is registered for both Codex and Claude. Use XcodeGen (`project.yml`) for project generation.

## Development direction confirmed by the user

- Build a production-quality foundation from the first prototype: architecture, specifications, meaningful tests, and real Supabase integration. Fixtures support tests/previews; a fixture-only app is not the deliverable.
- Figma Kizuki App is general visual guidance. Current Notion requirements guide behavior and adjustments. UI can iterate; separate artwork exports are not a kickoff blocker.
- Use Blobatar (https://blobatar.dev/) for profile pictures after verifying its API, license, and supported image formats.
- Use distinct coding and testing/review agents for each PR. Select models and effort per task; rotate roles across tasks where useful. Never have the author independently approve its own change.
- Raise important product/design decisions; do not invent requirements.
- Supabase project: `enosggckdxjiaqtxalhg`; owner supplied by user: `edison@kizuki.club`. Environment role remains to be confirmed before remote migrations.
