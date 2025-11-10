vim.g.mapleader = " " -- 或者你喜欢的任何键，比如 ";"
vim.g.maplocalleader = " "

-- 禁用Neovim原生的s键功能，以防和mini surround冲突
vim.keymap.set({ "n", "x" }, "s", "<Nop>", { silent = true, desc = "Disable 's' for mini.surround" })

-- 将 <leader>r 映射为重新加载配置
vim.keymap.set("n", "<leader>r", function()
    -- 先保存当前文件（如果已修改）
    vim.cmd("w")
    -- 重新加载 init.lua
    vim.cmd("source %")
    -- 打印一条提示信息，告诉你配置已重载
    print("Configuration reloaded!")
end, { desc = "Reload configuration" })

-- [[ Basic Keymaps ]]
--  See `:help vim.keymap.set()`
vim.keymap.set({ "n", "x" }, "J", "5j", { desc = "move 5 line down" })
vim.keymap.set({ "n", "x" }, "K", "5k", { desc = "move 5 line up" })
-- Clear highlights on search when pressing <Esc> in normal mode
--  See `:help hlsearch`
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>")

-- Diagnostic keymaps
vim.keymap.set("n", "<leader>q", vim.diagnostic.setloclist, { desc = "Open diagnostic [Q]uickfix list" })

-- Exit terminal mode in the builtin terminal with a shortcut that is a bit easier
-- for people to discover. Otherwise, you normally need to press <C-\><C-n>, which
-- is not what someone will guess without a bit more experience.
--
-- NOTE: This won't work in all terminal emulators/tmux/etc. Try your own mapping
-- or just use <C-\><C-n> to exit terminal mode
vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })

-- TIP: Disable arrow keys in normal mode
vim.keymap.set("n", "<left>", '<cmd>echo "Use h to move!!"<CR>')
vim.keymap.set("n", "<right>", '<cmd>echo "Use l to move!!"<CR>')
vim.keymap.set("n", "<up>", '<cmd>echo "Use k to move!!"<CR>')
vim.keymap.set("n", "<down>", '<cmd>echo "Use j to move!!"<CR>')

-- Keybinds to make split navigation easier.
--  Use CTRL+<hjkl> to switch between windows
--
--  See `:help wincmd` for a list of all window commands
vim.keymap.set("n", "<C-h>", "<C-w><C-h>", { desc = "Move focus to the left window" })
vim.keymap.set("n", "<C-l>", "<C-w><C-l>", { desc = "Move focus to the right window" })
vim.keymap.set("n", "<C-j>", "<C-w><C-j>", { desc = "Move focus to the lower window" })
vim.keymap.set("n", "<C-k>", "<C-w><C-k>", { desc = "Move focus to the upper window" })

vim.keymap.set("n", "<C-s>", ":w<CR>", { desc = "[S]ave" })
vim.keymap.set("n", "<leader>bd", ":bd<CR>", { desc = "[B]uffer [D]elete" })

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
-- 创建一个变量来保存终端缓冲区ID，以便复用
local term_buf = nil

local function toggle_floating_terminal()
    -- 检查是否已经存在一个悬浮终端窗口
    local win_found = false
    for _, win in ipairs(vim.api.nvim_list_wins()) do
        local config = vim.api.nvim_win_get_config(win)
        -- 检查是否是浮动窗口，并且显示的是我们的终端缓冲区
        if config.relative == "editor" and vim.api.nvim_win_get_buf(win) == term_buf then
            win_found = true
            -- 如果找到了，就关闭它
            vim.api.nvim_win_close(win, true)
            break
        end
    end

    -- 如果找到了窗口并已关闭，或者本来就找不到，函数就结束
    if win_found then
        return
    end

    -- --- 如果没找到窗口，就创建一个 ---

    -- 1. 检查终端缓冲区是否存在，如果不存在就创建它
    if not term_buf or not vim.api.nvim_buf_is_valid(term_buf) then
        term_buf = vim.api.nvim_create_buf(false, true) -- false: 不列出, true: 是scratch buffer
    end

    -- 2. 获取编辑器尺寸，用于计算居中位置
    local ui = vim.api.nvim_list_uis()[1]
    local width = math.floor(ui.width * 0.4)
    local height = math.floor(ui.height * 0.3) -- 高度稍微小一点
    local col = math.floor((ui.width - width) / 2)
    local row = ui.height - height - 6

    -- 3. 创建浮动窗口，并将我们的终端缓冲区显示在里面
    local win = vim.api.nvim_open_win(term_buf, true, {
        relative = "editor",
        width = width,
        height = height,
        col = col,
        row = row,
        border = "rounded",
        style = "minimal",
    })
    -- 4. 检查这个缓冲区是否已经是终端了
    if vim.bo[term_buf].buftype ~= "terminal" then
        -- 如果不是，就在这个缓冲区里启动终端
        -- vim.cmd.term() 会在当前窗口（也就是我们的浮动窗口）的当前缓冲区里启动终端
        vim.cmd.term()
        -- 将新创建的终端进程的缓冲区ID保存下来
        term_buf = vim.api.nvim_get_current_buf()
    end

    -- 5. 进入终端插入模式，方便直接输入
    vim.cmd("startinsert")
end

-- 设置快捷键，比如 <leader>ft (floating terminal)
vim.keymap.set("n", "<leader>ft", toggle_floating_terminal, { desc = "Toggle Floating Terminal" })

-- 可选：在终端模式下设置快捷键，让它更易用
-- 例如，在终端模式下按 <Esc> 或 jk 返回普通模式
vim.api.nvim_create_autocmd("TermOpen", {
    pattern = "*",
    callback = function()
        local opts = { buffer = 0 }
        vim.keymap.set("t", "<Esc>", "<C-\\><C-n>", opts)
        vim.keymap.set("t", "jk", "<C-\\><C-n>", opts)
    end,
})
