return 
    { -- Autoformat
        'stevearc/conform.nvim',
        event = { 'BufWritePre' },
        cmd = { 'ConformInfo' },
        keys = {
            {
                '<leader>cf',
                function()
                    require('conform').format { async = false, lsp_format = 'fallback' }
                end,
                desc = '[C]ode [F]ormat buffer',
            },
        },
        opts = {
            notify_on_error = false,
            format_on_save = function(bufnr)
                local format_on_save_filetypes = {
                    lua = true,
                    python = true,
                }

                if format_on_save_filetypes[vim.bo[bufnr].filetype] then
                    return {
                        timeout_ms = 500,
                        lsp_format = 'fallback',
                    }
                end

                return nil
            end,
            formatters_by_ft = {
                lua = { 'stylua' },
                python = { 'isort', 'black' },
                c = { 'clang_format' },
                cpp = { 'clang_format' },
            },
        },
    }
