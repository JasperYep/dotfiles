local theme = vim.fn.expand("~/.config/theme/current/nvim/colorscheme.lua")
local uv = vim.uv or vim.loop

if uv.fs_stat(theme) then
    local ok, spec = pcall(dofile, theme)
    if ok and type(spec) == "table" then
        return spec
    end
end

return {
    "rose-pine/neovim",
    name = "rose-pine",
    lazy = false,
    priority = 1000,
    config = function()
        vim.o.background = "light"
        require("rose-pine").setup({
            variant = "auto",
            dark_variant = "moon",
            styles = { transparency = true },
        })
        vim.cmd.colorscheme("rose-pine")
    end,
}
