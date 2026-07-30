#!/usr/bin/env sh

set -eu

workspace_json="$(hyprctl activeworkspace -j)"
layout="master"

case "$workspace_json" in
    *'"tiledLayout"'*'"scrolling"'*)
        layout="scrolling"
        ;;
esac

dispatch() {
    hyprctl dispatch "$1"
}

case "${1:-}" in
    focus-left)
        if [ "$layout" = "scrolling" ]; then
            dispatch 'hl.dsp.layout("focus l")'
        else
            dispatch 'hl.dsp.focus({ direction = "l" })'
        fi
        ;;
    focus-right)
        if [ "$layout" = "scrolling" ]; then
            dispatch 'hl.dsp.layout("focus r")'
        else
            dispatch 'hl.dsp.focus({ direction = "r" })'
        fi
        ;;
    move-left)
        if [ "$layout" = "scrolling" ]; then
            dispatch 'hl.dsp.layout("swapcol l")'
        else
            dispatch 'hl.dsp.window.move({ direction = "l" })'
        fi
        ;;
    move-right)
        if [ "$layout" = "scrolling" ]; then
            dispatch 'hl.dsp.layout("swapcol r")'
        else
            dispatch 'hl.dsp.window.move({ direction = "r" })'
        fi
        ;;
    shrink-main)
        if [ "$layout" = "scrolling" ]; then
            dispatch 'hl.dsp.layout("colresize -0.05")'
        else
            dispatch 'hl.dsp.layout("mfact -0.05")'
        fi
        ;;
    grow-main)
        if [ "$layout" = "scrolling" ]; then
            dispatch 'hl.dsp.layout("colresize +0.05")'
        else
            dispatch 'hl.dsp.layout("mfact +0.05")'
        fi
        ;;
    promote-main)
        if [ "$layout" = "scrolling" ]; then
            dispatch 'hl.dsp.layout("promote")'
        else
            dispatch 'hl.dsp.layout("swapwithmaster")'
        fi
        ;;
    *)
        echo "usage: $0 {focus-left|focus-right|move-left|move-right|shrink-main|grow-main|promote-main}" >&2
        exit 64
        ;;
esac
