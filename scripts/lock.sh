#!/bin/sh

BLANK='#00000000'
TEXT='#000000cc'
SUBTEXT='#000000aa'
# TEXT='#ffffffee'
# SUBTEXT='#ffffffaa'
SUCCESS='#ffffffdd'
ERROR='#ff5c5cff'

# Week I / II
WEEKNUM=$(date +%V)
SIZE=$([ $((WEEKNUM % 2)) -eq 1 ] && echo "I" || echo "II")

i3lock \
    --image=/home/jasper/Pictures/lockscreen_bg.png \
    \
    --insidever-color=$BLANK \
    --ringver-color=$BLANK \
    --insidewrong-color=$BLANK \
    --ringwrong-color=$BLANK \
    --inside-color=$BLANK \
    --ring-color=$BLANK \
    --line-color=$BLANK \
    --separator-color=$BLANK \
    --ring-width=1 \
    --radius=1 \
    \
    --verif-color=$SUCCESS \
    --wrong-color=$ERROR \
    --time-color=$TEXT \
    --date-color=$SUBTEXT \
    --layout-color=$SUBTEXT \
    \
    --keyhl-color=$SUCCESS \
    --bshl-color=$ERROR \
    \
    --clock \
    --indicator \
    --time-str="%H:%M" \
    --date-str="%A·$SIZE, %B %d" \
    --time-size=120 \
    --time-font="SF Pro Display" \
    --date-size=26 \
    \
    --date-pos="ix:120" \
    --time-pos="ix:250" \
    --greeter-pos="ix:1050" \
    --date-align=0 \
    --time-align=0
