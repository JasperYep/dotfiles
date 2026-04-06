#!/bin/bash

# Define paths
PIC_DIR="/home/jasper/Pictures"
CONF_FILE="/home/jasper/.config/hypr/hyprpaper.conf"
TODAY_WP="$PIC_DIR/today-wallpaper.jpg"
YESTERDAY_WP="$PIC_DIR/yesterday-wallpaper.jpg"
OLD_WP="$PIC_DIR/wallpaper.jpg"

# 1. Rename today to yesterday
if [ -f "$TODAY_WP" ]; then
    mv "$TODAY_WP" "$YESTERDAY_WP"
elif [ -f "$OLD_WP" ]; then
    mv "$OLD_WP" "$YESTERDAY_WP"
fi

# 2. Get today's high-quality free image (Bing Daily)
BING_API_CN="https://cn.bing.com/HPImageArchive.aspx?format=js&idx=0&n=10&nc=1612409408851&pid=hp&FORM=BEHPTB&uhd=1&uhdwidth=3840&uhdheight=2160"
# BING_API="https://global.bing.com/HPImageArchive.aspx?format=js&idx=0&n=9&pid=hp&FORM=BEHPTB&uhd=1&uhdwidth=3840&uhdheight=2160&setmkt=%s&setlang=en"
# BING_API="https://www.bing.com/HPImageArchive.aspx?format=js&idx=0&n=1&mkt=zh-CN"
IMG_PATH=$(curl -s "$BING_API_CN" | grep -oP '"url":"\K[^"]+' | head -n 1)
IMG_URL="https://www.bing.com${IMG_PATH}"

curl -sL "$IMG_URL" -o "$TODAY_WP"

# # 3. Update hyprpaper configuration
# sed -i "s|path = .*|path = $TODAY_WP|" "$CONF_FILE"
#
# # 4. Apply dynamically via hyprctl
# export HYPRLAND_INSTANCE_SIGNATURE=$(ls -t /tmp/hypr | head -n 1)
#
# hyprctl hyprpaper unload all
# hyprctl hyprpaper preload "$TODAY_WP"
# hyprctl hyprpaper wallpaper "DP-1,$TODAY_WP"
hyprctl hyprpaper wallpaper "DP-1,/home/jasper/Pictures/today-wallpaper.jpg"
# (Optional) Notify user
notify-send "Wallpaper Updated" "Today's daily wallpaper has been applied." -i "$TODAY_WP"
