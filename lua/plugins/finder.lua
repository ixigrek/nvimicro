-- lua/plugins/finder.lua
return {
  "ibhagwan/fzf-lua",
  cmd = "FzfLua",
  keys = {
    { "<leader>ff", "<cmd>FzfLua files<CR>", desc = "Find Files" },
    { "<leader>fg", "<cmd>FzfLua live_grep<CR>", desc = "Live Grep" },
    { "<leader>fb", "<cmd>FzfLua buffers<CR>", desc = "Find Buffers" },
    { "<leader>fh", "<cmd>FzfLua help_tags<CR>", desc = "Help Tags" },
    { "<leader>fo", "<cmd>FzfLua oldfiles<CR>", desc = "Recent Files" },
    { "<leader>fr", "<cmd>FzfLua resume<CR>", desc = "Resume Last Picker" },
    -- Fuzzy-searchable counterparts to the native gO / <leader>q.
    { "<leader>fs", "<cmd>FzfLua lsp_document_symbols<CR>", desc = "Document Symbols" },
    { "<leader>fS", "<cmd>FzfLua lsp_live_workspace_symbols<CR>", desc = "Workspace Symbols" },
    { "<leader>fd", "<cmd>FzfLua diagnostics_document<CR>", desc = "Buffer Diagnostics" },
    { "<leader>fD", "<cmd>FzfLua diagnostics_workspace<CR>", desc = "Workspace Diagnostics" },
    { "<leader>gs", "<cmd>FzfLua git_status<CR>", desc = "Git Status" },
    { "<leader>gc", "<cmd>FzfLua git_commits<CR>", desc = "Git Commits" },
  },
  opts = {},
}
