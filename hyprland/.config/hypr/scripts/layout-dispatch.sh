#!/usr/bin/env sh

set -eu

layout="$(hyprctl activeworkspace -j | jq -r '.tiledLayout // "master"')"

dispatch() {
    hyprctl dispatch "$@"
}

case "${1:-}" in
    focus-left)
        if [ "$layout" = "scrolling" ]; then
            dispatch layoutmsg "focus l"
        else
            dispatch movefocus l
        fi
        ;;
    focus-right)
        if [ "$layout" = "scrolling" ]; then
            dispatch layoutmsg "focus r"
        else
            dispatch movefocus r
        fi
        ;;
    move-left)
        if [ "$layout" = "scrolling" ]; then
            dispatch layoutmsg "swapcol l"
        else
            dispatch movewindow l
        fi
        ;;
    move-right)
        if [ "$layout" = "scrolling" ]; then
            dispatch layoutmsg "swapcol r"
        else
            dispatch movewindow r
        fi
        ;;
    shrink-main)
        if [ "$layout" = "scrolling" ]; then
            dispatch layoutmsg "colresize -0.05"
        else
            dispatch layoutmsg "mfact -0.05"
        fi
        ;;
    grow-main)
        if [ "$layout" = "scrolling" ]; then
            dispatch layoutmsg "colresize +0.05"
        else
            dispatch layoutmsg "mfact +0.05"
        fi
        ;;
    promote-main)
        if [ "$layout" = "scrolling" ]; then
            dispatch layoutmsg promote
        else
            dispatch layoutmsg swapwithmaster
        fi
        ;;
    *)
        echo "usage: $0 {focus-left|focus-right|move-left|move-right|shrink-main|grow-main|promote-main}" >&2
        exit 64
        ;;
esac
