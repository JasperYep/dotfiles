vim.g.mapleader = " " -- 或者你喜欢的任何键，比如 ";"
vim.g.maplocalleader = " "

-- 连续缩进，保持 V-line 模式
vim.keymap.set("v", ">", ">gv", { silent = true, desc = "Indent and keep selection" })
vim.keymap.set("v", "<", "<gv", { silent = true, desc = "Outdent and keep selection" })
vim.keymap.set("i", "jk", "<Esc>", { silent = true, desc = "Exit insert mode" })

-- 将 <leader>r 映射为重新加载配置
local function reload_config()
    for module in pairs(package.loaded) do
        if module == "core" or module:match("^core%.") then
            package.loaded[module] = nil
        end
    end

    dofile(vim.fn.stdpath("config") .. "/init.lua")
end

vim.keymap.set("n", "<leader>r", reload_config, { desc = "Reload Neovim config" })

-- [[ Basic Keymaps ]]
--  See `:help vim.keymap.set()`
vim.keymap.set({ "n", "x" }, "J", "5j", { desc = "Move 5 lines down" })
vim.keymap.set({ "n", "x" }, "K", "5k", { desc = "Move 5 lines up" })
-- Clear highlights on search when pressing <Esc> in normal mode
--  See `:help hlsearch`
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>")

-- Diagnostic keymaps
vim.keymap.set("n", "<leader>q", vim.diagnostic.setloclist, { desc = "Open diagnostic [Q]uickfix list" })
vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, { desc = "Previous diagnostic" })
vim.keymap.set("n", "]d", vim.diagnostic.goto_next, { desc = "Next diagnostic" })
vim.keymap.set("n", "gl", vim.diagnostic.open_float, { desc = "Line diagnostics" })

-- Exit terminal mode in the builtin terminal with a shortcut that is a bit easier
-- for people to discover. Otherwise, you normally need to press <C-\><C-n>, which
-- is not what someone will guess without a bit more experience.
--
-- NOTE: This won't work in all terminal emulators/tmux/etc. Try your own mapping
-- or just use <C-\><C-n> to exit terminal mode
vim.keymap.set("t", "jk", "<C-\\><C-n>", { silent = true, desc = "Exit terminal mode" })

-- -- TIP: Disable arrow keys in normal mode
-- vim.keymap.set("n", "<left>", '<cmd>echo "Use h to move!!"<CR>')
-- vim.keymap.set("n", "<right>", '<cmd>echo "Use l to move!!"<CR>')
-- vim.keymap.set("n", "<up>", '<cmd>echo "Use k to move!!"<CR>')
-- vim.keymap.set("n", "<down>", '<cmd>echo "Use j to move!!"<CR>')

-- Keybinds to make split navigation easier.
--  Use CTRL+<hjkl> to switch between windows
--
--  See `:help wincmd` for a list of all window commands
vim.keymap.set("n", "<C-h>", "<C-w><C-h>", { desc = "Move focus to the left window" })
vim.keymap.set("n", "<C-l>", "<C-w><C-l>", { desc = "Move focus to the right window" })
vim.keymap.set("n", "<C-j>", "<C-w><C-j>", { desc = "Move focus to the lower window" })
vim.keymap.set("n", "<C-k>", "<C-w><C-k>", { desc = "Move focus to the upper window" })
vim.keymap.set("t", "<C-g>h", "<C-\\><C-n><C-w>h", { silent = true, desc = "Move focus to the left window" })
vim.keymap.set("t", "<C-g>l", "<C-\\><C-n><C-w>l", { silent = true, desc = "Move focus to the right window" })
vim.keymap.set("t", "<C-g>j", "<C-\\><C-n><C-w>j", { silent = true, desc = "Move focus to the lower window" })
vim.keymap.set("t", "<C-g>k", "<C-\\><C-n><C-w>k", { silent = true, desc = "Move focus to the upper window" })

