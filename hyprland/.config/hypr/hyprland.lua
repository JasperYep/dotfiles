-- Public Hyprland configuration. Machine-specific settings live in host.lua.
local configHome = os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")
require(configHome .. "/hypr/host.lua")

-----------------
--- AUTOSTART ---
-----------------

hl.on("hyprland.start", function()
	hl.exec_cmd(
		"systemctl --user import-environment HYPRLAND_INSTANCE_SIGNATURE WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE XDG_SESSION_CLASS"
	)
	hl.exec_cmd("~/.local/bin/theme-switch apply")
	hl.exec_cmd("waybar")
	hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")
	hl.exec_cmd("fcitx5 -d --replace")
	hl.exec_cmd("mako")
	hl.exec_cmd("hyprpaper")
	hl.exec_cmd("udiskie --appindicator")
	hl.exec_cmd("wl-paste --type text --watch cliphist store")
	hl.exec_cmd("wl-paste --type image --watch cliphist store")
end)

-------------------
--- ENVIRONMENT ---
-------------------

hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("XMODIFIERS", "@im=fcitx")
hl.env("QT_IM_MODULE", "fcitx")
hl.env("QT_QPA_PLATFORM", "wayland")

---------------------
--- LOOK AND FEEL ---
---------------------

hl.config({
	general = {
		gaps_in = 6,
		gaps_out = 6,
		border_size = 2,
		resize_on_border = false,
		allow_tearing = false,
		layout = "master",
	},
	decoration = {
		rounding = 8,
		rounding_power = 2,
		active_opacity = 1.0,
		inactive_opacity = 1.0,
		dim_inactive = false,
		shadow = {
			enabled = false,
		},
		blur = {
			enabled = false,
		},
	},
	animations = {
		enabled = true,
	},
	master = {
		mfact = 0.65,
		new_status = "slave",
		new_on_top = true,
	},
	misc = {
		force_default_wallpaper = 0,
		disable_hyprland_logo = true,
		disable_splash_rendering = true,
		vrr = 0,
		focus_on_activate = false,
	},
	render = {
		direct_scanout = true,
		expand_undersized_textures = true,
		new_render_scheduling = true,
	},
	input = {
		kb_layout = "custom",
		follow_mouse = 0,
		sensitivity = 0,
		touchpad = {
			natural_scroll = false,
		},
	},
})

-- Theme colors, GTK settings, and border overrides are managed by theme-switch.
require(configHome .. "/hypr/theme.lua")

hl.animation({ leaf = "windows", enabled = false })
hl.animation({ leaf = "border", enabled = false })
hl.animation({ leaf = "borderangle", enabled = false })
hl.animation({ leaf = "fade", enabled = true, speed = 1.5, bezier = "default" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 1.5, bezier = "default", style = "slide 10%" })
hl.animation({ leaf = "layers", enabled = false })

-------------------
--- KEYBINDINGS ---
-------------------

local mainMod = "SUPER"
local terminal = "ghostty"
local fileManager = "thunar"
local menu = "rofi -show drun"
local fileSearch = "~/.local/bin/rofi-files"
local calculator = "~/.local/bin/rofi-calc"

local function execBind(keys, command, options)
	hl.bind(keys, hl.dsp.exec_cmd(command), options)
end

execBind(mainMod .. " + B", "killall -SIGUSR1 waybar")
execBind(mainMod .. " + SHIFT + T", "~/.local/bin/theme-switch toggle")
execBind(mainMod .. " + RETURN", terminal)
execBind(mainMod .. " + E", fileManager)
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "maximized" }))
execBind(mainMod .. " + SPACE", "pkill -x rofi || " .. menu)
execBind(mainMod .. " + O", "pkill -x rofi || " .. fileSearch)
execBind(mainMod .. " + C", "pkill -x rofi || " .. calculator)

hl.bind(mainMod .. " + CTRL + H", hl.dsp.layout("mfact -0.05"))
hl.bind(mainMod .. " + CTRL + L", hl.dsp.layout("mfact +0.05"))
hl.bind(mainMod .. " + CTRL + R", hl.dsp.layout("orientationcycle left top center"))
hl.bind(mainMod .. " + CTRL + COMMA", hl.dsp.layout("removemaster"))
hl.bind(mainMod .. " + CTRL + PERIOD", hl.dsp.layout("addmaster"))

