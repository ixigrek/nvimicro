-- lua/config/keymaps.lua
local map = vim.keymap.set

map("n", "<Esc>", "<cmd>nohlsearch<CR>")
map("n", "[d", vim.diagnostic.goto_prev, { desc = "Previous diagnostic" })
map("n", "]d", vim.diagnostic.goto_next, { desc = "Next diagnostic" })
map("n", "<leader>q", vim.diagnostic.setloclist, { desc = "Diagnostics to loclist" })

map("n", "<C-h>", "<C-w><C-h>", { desc = "Move focus left window" })
map("n", "<C-l>", "<C-w><C-l>", { desc = "Move focus right window" })
map("n", "<C-j>", "<C-w><C-j>", { desc = "Move focus lower window" })
map("n", "<C-k>", "<C-w><C-k>", { desc = "Move focus upper window" })