vim.keymap.set("n", "<C-s>", ":w<CR>", { desc = "[S]ave" })
vim.keymap.set("n", "[b", "<cmd>bprevious<CR>", { desc = "Previous buffer" })
vim.keymap.set("n", "]b", "<cmd>bnext<CR>", { desc = "Next buffer" })

local function delete_current_buffer()
    local current = vim.api.nvim_get_current_buf()
    local listed_buffers = vim.fn.getbufinfo({ buflisted = 1 })

    if #listed_buffers > 1 then
        vim.cmd.bprevious()
    else
        vim.cmd.enew()
    end

    if vim.api.nvim_buf_is_valid(current) then
        vim.api.nvim_buf_delete(current, { force = false })
    end
end

vim.keymap.set("n", "<leader>bd", delete_current_buffer, { desc = "[B]uffer [D]elete" })

-- 调整窗口大小的快捷键
vim.keymap.set("n", "<C-M-Left>", "<C-w><", { desc = "Decrease window width" })
vim.keymap.set("n", "<C-M-Right>", "<C-w>>", { desc = "Increase window width" })
vim.keymap.set("n", "<C-M-Down>", "<C-w>-", { desc = "Decrease window height" })
vim.keymap.set("n", "<C-M-Up>", "<C-w>+", { desc = "Increase window height" })
--
-- NOTE: Some terminals have colliding keymaps or are not able to send distinct keycodes
-- vim.keymap.set("n", "<C-S-h>", "<C-w>H", { desc = "Move window to the left" })
-- vim.keymap.set("n", "<C-S-l>", "<C-w>L", { desc = "Move window to the right" })
-- vim.keymap.set("n", "<C-S-j>", "<C-w>J", { desc = "Move window to the lower" })
-- vim.keymap.set("n", "<C-S-k>", "<C-w>K", { desc = "Move window to the upper" })

-- NOTE: 浮动Terminal
-- 使用两个独立的终端缓冲区：一个用于普通shell，一个用于Claude Code。
local terminal_buffers = {}

local function terminal_job_is_running(buf)
    if not buf or not vim.api.nvim_buf_is_valid(buf) then
        return false
    end

    local job_id = vim.b[buf].terminal_job_id
    return job_id ~= nil and vim.fn.jobwait({ job_id }, 0)[1] == -1
end

local function close_floating_terminal(buf)
    if not buf or not vim.api.nvim_buf_is_valid(buf) then
        return false
    end

    for _, win in ipairs(vim.api.nvim_list_wins()) do
        local config = vim.api.nvim_win_get_config(win)
        if config.relative == "editor" and vim.api.nvim_win_get_buf(win) == buf then
            vim.api.nvim_win_close(win, true)
            return true
        end
    end

    return false
end

local function toggle_floating_terminal(kind, command)
    local term_buf = terminal_buffers[kind]

    if close_floating_terminal(term_buf) then
        return
    end

    -- 进程已经退出时，重新打开快捷键应启动一个新的终端。
    if term_buf and vim.api.nvim_buf_is_valid(term_buf) and vim.bo[term_buf].buftype == "terminal" then
        if not terminal_job_is_running(term_buf) then
            vim.api.nvim_buf_delete(term_buf, { force = true })
            term_buf = nil
        end
    end

    if not term_buf or not vim.api.nvim_buf_is_valid(term_buf) then
        term_buf = vim.api.nvim_create_buf(false, true)
        terminal_buffers[kind] = term_buf
    end

    local ui = vim.api.nvim_list_uis()[1]
    local is_claude = kind == "claude"
    local width = math.max(1, math.floor(ui.width * (is_claude and 0.82 or 0.45)))
    local height = math.max(1, math.floor(ui.height * (is_claude and 0.80 or 0.30)))
    local col = math.floor((ui.width - width) / 2)
    local row = math.floor((ui.height - height) / 2)

    local win = vim.api.nvim_open_win(term_buf, true, {
        relative = "editor",
        width = width,
        height = height,
        col = col,
        row = row,
        border = "rounded",
        style = "minimal",
    })

    vim.wo[win].number = false
    vim.wo[win].relativenumber = false
    vim.wo[win].signcolumn = "no"
    vim.wo[win].wrap = false
    vim.bo[term_buf].bufhidden = "hide"

    if vim.bo[term_buf].buftype ~= "terminal" then
        local job_id = vim.fn.termopen(command or vim.o.shell, { cwd = vim.fn.getcwd() })
        if job_id <= 0 then
            vim.api.nvim_win_close(win, true)
            vim.notify("Unable to start terminal process", vim.log.levels.ERROR)
            return
        end
    end

    vim.cmd("startinsert")
