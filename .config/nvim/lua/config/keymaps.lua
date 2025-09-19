-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
--
local map = vim.keymap.set
map({ "n", "v" }, "K", "5k", { desc = "Up 5 lines", noremap = true })
map({ "n", "v" }, "J", "5j", { desc = "Down 5 lines", noremap = true })
