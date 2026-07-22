return {
    "catppuccin/nvim",
    name = "catppuccin",
    lazy = false,
    priority = 1000,
    config = function()
        vim.o.background = "light"

        require("catppuccin").setup({
            flavour = "latte",
            transparent_background = true,
            float = {
                transparent = true,
            },
            custom_highlights = function(colors)
                return {
                    IblIndent = { fg = colors.surface1 },
                    IblScope = { fg = colors.blue },

                    MiniStatuslineModeNormal = { fg = colors.base, bg = colors.blue, bold = true },
                    MiniStatuslineModeInsert = { fg = colors.base, bg = colors.green, bold = true },
                    MiniStatuslineModeVisual = { fg = colors.base, bg = colors.mauve, bold = true },
                    MiniStatuslineModeReplace = { fg = colors.base, bg = colors.red, bold = true },
                    MiniStatuslineModeCommand = { fg = colors.base, bg = colors.peach, bold = true },
                    MiniStatuslineModeOther = { fg = colors.base, bg = colors.teal, bold = true },
                    MiniStatuslineDevinfo = { fg = colors.text, bg = colors.surface0 },
                    MiniStatuslineFilename = { fg = colors.text, bg = colors.mantle, bold = true },
                    MiniStatuslineFileinfo = { fg = colors.subtext1, bg = colors.surface0 },
                    MiniStatuslineInactive = { fg = colors.overlay1, bg = colors.mantle },

                    NvimTreeNormal = { bg = "none" },
                    NvimTreeNormalNC = { bg = "none" },
                    NvimTreeWinSeparator = { bg = "none", fg = colors.surface1 },
                    NvimTreeFolderIcon = { bg = "none" },
                    NvimTreeFolderName = { bg = "none" },
                    NvimTreeOpenedFolderName = { bg = "none" },
                    NvimTreeRootFolder = { bg = "none", fg = colors.blue },

                    WinBar = { bg = "none" },
                    WinBarNC = { bg = "none" },

                    TelescopeNormal = { bg = "none" },
                    TelescopeBorder = { bg = "none", fg = colors.surface1 },
                    TelescopePromptNormal = { bg = "none" },
                    TelescopePromptBorder = { bg = "none", fg = colors.surface1 },
                    TelescopeResultsNormal = { bg = "none" },
                    TelescopeResultsBorder = { bg = "none", fg = colors.surface1 },
                    TelescopePreviewNormal = { bg = "none" },
                    TelescopePreviewBorder = { bg = "none", fg = colors.surface1 },

                    WhichKeyFloat = { bg = "none" },
                    WhichKeyBorder = { bg = "none", fg = colors.surface1 },

                    LazyNormal = { bg = "none" },
                    LazyButton = { bg = "none" },
                    LazyH1 = { bg = "none" },
                    LazyBorder = { fg = colors.surface1 },
                    LazyProp = { bg = "none" },
                    LazyCommit = { bg = "none" },
                    LazyReasonStart = { bg = "none" },
                    LazyReasonPlugin = { bg = "none" },
                    LazyReasonRuntime = { bg = "none" },
                    LazyReasonKeys = { bg = "none" },
                }
            end,
        })

        vim.cmd.colorscheme("catppuccin-latte")
    end,
}
