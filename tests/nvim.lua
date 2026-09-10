-- Run from the repo with deployed config/plugins:
-- nvim --headless '+lua local ok, err = pcall(dofile, "tests/nvim.lua"); if not ok then print(err); vim.cmd("cquit") end' +qa
local plugins = require('lazy.core.config').plugins
assert(not plugins['nvim-navic'], 'removed breadcrumb plugin is still registered')
assert(vim.o.winbar == '', 'unexpected permanent winbar')
for _, name in ipairs({ 'nvim-lspconfig', 'blink.cmp', 'conform.nvim', 'nvim-treesitter',
    'telescope.nvim', 'nvim-tree.lua', 'aerial.nvim', 'gitsigns.nvim', 'render-markdown.nvim' }) do
    assert(plugins[name], 'missing core editor feature: ' .. name)
end
require('lazy').load({ plugins = { 'render-markdown.nvim' } })
assert(require('render-markdown.state').config.latex.enabled == false)
assert(require('mini.statusline').section_location({ trunc_width = 0 }) == '%l:%v')
assert(vim.fn.maparg('<leader>e', 'n') ~= '')
assert(vim.fn.maparg('<leader>o', 'n') ~= '')
print('PASS Neovim core features, minimal navigation and literal LaTeX')
