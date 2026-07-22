#!/usr/bin/env bash
set -Eeuo pipefail

picture_dir="$HOME/Pictures"
today="$picture_dir/today-wallpaper.jpg"
yesterday="$picture_dir/yesterday-wallpaper.jpg"
state_dir="$HOME/.local/state"

mkdir -p "$picture_dir" "$state_dir"
exec 9>"$state_dir/daily-wallpaper.lock"
flock -n 9 || exit 0

temporary="$(mktemp --tmpdir="$picture_dir" '.daily-wallpaper.XXXXXX.jpg')"
trap 'rm -f "$temporary"' EXIT

curl_args=(
  --fail --silent --show-error --location
  --retry 3 --retry-all-errors
  --connect-timeout 10 --max-time 60
)
api='https://cn.bing.com/HPImageArchive.aspx?format=js&idx=0&n=1&uhd=1&uhdwidth=3840&uhdheight=2160'
image_path="$(curl "${curl_args[@]}" "$api" | jq -er '.images[0].url')"
curl "${curl_args[@]}" "https://www.bing.com${image_path}" -o "$temporary"
magick identify "$temporary" >/dev/null

changed=false
if [[ ! -f "$today" ]] || ! cmp -s "$temporary" "$today"; then
  [[ ! -f "$today" ]] || mv -f "$today" "$yesterday"
  chmod 0644 "$temporary"
  mv -f "$temporary" "$today"
  changed=true
fi

if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] && command -v hyprctl >/dev/null; then
  if monitors="$(hyprctl -j monitors 2>/dev/null | jq -r '.[].name' 2>/dev/null)" \
    && [[ -n "$monitors" ]]
  then
    while IFS= read -r monitor; do
      hyprctl hyprpaper wallpaper "$monitor, $today, cover" >/dev/null \
        || printf 'daily-wallpaper: could not update %s\n' "$monitor" >&2
    done <<<"$monitors"
  fi
fi

if [[ "$changed" == true ]] \
  && command -v notify-send >/dev/null \
  && [[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]]
then
  notify-send "Wallpaper updated" "The daily wallpaper is ready." -i "$today" \
    || printf 'daily-wallpaper: could not send notification\n' >&2
fi
