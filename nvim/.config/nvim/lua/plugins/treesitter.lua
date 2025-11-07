return {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    -- ✅ 添加这一行，它会自动加载所有 Treesitter 相关的命令
    cmd = { "TSInstall", "TSBufEnable", "TSBufDisable", "TSModuleInfo", "TSEnable", "TSDisable", "TSInstallInfo", "TSUpdate", "TSInstallSync" },
    main = "nvim-treesitter.configs",
    opts = {
        -- 你的配置保持不变
        ensure_installed = { "bash", "c", "diff", "html", "lua", "luadoc", "markdown", "markdown_inline", "query", "vim", "vimdoc" },
        auto_install = true,
        highlight = {
            enable = true,
            additional_vim_regex_highlighting = { "ruby" },
        },
        indent = { enable = true, disable = { "ruby" } },
    },
}
