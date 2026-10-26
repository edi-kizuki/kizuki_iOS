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
