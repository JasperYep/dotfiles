#!/usr/bin/env sh

set -eu

note_dir="${XDG_STATE_HOME:-$HOME/.local/state}/hypr/quicknote"
note_file="$note_dir/note.md"

mkdir -p "$note_dir"
touch "$note_file"

focus_quicknote() {
    hyprctl dispatch 'hl.dsp.focus({ window = "class:^(quicknote)$" })'
}

clients_json="$(hyprctl clients -j)"

case "$clients_json" in
    *'"class"'*'"quicknote"'*)
        hyprctl dispatch 'hl.dsp.workspace.toggle_special("notes")'
        focus_quicknote
        ;;
    *)
        shell_note_file="$(printf '%s' "$note_file" | sed "s/'/'\\\\''/g")"
        command="ghostty --class=quicknote -e nvim '$shell_note_file'"
        lua_command="$(printf '%s' "$command" | sed 's/\\/\\\\/g; s/"/\\"/g')"
        hyprctl dispatch "hl.dsp.exec_cmd(\"$lua_command\", { workspace = \"special:notes\" })"
        i=0
        while [ "$i" -lt 20 ]; do
            sleep 0.05
            clients_json="$(hyprctl clients -j)"
            case "$clients_json" in
                *'"class"'*'"quicknote"'*)
                    focus_quicknote
                    exit 0
                    ;;
            esac
            i=$((i + 1))
        done
        ;;
esac
