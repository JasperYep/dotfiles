local theme = vim.fn.expand("~/.config/theme/current/nvim/colorscheme.lua")
local uv = vim.uv or vim.loop

if uv.fs_stat(theme) then
    local ok, spec = pcall(dofile, theme)
    if ok and type(spec) == "table" then
        return spec
    end
end

return {
    "catppuccin/nvim",
    name = "catppuccin",
    lazy = false,
    priority = 1000,
    config = function()
        vim.o.background = "light"
        require("catppuccin").setup({
            flavour = "latte",
            transparent_background = true,
            float = { transparent = true },
        })
        vim.cmd.colorscheme("catppuccin-latte")
    end,
}
