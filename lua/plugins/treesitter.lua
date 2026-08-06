-- lua/plugins/treesitter.lua
return {
  "nvim-treesitter/nvim-treesitter",
  build = ":TSUpdate",
  event = { "BufReadPost", "BufNewFile" },
  opts = {
    ensure_installed = {
      "lua", "vim", "vimdoc",
      "python", "rust", "go", "gomod", "gowork",
      "terraform", "hcl",
      "yaml", "helm",
      "dockerfile", "bash",
      "json", "toml", "markdown", "markdown_inline",
      "javascript", "typescript", "tsx", "html", "css",
    },
    auto_install = false,
    highlight = { enable = true },
    indent = { enable = true },
  },
  config = function(_, opts)
    require("nvim-treesitter.configs").setup(opts)
  end,
}
