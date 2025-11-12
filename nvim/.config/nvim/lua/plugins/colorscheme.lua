return {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    config = function()
        require("tokyonight").setup({
            style = "day",
            -- 透明毛玻璃化
            on_highlights = function(hl, c)
                -- 使用主题内置的颜色变量，而不是硬编码的 "#444444"
                -- c.dark3 是一个比背景稍亮的灰色，非常适合浅色主题
                hl.IblIndent = { fg = c.dark3 }
                -- 使用主题的柔和蓝色来高亮当前代码块
                hl.IblScope = { fg = c.blue2 }
                --
                -- --- 新增的透明化配置 ---

                -- 1. Mini Statusline 透明
                -- 我们将状态栏的背景设置为 none
                hl.MiniStatuslineModeNormal = { bg = "none" }
                hl.MiniStatuslineModeInsert = { bg = "none" }
                hl.MiniStatuslineModeVisual = { bg = "none" }
                hl.MiniStatuslineModeReplace = { bg = "none" }
                hl.MiniStatuslineModeCommand = { bg = "none" }
                hl.MiniStatuslineInactive = { bg = "none" }

                -- 2. NvimTree 透明
                -- NvimTree 的背景和普通文本背景关联，通常已经透明了
                -- 但侧边栏的文件名等可能有自己的背景
                hl.NvimTreeNormal = { bg = "none" }
                hl.NvimTreeNormalNC = { bg = "none" } -- 非活动窗口
                hl.NvimTreeWinSeparator = { bg = "none", fg = c.border } -- 分隔线
                hl.NvimTreeFolderIcon = { bg = "none" }
                hl.NvimTreeFolderName = { bg = "none" }
                hl.NvimTreeOpenedFolderName = { bg = "none" }
                hl.NvimTreeRootFolder = { bg = "none", fg = c.blue1 } -- 根文件夹名高亮

                -- 3. Winbar 透明
                -- Winbar 使用的是 WinBar 和 WinBarNC 高亮组
                hl.WinBar = { bg = "none" }
                hl.WinBarNC = { bg = "none" }

                -- 4. (可选) 其他常见UI组件透明
                -- 比如 Telescope, WhichKey 等
                hl.TelescopeNormal = { bg = "none" }
                hl.TelescopeBorder = { bg = "none", fg = c.border }
                hl.TelescopePromptNormal = { bg = "none" }
                hl.TelescopePromptBorder = { bg = "none", fg = c.border }
                hl.TelescopeResultsNormal = { bg = "none" }
                hl.TelescopeResultsBorder = { bg = "none", fg = c.border }
                hl.TelescopePreviewNormal = { bg = "none" }
                hl.TelescopePreviewBorder = { bg = "none", fg = c.border }

                hl.WhichKeyFloat = { bg = "none" }
                hl.WhichKeyBorder = { bg = "none", fg = c.border }

                -- 5. 让 Lazy.nvim 的启动窗口变透明
                hl.LazyNormal = { bg = "none" } -- 窗口主体背景
                hl.LazyButton = { bg = "none" } -- 按钮背景
                hl.LazyH1 = { bg = "none" } -- 标题背景
                hl.LazyBorder = { fg = c.border } -- 边框颜色（使用主题色）
                hl.LazyProp = { bg = "none" } -- 属性文本背景
                hl.LazyCommit = { bg = "none" } -- 提交信息背景
                hl.LazyReasonStart = { bg = "none" } -- 启动原因背景
                hl.LazyReasonPlugin = { bg = "none" } -- 插件原因背景
                hl.LazyReasonRuntime = { bg = "none" } -- 运行时原因背景
                hl.LazyReasonKeys = { bg = "none" } -- 按键绑定原因背景
            end,
            transparent = true,
        })
        vim.cmd("colorscheme tokyonight-day")
    end,
}
