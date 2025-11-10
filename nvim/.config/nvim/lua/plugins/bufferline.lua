-- 推荐的 bufferline.nvim 配置 (使用 lazy = false)
return {
    "akinsho/bufferline.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    version = "*",
    -- 核心修复：设置为 lazy = false，强制在启动时加载
    lazy = false,

    -- 或者使用 event 替代，例如: event = 'VimEnter'

    config = function()
        -- 确保 nvim-web-devicons 在此之前加载，以便图标可用
        require("nvim-web-devicons").setup({})

        require("bufferline").setup({
            options = {
                style_preset = { require("bufferline").style_preset.default },
                show_buffer_close_icons = true,
                show_close_icon = true,
                diagnostics = "nvim_lsp",
            },
        })
    end,
}
