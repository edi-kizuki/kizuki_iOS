#!/usr/bin/env bash
# Related: [[014-b03-environment-pinning]], [[2026-10-25-vf08-env-bootstrap]].
set -euo pipefail
exec python3 "$(dirname "$0")/kz_remote.py" "$@"
