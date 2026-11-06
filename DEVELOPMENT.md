# Development setup

Related: [[README]], [[AGENTS]], [[Development wrap-up 2026-10-28]].

## Tools

- macOS with full Xcode 26.0.1, the version used in CI. Command Line Tools alone cannot build the iOS app.
- XcodeGen 2.46.0 or newer: `brew install xcodegen`.
- [Homebrew](https://brew.sh) for the installation commands, or install the tools manually.
- An iOS simulator runtime installed in Xcode Settings → Components. CI uses iPhone 17 Pro / iOS 26.0.1. The app deployment target is iOS 17.
- GitHub repository access to clone and contribute.

Open Xcode once to accept its license and finish installing components. If the wrong developer directory is selected, run `sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer`, adjusting the path for your Xcode installation. Confirm with `xcodebuild -version` and `xcodegen --version`.

Local backend work also needs a running Docker engine, Node.js 24 with npm/npx, and Python 3.10 or newer. Docker Desktop or a compatible engine works. `scripts/supabase-local.sh` runs the pinned Supabase CLI through npx. No Supabase login or remote project access is needed for local development.

If those optional tools are missing, one Homebrew setup is:

```sh
brew install node@24 python@3.14
brew install --cask docker
export PATH="$(brew --prefix node@24)/bin:$PATH"
open -a Docker
```

Wait for Docker to finish starting. Keep Node 24 on your shell PATH for later sessions, or select it with your existing Node version manager.

Allow disk space for Xcode, simulator runtimes, Swift build products, and Docker images. The first package resolution and local backend start download dependencies.

## First launch with sample data

From a fresh clone, at the repository root:

```sh
./scripts/generate-project.sh
open ios/Kizuki.xcodeproj
```

Choose the **Kizuki-Local** scheme and an iPhone simulator. Press **Run** (⌘R).

Debug launches use the sample-data prototype by default. No Docker, Node, Supabase credentials, private xcconfig, or Apple Developer team is needed for this path. Keep launch arguments empty for the normal prototype. `-fixtures` explicitly selects disposable sample data.

`project.yml` is the source of truth for the Xcode project. Generated `.xcodeproj` files are ignored. Regenerate after changing project settings or pulling changes to `project.yml`. The generator copies the tracked `ios/Package.resolved` lockfile into the generated workspace. Let Xcode resolve those pinned packages.

App icons, fonts, avatars, and their bundled notices are tracked. Running the optional avatar generator or installing its npm dependencies is unnecessary to build the app.

## Local backend

Start Docker first. Confirm `docker info`, `node --version`, `npx --version`, and `python3 --version` work in the same terminal.

Run these commands from the repository root on first setup:

```sh
./scripts/supabase-local.sh start
./scripts/supabase-local.sh reset
./scripts/supabase-local.sh configure
./scripts/generate-project.sh
open ios/Kizuki.xcodeproj
```

**`reset` deletes the existing local database contents.** Use it for a new local stack or when you deliberately want to reapply the tracked migrations. It also installs the required local environment marker. It never targets staging. The Docker project is named `kizuki-local`; multiple checkouts on one Mac share this local stack and its ports.

`configure` writes `ios/Configuration/Local.private.xcconfig` with the running local stack's public client key and file permissions `0600`. This file is ignored. Each teammate generates their own copy. Do not copy another machine's private configuration or insert a service-role key into the app.

In Xcode, select **Kizuki-Local** → Edit Scheme → Run → Arguments. Add `-live` under Arguments Passed On Launch and remove `-fixtures`. Build and run again after configuring. Remove `-live` to return to the prototype.

The live build currently supports existing-account sign-in, session restoration, sign-out, and own-profile reads. Account creation, recovery, onboarding, and most feature repositories remain incomplete. The sample-data prototype demonstrates more UI than the live backend implements. A fresh local database has no demo account; local API tests create and remove their own synthetic users. Successful signed-out startup is the initial live-mode check.

Local endpoints:

| Service | Address |
| --- | --- |
| Supabase API | `http://127.0.0.1:54321` |
| PostgreSQL | `127.0.0.1:54322` |
| Local email inbox | `http://127.0.0.1:54324` |

Studio, Storage, and Edge Runtime are disabled in the local configuration. Stop the stack with `./scripts/supabase-local.sh stop`.

## Verification

The normal iOS suite runs without Docker or private credentials:

```sh
./scripts/check-ios.sh
```

It regenerates the project, builds Kizuki-Local, and runs unit and UI tests. The default destination is iPhone 17 Pro. To use another installed simulator:

```sh
KIZUKI_TEST_DESTINATION='platform=iOS Simulator,name=iPhone 16' ./scripts/check-ios.sh
```

Replace the device name with one installed on your Mac. Two local live smoke tests are opt-in and skip in the normal suite. Test result bundles are written under `.build/`.

After local backend setup, run:

```sh
./scripts/supabase-local.sh test
```

This runs database tests, environment-bootstrap refusal tests, and local Auth/profile/RLS integration checks. The API checks create temporary local users and delete them afterward. No staging credentials are needed.

For the Python policy checks, install the tracked dependency in an isolated environment outside the checkout:

```sh
python3 -m venv /tmp/kizuki-checks-venv
/tmp/kizuki-checks-venv/bin/python -m pip install -r scripts/requirements-checks.txt
/tmp/kizuki-checks-venv/bin/python scripts/check-workflow-policy.py
python3 scripts/check-env-pins.py
python3 scripts/check-remote-mutations.py
python3 scripts/test-remote-guard.py
python3 scripts/test-local-guard.py
python3 scripts/test-release-config.py
./scripts/test-screenshot-gallery-guard.sh
```

The complete CI commands are in [the Foundation workflow](.github/workflows/foundation.yml). Edge guard tests additionally use Deno 2.5.6: `deno test --allow-read=supabase/functions supabase/functions/_shared/env_guard_test.ts`.

## Staging and devices

**Kizuki-Staging** is separate from local startup. It requires an approved staging public client key in ignored `ios/Configuration/Staging.private.xcconfig` as `SUPABASE_PUBLISHABLE_KEY = <public client key>`. Obtain access from the project owner. The staging URL is already pinned. Do not alter it or commit credentials. Staging also needs its environment marker and schema deployed before live startup can succeed; deployment is a separate operator task.

**Kizuki-Production** intentionally refuses to build against production. Do not disable that guard to get started. Neither local startup nor ordinary tests require remote database passwords, service-role keys, management tokens, or agent tools.

Use an iOS simulator for the documented local setup. Running on a physical device requires your Apple signing team and provisioning. Its loopback address points to the phone, so it cannot use the Mac's `127.0.0.1` backend. The app deliberately restricts local URLs; use an approved staging setup for device testing.

## Troubleshooting

- **Project is missing:** run `./scripts/generate-project.sh`; open `ios/Kizuki.xcodeproj`, not the Swift package alone.
- **Missing simulator destination:** install the runtime/device in Xcode or set `KIZUKI_TEST_DESTINATION` for command-line tests.
- **Build tools missing in Xcode:** ensure `xcodegen` and `python3` are available on the command-line PATH. Generate the project from Terminal before opening it.
- **Live setup/refusal screen:** run local `start`, then `configure`, and rebuild. A missing environment marker requires `reset`; remember it clears local data.
- **Docker unavailable or port conflict:** start the Docker engine and check ports 54320–54324. Do not start a second stack from another checkout.
- **UI runner initialization timeout:** restart the simulator in Xcode and rerun the suite. Report repeat failures with the `.xcresult` bundle; do not skip UI tests.
- **Disk full:** remove disposable build products from `.build/` and unused simulator data through Xcode. Preserve local database data and private configuration.
- **Unexpected prototype instead of live UI:** add `-live` to the Local scheme's Run arguments and remove `-fixtures`.
