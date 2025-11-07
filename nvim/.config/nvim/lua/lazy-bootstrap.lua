local lazypath = vim.fn.stdpath 'data' .. '/lazy/lazy.nvim'
if not (vim.uv or vim.loop).fs_stat(lazypath) then
    local lazyrepo = 'https://github.com/folke/lazy.nvim.git'
    local out = vim.fn.system { 'git', 'clone', '--filter=blob:none', '--branch=stable', lazyrepo, lazypath }
    if vim.v.shell_error ~= 0 then
        error('Error cloning lazy.nvim:\n' .. out)
    end
end

local rtp = vim.opt.rtp
rtp:prepend(lazypath)

require('lazy').setup {
    spec = {
        { import = 'plugins' }, -- 自动加载 lua/plugins/ 下的所有模块
    },
    defaults = { lazy = true }, -- 默认懒加载
    performance = {
        cache = { enabled = true },
        reset_packpath = true,
    },
}