execBind(mainMod .. " + N", "~/.config/hypr/scripts/quicknote.sh")
execBind(mainMod .. " + V", "cliphist list | rofi -dmenu | cliphist decode | wl-copy")
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
execBind(mainMod .. " + S", [[grim -g "$(slurp)" - | wl-copy]])
execBind(mainMod .. " + SHIFT + S", [[grim -g "$(slurp)" - | satty -f -]])
hl.bind(mainMod .. " + CTRL + DELETE", hl.dsp.exit())
execBind(mainMod .. " + CTRL + Q", "hyprlock")
execBind(mainMod .. " + CTRL + SHIFT + Q", "~/.config/hypr/scripts/away-lock.sh")
hl.bind(mainMod .. " + SHIFT + SPACE", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }))

hl.bind(mainMod .. " + H", hl.dsp.focus({ direction = "l" }))
hl.bind(mainMod .. " + L", hl.dsp.focus({ direction = "r" }))
hl.bind(mainMod .. " + K", hl.dsp.focus({ direction = "u" }))
hl.bind(mainMod .. " + J", hl.dsp.focus({ direction = "d" }))

hl.bind(mainMod .. " + SHIFT + H", hl.dsp.window.move({ direction = "l" }))
hl.bind(mainMod .. " + SHIFT + L", hl.dsp.window.move({ direction = "r" }))
hl.bind(mainMod .. " + SHIFT + K", hl.dsp.window.move({ direction = "u" }))
hl.bind(mainMod .. " + SHIFT + J", hl.dsp.window.move({ direction = "d" }))

for workspace = 1, 10 do
	local key = workspace % 10
	hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = workspace }))
	hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = workspace, follow = true }))
end

hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mainMod .. " + TAB", hl.dsp.focus({ workspace = "previous" }))
hl.bind(mainMod .. " + SHIFT + RETURN", hl.dsp.layout("swapwithmaster"))

hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

local mediaRepeat = { locked = true, repeating = true }
local mediaLocked = { locked = true }
execBind("XF86AudioRaiseVolume", "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+", mediaRepeat)
execBind("XF86AudioLowerVolume", "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-", mediaRepeat)
execBind("XF86AudioMute", "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle", mediaRepeat)
execBind("XF86AudioMicMute", "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle", mediaRepeat)
execBind("XF86AudioNext", "playerctl next", mediaLocked)
execBind("XF86AudioPause", "playerctl play-pause", mediaLocked)
execBind("XF86AudioPlay", "playerctl play-pause", mediaLocked)
execBind("XF86AudioPrev", "playerctl previous", mediaLocked)

--------------------
--- WINDOW RULES ---
--------------------

hl.window_rule({
	name = "quicknote",
	match = { class = "^(quicknote)$" },
	size = { 800, 500 },
	float = true,
	opacity = "1.0",
})

hl.window_rule({
	name = "suppress-maximize-events",
	match = { class = ".*" },
	suppress_event = "maximize",
})

hl.window_rule({
	name = "fix-xwayland-drags",
	match = {
		class = "^$",
		title = "^$",
		xwayland = true,
		float = true,
		fullscreen = false,
		pin = false,
	},
	no_focus = true,
})

hl.window_rule({
	name = "Picture-in-picture",
	match = { title = "^Picture-in-picture$" },
	float = true,
	pin = true,
	border_size = 1,
})

hl.window_rule({
	name = "Wemeet",
	match = { class = "^(wemeetapp)$" },
	no_dim = true,
	no_anim = true,
	no_blur = true,
	no_shadow = true,
	dim_around = false,
	decorate = false,
	no_screen_share = false,
	border_size = 0,
	opacity = "1.0",
})

-------------------
--- LAYER RULES ---
-------------------

hl.layer_rule({
	name = "no_anim_for_selection",
	match = { namespace = "selection" },
	no_anim = true,
})
