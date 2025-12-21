require("full-border"):setup()
require("bunny"):setup({
	hops = {
		{ key = "c", path = "~/code" },
		{ key = "~", path = "~", desc = "Home" },
		{ key = "d", path = "~/Desktop", desc = "Desktop" },
		{ key = "D", path = "~/Documents", desc = "Documents" },
		{ key = { "l" }, path = "~/Downloads/", desc = "Downloads" },
		{ key = { "s" }, path = "~/code/slides/workspace", desc = "Slides Workspace" },
		{ key = "u", path = "/run/media/jasper", desc = "USB" },
		{ key = { "y" }, path = "~/dotfiles/yazi/.config/yazi/", desc = "yazi config" },
	},
	desc_strategy = "path", -- If desc isn't present, use "path" or "filename", default is "path"
	ephemeral = false, -- Enable ephemeral hops, default is true
	tabs = true, -- Enable tab hops, default is true
	notify = true, -- Notify after hopping, default is false
	fuzzy_cmd = "fzf", -- Fuzzy searching command, default is "fzf"
})
