#!/usr/bin/env sh

set -eu

# 临时便签文件落在内存盘（$XDG_RUNTIME_DIR 是 tmpfs）：
# 登录会话内一直保留，登出/重启随内存盘一起消失 —— 这就是“用后即焚”。
note_file="${XDG_RUNTIME_DIR:-/tmp}/quicknote.txt"
touch "$note_file"

focus_quicknote() {
	hyprctl dispatch 'hl.dsp.focus({ window = "class:^(quicknote)$" })' >/dev/null
}

# 已有便签窗口：直接聚焦（平铺窗口不做显隐切换）
if hyprctl clients -j | grep -q '"class": "quicknote"'; then
	focus_quicknote
	exit 0
fi

# 组装 micro 配置：配色跟随系统主题（theme/current 为 light/dark 软链）
micro_dir="${XDG_RUNTIME_DIR:-/tmp}/quicknote-micro"
mkdir -p "$micro_dir/colorschemes"
cp -f "$HOME/.config/theme/current/micro/quicknote.micro" "$micro_dir/colorschemes/quicknote.micro"
cat >"$micro_dir/settings.json" <<'JSON'
{
    "colorscheme": "quicknote",
    "softwrap": true,
    "ruler": false,
    "statusline": true,
    "statusformatl": "$(line):$(col)$(modified)  ",
    "statusformatr": "quicknote ",
    "savecursor": true,
    "matchbrace": true,
    "hlsearch": true,
    "incsearch": true,
    "tabstospaces": true,
    "tabsize": 4
}
JSON

command="foot --app-id=quicknote -e micro -config-dir '$micro_dir' '$note_file'"
lua_command="$(printf '%s' "$command" | sed 's/\\/\\\\/g; s/"/\\"/g')"
hyprctl dispatch "hl.dsp.exec_cmd(\"$lua_command\")" >/dev/null

i=0
while [ "$i" -lt 20 ]; do
	sleep 0.05
	if hyprctl clients -j | grep -q '"class": "quicknote"'; then
		focus_quicknote
		break
	fi
	i=$((i + 1))
done
