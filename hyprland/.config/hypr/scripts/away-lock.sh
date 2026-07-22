#!/usr/bin/env sh
set -eu

status_file="${XDG_RUNTIME_DIR:-/tmp}/hyprlock-away-$(id -u)"

show_status() {
    [ -r "$status_file" ] || return 0
    sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g' "$status_file"
}

prompt_and_lock() {
    status="$(
        rofi -dmenu \
            -p "离开状态" \
            -theme-str 'window { width: 900px; }' \
            </dev/null
    )" || return 0
    [ -n "$status" ] || return 0

    umask 077
    printf '%s\n' "$status" >"$status_file"
    trap 'rm -f "$status_file"' 0
    trap 'exit 1' HUP INT TERM

    hyprlock --config "$HOME/.config/hypr/hyprlock-away.conf"
}

case "${1:-prompt}" in
    prompt) prompt_and_lock ;;
    show) show_status ;;
    *) exit 2 ;;
esac
