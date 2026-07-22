return {
    "lukas-reineke/indent-blankline.nvim",
    main = "ibl",
    -- 使用事件触发，这是解决加载顺序问题的最优雅方式
    event = { "BufReadPost", "BufNewFile" },
    opts = {
        indent = {
            char = "▏", -- 使用你喜欢的精致字符
        },
        scope = {
            enabled = true,
            show_start = false,
            show_end = false,
        },
        -- 在这里排除不需要缩进线的文件类型
        exclude = {
            filetypes = {
                "help",
                "alpha",
                "dashboard",
                "neo-tree",
                "Trouble",
                "lazy",
                "mason",
                "notify",
                "toggleterm",
            },
        },
    },
}
