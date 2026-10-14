#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT_DIR/.env.local"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "error: $ENV_FILE not found" >&2
  exit 1
fi

# export every var defined in .env.local
set -a
source "$ENV_FILE"
set +a

# A shared background service does not inherit this script's environment.
# Use a private server so MCP configuration can resolve the exported variables.
exec opencode --standalone "$ROOT_DIR" "$@"
