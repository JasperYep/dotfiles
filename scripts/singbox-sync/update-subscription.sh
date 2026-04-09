#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "$0")" && pwd)
ENV_FILE="$SCRIPT_DIR/subscription.env"
BASE_CONFIG="$SCRIPT_DIR/base.json"
CONVERTER_DIR="${CONVERTER_DIR:-$HOME/tools/sing-box-subscribe}"
OUTPUT="$SCRIPT_DIR/generated/config.json"

ensure_converter_ready() {
  if [[ ! -x "$CONVERTER_DIR/.venv/bin/python" ]]; then
    cat >&2 <<MSG
converter not ready: $CONVERTER_DIR

bootstrap:
  git clone --depth 1 https://github.com/NiuStar/sing-box-subscribe "$CONVERTER_DIR"
  cd "$CONVERTER_DIR"
  uv venv .venv
  uv pip install --python .venv/bin/python -r requirements.txt
MSG
    exit 1
  fi

  local parser="$CONVERTER_DIR/parsers/clash2base64.py"
  if [[ -f "$parser" ]] && grep -q "share_link\['smux'\]\['protocol'\]" "$parser"; then
    python3 - "$parser" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
text = p.read_text(encoding='utf-8')
old = "            vless_info[\"protocol\"] = share_link['smux']['protocol']\n"
new = "            vless_info[\"protocol\"] = share_link.get('smux', {}).get('protocol', '')\n"
if old in text:
    p.write_text(text.replace(old, new, 1), encoding='utf-8')
PY
  fi
}

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

ensure_converter_ready
python3 "$SCRIPT_DIR/sync_subscription.py" \
  "${SOURCE_ARGS[@]}" \
  --user-agent "$USER_AGENT" \
  --base-config "$BASE_CONFIG" \
  --converter-dir "$CONVERTER_DIR" \
  --output "$OUTPUT"

sing-box check -c "$OUTPUT"
echo "Validated: $OUTPUT"
echo "Manual install only. Current system config is untouched until you run install-generated-config.sh"