end

local function toggle_claude_code()
    if vim.fn.executable("claude") ~= 1 then
        vim.notify("Claude Code executable not found: claude", vim.log.levels.ERROR)
        return
    end

    toggle_floating_terminal("claude", vim.fn.exepath("claude"))
end

vim.api.nvim_create_user_command("Claude", toggle_claude_code, {
    desc = "Open Claude Code in a floating terminal",
    force = true,
})

-- <leader>ft: 普通shell；<leader>fc: Claude Code。
vim.keymap.set("n", "<leader>ft", function()
    toggle_floating_terminal("shell")
end, { desc = "Toggle Floating Terminal" })
vim.keymap.set("n", "<leader>fc", toggle_claude_code, { desc = "Open Claude Code" })

local git_diff_buf = nil
local git_diff_win = nil

local function close_git_diff()
    if git_diff_win and vim.api.nvim_win_is_valid(git_diff_win) then
        vim.api.nvim_win_close(git_diff_win, true)
    end

    if git_diff_buf and vim.api.nvim_buf_is_valid(git_diff_buf) then
        vim.api.nvim_buf_delete(git_diff_buf, { force = true })
    end

    git_diff_win = nil
    git_diff_buf = nil
end

local function show_git_diff()
    if git_diff_win and vim.api.nvim_win_is_valid(git_diff_win) then
        close_git_diff()
        return
    end

    close_git_diff()

    vim.system({ "git", "-C", vim.fn.getcwd(), "diff", "--no-ext-diff", "HEAD", "--" }, { text = true }, function(result)
        vim.schedule(function()
            if result.code ~= 0 then
                local message = vim.trim(result.stderr or "Not a Git repository")
                vim.notify(message, vim.log.levels.ERROR)
                return
            end

            if result.stdout == "" then
                vim.notify("No tracked changes compared with HEAD", vim.log.levels.INFO)
                return
            end

            local buf = vim.api.nvim_create_buf(false, true)
            local lines = vim.split(result.stdout, "\n", { plain = true })
            if lines[#lines] == "" then
                table.remove(lines)
            end
            vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
            vim.bo[buf].buftype = "nofile"
            vim.bo[buf].bufhidden = "wipe"
            vim.bo[buf].filetype = "diff"
            vim.bo[buf].modifiable = false
            vim.bo[buf].swapfile = false

            local ui = vim.api.nvim_list_uis()[1]
            local width = math.max(1, math.floor(ui.width * 0.92))
            local height = math.max(1, math.floor(ui.height * 0.86))
            local win = vim.api.nvim_open_win(buf, true, {
                relative = "editor",
                width = width,
                height = height,
                col = math.floor((ui.width - width) / 2),
                row = math.floor((ui.height - height) / 2),
                border = "rounded",
                style = "minimal",
            })

            git_diff_buf = buf
            git_diff_win = win
            vim.wo[win].number = false
            vim.wo[win].relativenumber = false
            vim.wo[win].signcolumn = "no"
            vim.wo[win].wrap = false

            local close = function()
                close_git_diff()
            end
            vim.keymap.set("n", "q", close, { buffer = buf, desc = "Close Git diff" })
            vim.keymap.set("n", "<Esc>", close, { buffer = buf, desc = "Close Git diff" })
        end)
    end)
end

vim.api.nvim_create_user_command("GitDiff", show_git_diff, {
    desc = "Show tracked changes compared with HEAD",
    force = true,
})
vim.keymap.set("n", "<leader>gW", show_git_diff, { desc = "[G]it [W]orktree diff" })
