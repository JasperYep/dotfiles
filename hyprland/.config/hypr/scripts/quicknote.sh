#!/usr/bin/env sh

set -eu

note_dir="${XDG_STATE_HOME:-$HOME/.local/state}/hypr/quicknote"
note_file="$note_dir/note.md"
matcher='class:^(quicknote)$'

mkdir -p "$note_dir"
touch "$note_file"

clients_json="$(hyprctl clients -j)"

case "$clients_json" in
    *'"class"'*'"quicknote"'*)
        hyprctl dispatch togglespecialworkspace notes
        hyprctl dispatch focuswindow "$matcher"
        ;;
    *)
        hyprctl dispatch exec "[workspace special:notes] kitty --class quicknote -e nvim $note_file"
        i=0
        while [ "$i" -lt 20 ]; do
            sleep 0.05
            clients_json="$(hyprctl clients -j)"
            case "$clients_json" in
                *'"class"'*'"quicknote"'*)
                    hyprctl dispatch focuswindow "$matcher"
                    exit 0
                    ;;
            esac
            i=$((i + 1))
        done
        ;;
esac
