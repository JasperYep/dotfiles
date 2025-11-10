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
        dependencies = {
            -- 核心工具安装与管理
            { "mason-org/mason.nvim", opts = {} },
            "mason-org/mason-lspconfig.nvim",
            "WhoIsSethDaniel/mason-tool-installer.nvim",

            -- 状态指示器
            { "j-hui/fidget.nvim", opts = {} },

            -- 增强 LSP capabilities，与补全插件协同
            "saghen/blink.cmp",
        },
        config = function()
            -- 辅助函数：更容易地创建 LSP 缓冲区本地映射
            local map = function(keys, func, desc, mode)
                mode = mode or "n"
                vim.keymap.set(mode, keys, func, { buffer = true, desc = "LSP: " .. desc })
            end

            -- LSP 附加事件 (LspAttach) 自动命令
            vim.api.nvim_create_autocmd("LspAttach", {
                group = vim.api.nvim_create_augroup("custom-lsp-attach", { clear = true }),
                callback = function(event)
                    -- 通用 LSP 快捷键映射 (保持您原有的优秀映射)
                    map("grn", vim.lsp.buf.rename, "[R]e[n]ame")
                    map("gra", vim.lsp.buf.code_action, "[G]oto Code [A]ction", { "n", "x" })
                    map("grr", require("telescope.builtin").lsp_references, "[G]oto [R]eferences")
                    map("gri", require("telescope.builtin").lsp_implementations, "[G]oto [I]mplementation")
                    map("grd", require("telescope.builtin").lsp_definitions, "[G]oto [D]efinition")
                    map("grD", vim.lsp.buf.declaration, "[G]oto [D]eclaration")
                    map("gO", require("telescope.builtin").lsp_document_symbols, "Open Document Symbols")
                    map("gW", require("telescope.builtin").lsp_dynamic_workspace_symbols, "Open Workspace Symbols")
                    map("grt", require("telescope.builtin").lsp_type_definitions, "[G]oto [T]ype Definition")

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
                            buffer = event.buf,
                            group = highlight_augroup,
                            callback = vim.lsp.buf.document_highlight,
                        })

                        vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
                            buffer = event.buf,
                            group = highlight_augroup,
                            callback = vim.lsp.buf.clear_references,
                        })

                        vim.api.nvim_create_autocmd("LspDetach", {
                            group = vim.api.nvim_create_augroup("custom-lsp-detach", { clear = true }),
                            callback = function(event2)
                                vim.lsp.buf.clear_references()
                                vim.api.nvim_clear_autocmds({ group = "custom-lsp-highlight", buffer = event2.buf })
                            end,
                        })
                    end

                    -- 切换 Inlay Hints
                    if client and client_supports_method(client, vim.lsp.protocol.Methods.textDocument_inlayHint, event.buf) then
                        map("<leader>th", function()
                            vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = event.buf }))
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

            -- 确保这些 LSP 服务器和工具被安装
            local ensure_installed = vim.tbl_keys(servers or {})
            vim.list_extend(ensure_installed, {
                "stylua", -- Lua 格式化工具
                "isort", -- Python 导入排序
                "black", -- Python 格式化工具
            })
            require("mason-tool-installer").setup({ ensure_installed = ensure_installed })

            -- 设置 LSP handlers
            require("mason-lspconfig").setup({
                ensure_installed = {}, -- 交给 mason-tool-installer
                automatic_installation = false,
                handlers = {
                    function(server_name)
                        local server = servers[server_name] or {}
                        -- 合并 LSP capabilities
                        server.capabilities = vim.tbl_deep_extend("force", {}, capabilities, server.capabilities or {})
                        require("lspconfig")[server_name].setup(server)
                    end,
                },
            })
        end,
    },
}
