return {
    "nvim-tree/nvim-tree.lua",
    version = "*",
    lazy = false,
    dependencies = {
        "nvim-tree/nvim-web-devicons",
    },
    keys = {
        {
            "<leader>e",
            function()
                vim.cmd("NvimTreeToggle")
            end,
            desc = "[E]xplorer Toggle",
        },
    },
    config = function()
        require("nvim-tree").setup({})
    end,
}
