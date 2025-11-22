return {
    -- Highlight todo, notes, etc in comments
    { "folke/todo-comments.nvim", event = "VimEnter", dependencies = { "nvim-lua/plenary.nvim" }, opts = { signs = false } },

    { -- Collection of various small independent plugins/modules
        -- "echasnovski/mini.nvim",
        "nvim-mini/mini.nvim",
        -- 为了让 statusline 在启动时立即可见，设置 lazy=false 和高优先级
        lazy = false,
        priority = 1000,
        dependencies = { "nvim-tree/nvim-web-devicons" },
        config = function()
            -- 确保宏录制的状态栏 AutoCmd 组 ID 可以在所有 AutoCmd 中使用
            local macro_augroup = vim.api.nvim_create_augroup("MiniStatuslineMacro", { clear = true })

            -- 创建按键显示的 augroup
            local keys_augroup = vim.api.nvim_create_augroup("MiniStatuslineKeys", { clear = true })

            -- 初始化按键序列变量
            vim.g.keys_sequence = ""

            -- Better Around/Inside textobjects
            require("mini.ai").setup({ n_lines = 500 })

            -- Add/delete/replace surroundings (brackets, quotes, etc.)
            require("mini.surround").setup()

            -- Statusline - 宏录制状态 AutoCmds
            vim.api.nvim_create_autocmd("RecordingEnter", {
                group = macro_augroup,
                pattern = "*",
                callback = function()
                    vim.g.macro_recording = "Recording @" .. vim.fn.reg_recording()
                    vim.cmd("redrawstatus")
                end,
            })

            vim.api.nvim_create_autocmd("RecordingLeave", {
                group = macro_augroup,
                pattern = "*",
                callback = function()
                    vim.g.macro_recording = ""
                    vim.cmd("redrawstatus")
                end,
            })

            -- 按键显示 AutoCmds
            vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
                group = keys_augroup,
                pattern = "*",
                callback = function()
                    -- 清空按键序列
                    vim.g.keys_sequence = ""
                    vim.cmd("redrawstatus")
                end,
            })

            -- 捕获按键
            vim.on_key(function(key)
                -- 忽略特殊键
                if key:find("<") then
                    return
                end

                -- 更新按键序列
                local current_sequence = vim.g.keys_sequence or ""
                vim.g.keys_sequence = current_sequence .. key

                -- 限制序列长度
                if #vim.g.keys_sequence > 10 then
                    vim.g.keys_sequence = vim.g.keys_sequence:sub(-10)
                end

                vim.cmd("redrawstatus")
            end)

            local statusline = require("mini.statusline")
            -- set use_icons to true if you have a Nerd Font
            statusline.setup({
                use_icons = vim.g.have_nerd_font,

                content = {
                    active = function()
                        -- ⭐️ 修正：将 statusline 赋给一个局部变量，方便调用
                        local msl = statusline

                        -- 获取其他内置组件
                        -- ⭐️ 修正：使用 msl (statusline) 局部变量来访问内置函数
                        local mode, mode_hl = msl.section_mode({ trunc_width = 120 })
                        local filename = msl.section_filename({ trunc_width = 140 })
                        local fileinfo = msl.section_fileinfo({ trunc_width = 120 })
                        local location = msl.section_location({ trunc_width = 200 })

                        -- ⭐️ 关键：获取宏录制状态
                        local macro = vim.g.macro_recording or ""

                        -- ⭐️ 新增：获取按键序列
                        local keys = vim.g.keys_sequence or ""

                        -- ⭐️ 修正：使用 msl (statusline) 局部变量来访问 combine_groups
                        return msl.combine_groups({
                            { hl = mode_hl, strings = { mode } },
                            -- ... 其他左侧分组 (例如 git, diff, diagnostics) ...
                            "%<", -- 标记左侧截断点
                            { hl = "MiniStatuslineFilename", strings = { filename } },
                            "%=", -- End left alignment

                            -- ⭐️ 关键：将宏录制状态添加到中间或右侧合适的位置
                            { hl = "MiniStatuslineInfo", strings = { macro } },

                            -- ⭐️ 新增：在右侧显示按键序列
                            { hl = "MiniStatuslineDevinfo", strings = { keys } },
                            { hl = "MiniStatuslineFileinfo", strings = { fileinfo } },
                            { hl = mode_hl, strings = { location } },
                        })
                    end,
                },
            })

            -- You can configure sections in the statusline by overriding their
            -- default behavior. For example, here we set the section for
            -- cursor location to LINE:COLUMN
            ---@diagnostic disable-next-line: duplicate-set-field
            statusline.section_location = function()
                return "%2l:%-2v"
            end
        end,
    },
}
