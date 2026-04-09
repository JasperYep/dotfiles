#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "$0")" && pwd)
CONFIG_PATH="${1:-$SCRIPT_DIR/generated/config.json}"

if [[ ! -f "$CONFIG_PATH" ]]; then
  echo "Config not found: $CONFIG_PATH" >&2
  exit 1
fi

install -m 640 -o root -g sing-box "$CONFIG_PATH" /etc/sing-box/config.json
rm -f /var/lib/sing-box/cache.db
systemctl restart sing-box
systemctl --no-pager --full status sing-box
