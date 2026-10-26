#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Deliberately no link, db push, --db-url, or remote migration operation.
# Prevent inherited credentials from influencing this exclusively local workflow.
unset SUPABASE_ACCESS_TOKEN SUPABASE_DB_PASSWORD SUPABASE_PROJECT_ID
command -v docker >/dev/null || { echo 'Docker is required for local Supabase.' >&2; exit 1; }
docker info >/dev/null 2>&1 || { echo 'Docker daemon unavailable. Start Docker Desktop or a compatible container runtime.' >&2; exit 1; }
cli() { npx --yes supabase@2.122.0 "$@"; }
case "${1:-}" in
  start) cli start ;;
  stop) cli stop ;;
  reset) cli db reset --local ;;
  test)
    cli test db --local
    cli status --output json | python3 scripts/test-local-api.py
    ;;
  configure)
    cli status --output json | python3 scripts/configure-local.py
    ;;
  *) echo 'Usage: scripts/supabase-local.sh {start|stop|reset|test|configure}' >&2; exit 2 ;;
esac
