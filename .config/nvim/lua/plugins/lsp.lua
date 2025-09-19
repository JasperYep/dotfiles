return {
  "neovim/nvim-lspconfig",
  opts = function()
    local keys = require("lazyvim.plugins.lsp.keymaps").get()

    -- 禁用默认的 K 键映射
    keys[#keys + 1] = { "K", false }

    -- 将 hover 功能映射到 gh
    keys[#keys + 1] = { "gh", vim.lsp.buf.hover, { desc = "Hover Documentation" } }
  end,
}
