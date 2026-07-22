return {
    'MeanderingProgrammer/render-markdown.nvim',
    ft = { 'markdown' },
    dependencies = {
        'nvim-treesitter/nvim-treesitter',
        'nvim-mini/mini.nvim',
    },
    opts = {
        restart_highlighter = true,
        anti_conceal = {
            ignore = {
                latex = true,
            },
        },
        latex = {
            converter = { vim.fn.stdpath('config') .. '/bin/render_markdown_latex.py' },
            render_modes = true,
        },
    },
    config = function(_, opts)
        require('render-markdown').setup(opts)
    end,
}
