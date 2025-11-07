return {
	"SmiteshP/nvim-navic",
	event = "VeryLazy",
	dependencies = "neovim/nvim-lspconfig",
	opts = {
		-- 1. 定义我们设计的图标映射
		icons = {
			File = "󰈙 ",
			Module = "󰆧 ",
			Namespace = "󰅪 ",
			Package = "󰏗 ",
			Class = "󰠱 ",
			Method = "󰊕 ",
			Property = "󰜢 ",
			Field = "󰄶 ",
			Constructor = " ",
			Enum = " ",
			Interface = " ",
			Function = "󰊕 ",
			Variable = "󰀫 ",
			Constant = "󰏿 ",
			String = "󰅱 ",
			Number = "󰎠 ",
			Boolean = "󰔙 ",
			Array = "󰅪 ",
			Object = "󰅩 ",
			Key = "󰌋 ",
			Null = "󰟢 ",
			EnumMember = " ",
			Struct = "󰙅 ",
			Event = " ",
			Operator = "󰆕 ",
			TypeParameter = "󰊄 ",
		},

		lsp = {
			auto_attach = true, -- 自动附加到所有支持 LSP 的 buffer
			preference = nil, -- 可以指定优先使用的 LSP
		},
		highlight = true,
		separator = " > ",
		depth_limit = 0,
		depth_limit_indicator = "..",
	},
}
