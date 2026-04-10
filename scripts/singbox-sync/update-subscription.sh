#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "$0")" && pwd)
ENV_FILE="$SCRIPT_DIR/subscription.env"
BASE_CONFIG="$SCRIPT_DIR/base.json"
CONVERTER_BIN="${SING_BOX_SUBSCRIBE_BIN:-sing-box-subscribe}"
OUTPUT="$SCRIPT_DIR/generated/config.json"

if [[ -f "$ENV_FILE" ]]; then
  set -a
  source "$ENV_FILE"
  set +a
fi

if [[ $# -gt 0 ]]; then
  if [[ -f "$1" ]]; then
    SOURCE_ARGS=(--source-file "$1")
  else
    SOURCE_ARGS=(--subscription-url "$1")
  fi
else
  : "${SUBSCRIPTION_URL:?SUBSCRIPTION_URL is not set}"
  SOURCE_ARGS=(--subscription-url "$SUBSCRIPTION_URL")
fi

USER_AGENT="${SUBSCRIPTION_UA:-clashmeta}"

python3 "$SCRIPT_DIR/sync_subscription.py" \
  "${SOURCE_ARGS[@]}" \
  --user-agent "$USER_AGENT" \
  --base-config "$BASE_CONFIG" \
  --converter-bin "$CONVERTER_BIN" \
  --output "$OUTPUT"

sing-box check -c "$OUTPUT"
echo "Validated: $OUTPUT"
echo "Generated preview only. The NixOS service path owns production deployment."
