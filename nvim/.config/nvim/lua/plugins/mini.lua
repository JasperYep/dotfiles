return {
    -- Highlight todo, notes, etc in comments
    { "folke/todo-comments.nvim", event = "VimEnter", dependencies = { "nvim-lua/plenary.nvim" }, opts = { signs = false } },

    { -- Collection of various small independent plugins/modules
        "echasnovski/mini.nvim",
        -- 为了让 statusline 在启动时立即可见，设置 lazy=false 和高优先级
        lazy = false,
        priority = 1000,
        dependencies = { "nvim-tree/nvim-web-devicons" },
        config = function()
            -- 在这一个 config 函数里配置所有需要的 mini 模块

            -- Better Around/Inside textobjects
            require("mini.ai").setup({ n_lines = 500 })

            -- Add/delete/replace surroundings (brackets, quotes, etc.)
            -- 这是解决你问题的关键
            require("mini.surround").setup()

            -- Statusline
            local statusline = require("mini.statusline")
            -- set use_icons to true if you have a Nerd Font
            statusline.setup({ use_icons = vim.g.have_nerd_font })

            -- You can configure sections in the statusline by overriding their
            -- default behavior. For example, here we set the section for
            -- cursor location to LINE:COLUMN
            ---@diagnostic disable-next-line: duplicate-set-field
            statusline.section_location = function()
                return "%2l:%-2v"
            end
        end,
    },
}
