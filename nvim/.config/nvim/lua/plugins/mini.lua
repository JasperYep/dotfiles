return {
    { -- Collection of various small independent plugins/modules
        "nvim-mini/mini.nvim",
        lazy = false,
        dependencies = { "nvim-tree/nvim-web-devicons" },
        config = function()
            -- Better Around/Inside textobjects
            require("mini.ai").setup({ n_lines = 500 })

            require("mini.surround").setup({
                mappings = {
                    add = "gza",
                    delete = "gzd",
                    find = "gzf",
                    find_left = "gzF",
                    highlight = "gzh",
                    replace = "gzr",
                    update_n_lines = "gzn",
                },
            })

            local statusline = require("mini.statusline")
            statusline.setup({ use_icons = vim.g.have_nerd_font })

            ---@diagnostic disable-next-line: duplicate-set-field
            statusline.section_location = function()
                return "%2l:%-2v"
            end
        end,
    },
}
