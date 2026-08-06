-- lua/config/keymaps.lua
local map = vim.keymap.set

map("n", "<Esc>", "<cmd>nohlsearch<CR>")
-- goto_prev/goto_next are deprecated, slated for removal in 0.13
map("n", "[d", function() vim.diagnostic.jump({ count = -1, float = true }) end, { desc = "Previous diagnostic" })
map("n", "]d", function() vim.diagnostic.jump({ count = 1, float = true }) end, { desc = "Next diagnostic" })
map("n", "<leader>q", vim.diagnostic.setloclist, { desc = "Diagnostics to loclist" })

map("n", "<C-h>", "<C-w><C-h>", { desc = "Move focus left window" })
map("n", "<C-l>", "<C-w><C-l>", { desc = "Move focus right window" })
map("n", "<C-j>", "<C-w><C-j>", { desc = "Move focus lower window" })
map("n", "<C-k>", "<C-w><C-k>", { desc = "Move focus upper window" })
