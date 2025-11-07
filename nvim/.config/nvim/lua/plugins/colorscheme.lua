return {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    config = function()
        require("tokyonight").setup({
            style = "day",
            -- ✅ 在这里设置 indent_line 颜色，与主题完美集成
            on_highlights = function(hl, c)
                -- 使用主题内置的颜色变量，而不是硬编码的 "#444444"
                -- c.dark3 是一个比背景稍亮的灰色，非常适合浅色主题
                hl.IblIndent = { fg = c.dark3 }
                -- 使用主题的柔和蓝色来高亮当前代码块
                hl.IblScope = { fg = c.blue2 }
            end,
        })
        vim.cmd("colorscheme tokyonight-day")
    end,
}
