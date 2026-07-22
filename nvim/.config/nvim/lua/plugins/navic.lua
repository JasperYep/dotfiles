return {
    "SmiteshP/nvim-navic",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
        highlight = true,
        separator = " > ",
        depth_limit = 5,
        safe_output = true,
        lazy_update_context = true,
        lsp = {
            auto_attach = false,
            preference = nil,
        },
    },
    config = function(_, opts)
        local navic = require("nvim-navic")
        navic.setup(opts)

        local excluded_filetypes = {
            aerial = true,
            help = true,
            lazy = true,
            mason = true,
            NvimTree = true,
            prompt = true,
            TelescopePrompt = true,
        }

        local function build_winbar()
            if vim.bo.buftype ~= "" then
                return ""
            end

            if excluded_filetypes[vim.bo.filetype] then
                return ""
            end

            local filename = vim.fn.expand("%:t")
            if filename == "" then
                filename = "[No Name]"
            end

            if not navic.is_available() then
                return filename
            end

            local location = navic.get_location()
            if location == "" then
                return filename
            end

            return string.format("%s > %s", filename, location)
        end

        _G.custom_winbar = build_winbar
        vim.o.winbar = "%{%v:lua.custom_winbar()%}"
    end,
}
