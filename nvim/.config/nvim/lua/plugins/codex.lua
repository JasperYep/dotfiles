return {
    {
        "rhart92/codex.nvim",
        event = "VeryLazy",
        cmd = { "CodexToggle", "CodexBuffer", "CodexSelection" },
        keys = {
            {
                "<leader>m",
                function()
                    require("codex").toggle()
                end,
                desc = "Toggle Codex sidebar",
                mode = "n",
            },
            {
                "<leader>M",
                function()
                    require("codex").send_buffer()
                end,
                desc = "Send buffer to Codex",
                mode = "n",
            },
            {
                "<leader>m",
                function()
                    require("codex").send_selection()
                end,
                desc = "Send selection to Codex",
                mode = "x",
            },
        },
        opts = function()
            local codex = vim.fn.exepath("codex")
            local has_ui = #vim.api.nvim_list_uis() > 0

            if codex == "" then
                local fallback = vim.fn.expand("~/.npm-global/bin/codex")
                codex = vim.fn.executable(fallback) == 1 and fallback or "codex"
            end

            return {
                split = "vertical",
                size = 0.4,
                codex_cmd = { codex },
                autostart = has_ui,
                focus_after_send = true,
            }
        end,
        config = function(_, opts)
            require("codex").setup(opts)

            vim.api.nvim_create_user_command("CodexToggle", function()
                require("codex").toggle()
            end, { desc = "Toggle Codex sidebar" })

            vim.api.nvim_create_user_command("CodexBuffer", function()
                require("codex").send_buffer()
            end, { desc = "Send current buffer to Codex" })

            vim.api.nvim_create_user_command("CodexSelection", function()
                require("codex").send_selection()
            end, { desc = "Send last visual selection to Codex" })
        end,
    },
}
