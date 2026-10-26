#!/usr/bin/env bash
set -euo pipefail
# Debug may deliberately show the non-crashing setup screen before local setup.
if [[ "${CONFIGURATION:-}" == Debug ]]; then exit 0; fi
python3 "$(dirname "$0")/validate-release-config.py"
