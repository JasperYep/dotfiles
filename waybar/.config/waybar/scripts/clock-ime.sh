#!/usr/bin/env bash
set -euo pipefail

state_file="${XDG_RUNTIME_DIR:-/tmp}/waybar-clock-mode"

if [[ "${1:-}" == "toggle" ]]; then
    mode="$(cat "$state_file" 2>/dev/null || printf 'time')"
    if [[ "$mode" == "date" ]]; then
        printf 'time' > "$state_file"
    else
        printf 'date' > "$state_file"
    fi
    pkill -RTMIN+9 waybar 2>/dev/null || true
    exit 0
fi

mode="$(cat "$state_file" 2>/dev/null || printf 'time')"
if [[ "$mode" == "date" ]]; then
    text="$(date '+%Y-%m-%d')"
else
    text="$(date '+%H:%M')"
fi

im_name="$(fcitx5-remote -n 2>/dev/null || true)"
if [[ "$im_name" == rime* ]]; then
    class="ime-zh"
else
    class="ime-en"
fi

printf '{"text":"%s","class":"%s","tooltip":"%s"}\n' \
    "$text" \
    "$class" \
    "$(date '+%Y-%m-%d %A')"
