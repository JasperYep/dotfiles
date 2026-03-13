return {
    "nvim-tree/nvim-tree.lua",
    version = "*",
    cmd = { "NvimTreeToggle", "NvimTreeFindFile", "NvimTreeFindFileToggle" },
    dependencies = {
        "nvim-tree/nvim-web-devicons",
    },
    keys = {
        {
            "<leader>e",
            "<cmd>NvimTreeFindFileToggle<cr>",
            desc = "Toggle [E]xplorer",
        },
    },
    config = function()
        require("nvim-tree").setup({
            actions = {
                open_file = {
                    quit_on_open = true,
                },
            },
            update_focused_file = {
                enable = true,
                update_root = true,
            },
            view = {
                preserve_window_proportions = true,
                width = 32,
            },
        })
    end,
}
