require("full-border"):setup()
require("bunny"):setup({
	hops = {
		{ key = "/", path = "/" },
		{ key = "t", path = "~/todo/" },
		{ key = "u", path = "/run/media/jasper", desc = "USB" },
		{ key = { "c", "y" }, path = "~/.config/yazi", desc = "yazi Config files" },
		{ key = { "c", "i" }, path = "~/.config/i3/", desc = "i3 Config files" },
		{ key = { "c", "n" }, path = "~/.config/nvim/", desc = "Nvim Config files" },
		{ key = { "l", "s" }, path = "~/.local/share", desc = "Local share" },
		{ key = { "l", "b" }, path = "~/.local/bin", desc = "Local bin" },
		{ key = { "l", "t" }, path = "~/.local/state", desc = "Local state" },
		-- key and path attributes are required, desc is optional
	},
	desc_strategy = "path", -- If desc isn't present, use "path" or "filename", default is "path"
	ephemeral = false, -- Enable ephemeral hops, default is true
	tabs = true, -- Enable tab hops, default is true
	notify = true, -- Notify after hopping, default is false
	fuzzy_cmd = "fzf", -- Fuzzy searching command, default is "fzf"
})
