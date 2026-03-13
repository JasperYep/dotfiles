return {
    -- 1. LSP Plugins and Dependencies
    {
        -- `lazydev` 配置 Lua LSP，用于识别 Neovim API、运行时和插件的类型
        "folke/lazydev.nvim",
        ft = "lua",
        opts = {
            library = {
                -- 为 vim.uv (libuv) 模块加载类型定义
                { path = "${3rd}/luv/library", words = { "vim%.uv" } },
            },
        },
    },
    {
        -- 主要 LSP 配置入口
        "neovim/nvim-lspconfig",
        event = { "BufReadPre", "BufNewFile" },
        cmd = { "LspInfo", "Mason", "MasonInstall", "MasonToolsInstall", "MasonUpdate" },
        keys = {
            { "<leader>pm", "<cmd>Mason<cr>", desc = "[P]ackage [M]anager" },
            { "<leader>pi", "<cmd>MasonToolsInstall<cr>", desc = "[P]ackage [I]nstall tools" },
        },
        dependencies = {
            -- 核心工具安装与管理
            { "mason-org/mason.nvim", opts = {} },
            "WhoIsSethDaniel/mason-tool-installer.nvim",

            -- 状态指示器
            { "j-hui/fidget.nvim", opts = {} },

            -- 增强 LSP capabilities，与补全插件协同
            "saghen/blink.cmp",
        },
        config = function()
            -- LSP 附加事件 (LspAttach) 自动命令
            vim.api.nvim_create_autocmd("LspAttach", {
                group = vim.api.nvim_create_augroup("custom-lsp-attach", { clear = true }),
                callback = function(event)
                    local bufnr = event.buf
                    local map = function(keys, func, desc, mode)
                        vim.keymap.set(mode or "n", keys, func, { buffer = bufnr, desc = desc })
                    end

                    map("gh", vim.lsp.buf.hover, "Hover")
                    map("gd", require("telescope.builtin").lsp_definitions, "Goto Definition")
                    map("gD", vim.lsp.buf.declaration, "Goto Declaration")
                    map("gr", require("telescope.builtin").lsp_references, "Goto References")
                    map("gi", require("telescope.builtin").lsp_implementations, "Goto Implementation")
                    map("gy", require("telescope.builtin").lsp_type_definitions, "Goto Type Definition")
                    map("<leader>rn", vim.lsp.buf.rename, "[R]e[n]ame")
                    map("<leader>ca", vim.lsp.buf.code_action, "[C]ode [A]ction", { "n", "x" })
                    map("<leader>ds", require("telescope.builtin").lsp_document_symbols, "[D]ocument [S]ymbols")
                    map("<leader>ws", require("telescope.builtin").lsp_dynamic_workspace_symbols, "[W]orkspace [S]ymbols")

                    -- 兼容 nvim-0.10 和 nvim-0.11 的方法支持检查函数
                    local client_supports_method = (function()
                        if vim.fn.has("nvim-0.11") == 1 then
                            ---@diagnostic disable-next-line: assign-type-mismatch
                            return function(client, method, bufnr)
                                return client:supports_method(method, bufnr)
                            end
                        else
                            ---@diagnostic disable-next-line: assign-type-mismatch
                            return function(client, method, bufnr)
                                return client.supports_method(method, { bufnr = bufnr })
                            end
                        end
                    end)()

                    local client = vim.lsp.get_client_by_id(event.data.client_id)

                    -- 自动高亮引用
                    if client and client_supports_method(client, vim.lsp.protocol.Methods.textDocument_documentHighlight, event.buf) then
                        local highlight_augroup = vim.api.nvim_create_augroup("custom-lsp-highlight", { clear = false })
                        vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
                            buffer = bufnr,
                            group = highlight_augroup,
                            callback = vim.lsp.buf.document_highlight,
                        })

                        vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
                            buffer = bufnr,
                            group = highlight_augroup,
                            callback = vim.lsp.buf.clear_references,
                        })

                        vim.api.nvim_create_autocmd("LspDetach", {
                            buffer = bufnr,
                            callback = function(event2)
                                vim.lsp.buf.clear_references()
                                vim.api.nvim_clear_autocmds({ group = "custom-lsp-highlight", buffer = event2.buf })
                            end,
                        })
                    end

                    -- 切换 Inlay Hints
                    if client and client_supports_method(client, vim.lsp.protocol.Methods.textDocument_inlayHint, bufnr) then
                        map("<leader>th", function()
                            local enabled = vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr })
                            vim.lsp.inlay_hint.enable(not enabled, { bufnr = bufnr })
                        end, "[T]oggle Inlay [H]ints")
                    end
                end,
            })

            -- 诊断配置 (保持不变)
            vim.diagnostic.config({
                severity_sort = true,
                float = { border = "rounded", source = "if_many" },
                underline = { severity = vim.diagnostic.severity.ERROR },
                signs = vim.g.have_nerd_font and {
                    text = {
                        [vim.diagnostic.severity.ERROR] = "󰅚 ",
                        [vim.diagnostic.severity.WARN] = "󰀪 ",
                        [vim.diagnostic.severity.INFO] = "󰋽 ",
                        [vim.diagnostic.severity.HINT] = "󰌶 ",
                    },
                } or {},
                virtual_text = {
                    source = "if_many",
                    spacing = 2,
                    format = function(diagnostic)
                        -- 仅显示消息本身
                        return diagnostic.message
                    end,
                },
            })

            -- 获取并广播 blink.cmp 增强的能力
            local capabilities = require("blink.cmp").get_lsp_capabilities()
            local executables = {
                clangd = "clangd",
                pyright = "pyright-langserver",
                lua_ls = "lua-language-server",
            }

            -- 您的 LSP 服务器配置：Lua, Python, C/C++
            local servers = {
                -- C/C++ (最受欢迎的 LSP)
                clangd = {},
                -- Python (最受欢迎的 LSP)
                pyright = {},
                -- Lua (您的配置已经有了)
                lua_ls = {
                    settings = {
                        Lua = {
                            completion = {
                                callSnippet = "Replace",
                            },
                            -- 建议在开发 Neovim 配置时保持禁用以下诊断，以避免误报
                            -- diagnostics = { disable = { 'missing-fields', 'undefined-field', 'redundant-parameter' } },
                        },
                    },
                },
            }

            require("mason-tool-installer").setup({
                ensure_installed = {
                    "clangd",
                    "pyright",
                    "lua-language-server",
                    "clang-format",
                    "stylua",
                    "isort",
                    "black",
                },
                run_on_start = false,
            })

            for server_name, server in pairs(servers) do
                local executable = executables[server_name]
                server.capabilities = vim.tbl_deep_extend("force", {}, capabilities, server.capabilities or {})

                if executable and vim.fn.executable(executable) == 1 then
                    if vim.fn.has("nvim-0.11") == 1 then
                        vim.lsp.config(server_name, server)
                        vim.lsp.enable(server_name)
                    else
                        require("lspconfig")[server_name].setup(server)
                    end
                end
            end
        end,
    },
}
