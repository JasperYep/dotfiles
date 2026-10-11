return {
    "rose-pine/neovim",
    name = "rose-pine",
    lazy = false,
    priority = 1000,
    config = function()
        vim.o.background = "dark"

        require("rose-pine").setup({
            variant = "auto",
            dark_variant = "moon",
            styles = {
                transparency = true,
            },
            highlight_groups = {
                IblIndent = { fg = "highlight_high" },
                IblScope = { fg = "foam" },

                MiniStatuslineModeNormal = { fg = "base", bg = "foam", bold = true },
                MiniStatuslineModeInsert = { fg = "base", bg = "pine", bold = true },
                MiniStatuslineModeVisual = { fg = "base", bg = "iris", bold = true },
                MiniStatuslineModeReplace = { fg = "base", bg = "love", bold = true },
                MiniStatuslineModeCommand = { fg = "base", bg = "gold", bold = true },
                MiniStatuslineModeOther = { fg = "base", bg = "rose", bold = true },
                MiniStatuslineDevinfo = { fg = "text", bg = "highlight_med" },
                MiniStatuslineFilename = { fg = "text", bg = "highlight_low", bold = true },
                MiniStatuslineFileinfo = { fg = "subtle", bg = "highlight_med" },
                MiniStatuslineInactive = { fg = "muted", bg = "highlight_low" },

                NvimTreeNormal = { bg = "none" },
                NvimTreeNormalNC = { bg = "none" },
                NvimTreeWinSeparator = { bg = "none", fg = "highlight_high" },
                NvimTreeFolderIcon = { bg = "none" },
                NvimTreeFolderName = { bg = "none" },
                NvimTreeOpenedFolderName = { bg = "none" },
                NvimTreeRootFolder = { bg = "none", fg = "foam" },

                TelescopeNormal = { bg = "none" },
                TelescopeBorder = { bg = "none", fg = "highlight_high" },
                TelescopePromptNormal = { bg = "none" },
                TelescopePromptBorder = { bg = "none", fg = "highlight_high" },
                TelescopeResultsNormal = { bg = "none" },
                TelescopeResultsBorder = { bg = "none", fg = "highlight_high" },
                TelescopePreviewNormal = { bg = "none" },
                TelescopePreviewBorder = { bg = "none", fg = "highlight_high" },

                WhichKeyFloat = { bg = "none" },
                WhichKeyBorder = { bg = "none", fg = "highlight_high" },

                LazyNormal = { bg = "none" },
                LazyButton = { bg = "none" },
                LazyH1 = { bg = "none" },
                LazyBorder = { fg = "highlight_high" },
                LazyProp = { bg = "none" },
                LazyCommit = { bg = "none" },
                LazyReasonStart = { bg = "none" },
                LazyReasonPlugin = { bg = "none" },
                LazyReasonRuntime = { bg = "none" },
                LazyReasonKeys = { bg = "none" },
            },
        })

        vim.cmd.colorscheme("rose-pine")
    end,
}
