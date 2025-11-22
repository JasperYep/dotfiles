#!/bin/sh

prefix="/usr"
exec_prefix="${prefix}"
xrdb="xrdb"
xinitdir="/etc/X11/xinit"
xclock="xclock"
xterm="xterm"
twm="twm"
xmodmap="xmodmap"

userresources="$HOME/.Xresources"
usermodmap="$HOME/.Xmodmap"
sysresources="$xinitdir/.Xresources"
sysmodmap="$xinitdir/.Xmodmap"

# merge in defaults and keymaps

if [ -f "$sysresources" ]; then
    if [ -x /usr/bin/cpp ]; then
        "$xrdb" -merge "$sysresources"
    else
        "$xrdb" -nocpp -merge "$sysresources"
    fi
fi

if [ -f "$sysmodmap" ]; then
    "$xmodmap" "$sysmodmap"
fi

if [ -f "$userresources" ]; then
    if [ -x /usr/bin/cpp ]; then
        "$xrdb" -merge "$userresources"
    else
        "$xrdb" -nocpp -merge "$userresources"
    fi
fi

if [ -f "$usermodmap" ]; then
    "$xmodmap" "$usermodmap"
fi

# start some nice programs

if [ -d "$xinitdir"/xinitrc.d ]; then
    for f in "$xinitdir/xinitrc.d"/?*.sh; do
        [ -x "$f" ] && . "$f"
    done
    unset f
fi

# slstatus &
# status
while true; do
	WEEK_NUM=$(date '+%V') # %V 是 ISO 8601 标准的周数
	if [ $((WEEK_NUM % 2)) -eq 1 ]; then
	    WEEK_TAG="I"
	else
	    WEEK_TAG="II"
	fi

	xsetroot -name "$(date '+%Y-%m-%d %H:%M')  $WEEK_TAG"
sleep 60
done &


WALLPAPER_DIR=~/Pictures/Wallpapers

while true; do
    WALLPAPER_PATH=$(find "$WALLPAPER_DIR" -type f | shuf -n 1)
    if [ -n "$WALLPAPER_PATH" ]; then
        feh --bg-fill "$WALLPAPER_PATH"
    fi
    sleep 1800
done &


# pomodoro
~/pomodoro/pom_status.sh &

fcitx5 &

# 禁用屏幕保护和显示器关闭
xset s off
xset s noblank
xset -dpms

# autostart
picom -b


exec dwm
