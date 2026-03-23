#!/bin/sh
set -eu

ACK="--i-understand-that-this-will-be-running-without-the-usual-guardrails"
PORT="${PORT:-8080}"
WORKFLOW_PATH="${WORKFLOW_PATH:-/app/elixir/WORKFLOW.railway.md}"
LOGS_ROOT="${SYMPHONY_LOGS_ROOT:-/data/log}"
SYMPHONY_BIN="${SYMPHONY_BIN:-/app/elixir/bin/symphony}"

if [ ! -f "$WORKFLOW_PATH" ]; then
  echo "WORKFLOW_PATH does not exist: $WORKFLOW_PATH" >&2
  exit 1
fi

if [ ! -x "$SYMPHONY_BIN" ]; then
  echo "SYMPHONY_BIN is not executable: $SYMPHONY_BIN" >&2
  exit 1
fi

if [ -z "${LINEAR_API_KEY:-}" ]; then
  echo "LINEAR_API_KEY is required." >&2
  exit 1
fi

if ! codex login status >/dev/null 2>&1; then
  if [ -z "${OPENAI_API_KEY:-}" ]; then
    echo "OPENAI_API_KEY is required unless Codex is already authenticated in the container." >&2
    exit 1
  fi

  printf '%s' "$OPENAI_API_KEY" | codex login --with-api-key >/dev/null
fi

if [ -n "${GITHUB_TOKEN:-}" ]; then
  export GIT_CONFIG_COUNT=1
  export GIT_CONFIG_KEY_0="url.https://x-access-token:${GITHUB_TOKEN}@github.com/.insteadOf"
  export GIT_CONFIG_VALUE_0="https://github.com/"
fi

mkdir -p "$LOGS_ROOT"

exec "$SYMPHONY_BIN" \
  "$ACK" \
  "$WORKFLOW_PATH" \
  --logs-root "$LOGS_ROOT" \
  --port "$PORT"
