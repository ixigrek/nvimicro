-- lua/plugins/format.lua
return {
  "stevearc/conform.nvim",
  event = { "BufWritePre" },
  cmd = "ConformInfo",
  keys = {
    {
      "<leader>cf",
      function()
        require("conform").format({ async = true, lsp_format = "fallback" })
      end,
      desc = "Format Buffer",
    },
  },
  opts = {
    -- `lsp_fallback` is deprecated upstream in favour of `lsp_format`
    format_on_save = { timeout_ms = 1000, lsp_format = "fallback" },
    formatters_by_ft = {
      python = { "ruff_format" },
      rust = { "rustfmt" },
      go = { "gofmt", "goimports" },
      terraform = { "terraform_fmt" },
      ["terraform-vars"] = { "terraform_fmt" },
      yaml = { "yamlfmt" },
      ["yaml.ansible"] = { "yamlfmt" },
      lua = { "stylua" },
      javascript = { "prettier" },
      typescript = { "prettier" },
      javascriptreact = { "prettier" },
      typescriptreact = { "prettier" },
      json = { "prettier" },
      html = { "prettier" },
      css = { "prettier" },
      markdown = { "prettier" },
    },
  },
}
