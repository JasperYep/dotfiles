return {
    'nvim-treesitter/nvim-treesitter',
    lazy = false,
    build = ':TSUpdate',
    keys = {
        {
            '<leader>pt',
            function()
                require('nvim-treesitter').install({
                    'bash',
                    'c',
                    'cpp',
                    'json',
                    'lua',
                    'markdown',
                    'markdown_inline',
                    'python',
                    'query',
                    'vim',
                    'vimdoc',
                    'yaml',
                }, { summary = true })
            end,
            desc = '[P]ackage [T]reesitter parsers',
        },
    },
    config = function()
        local languages = {
            'bash',
            'c',
            'cpp',
            'json',
            'lua',
            'markdown',
            'markdown_inline',
            'python',
            'query',
            'vim',
            'vimdoc',
            'yaml',
        }

        require('nvim-treesitter').setup({})

        vim.api.nvim_create_autocmd('FileType', {
            group = vim.api.nvim_create_augroup('treesitter-start', { clear = true }),
            pattern = languages,
            callback = function(args)
                pcall(vim.treesitter.start, args.buf)
            end,
        })
    end,
}

