-- lua/plugins/format.lua
return {
  "stevearc/conform.nvim",
  event = { "BufWritePre" },
  cmd = { "ConformInfo", "FormatDisable", "FormatEnable" },
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
    -- `lsp_fallback` is deprecated upstream in favour of `lsp_format`.
    -- A function (rather than a table) so format-on-save can be switched off
    -- per buffer or globally for repos whose style this distro would fight.
    format_on_save = function(bufnr)
      if vim.g.nvimicro_disable_autoformat or vim.b[bufnr].nvimicro_disable_autoformat then
        return nil
      end
      return { timeout_ms = 1000, lsp_format = "fallback" }
    end,
    -- The no-binaries contract (CLAUDE.md) requires every code path that
    -- shells out to degrade silently when the binary is absent. conform's
    -- own default (notify_no_formatters = true) violates that: it posts a
    -- WARN vim.notify the first time a filetype's configured formatter is
    -- missing from $PATH (once per filetype per session, guarded by an
    -- internal flag -- not on every write, but still a notification this
    -- contract says shouldn't exist). Disable it here, for the whole table,
    -- not just the entries this task adds.
    notify_no_formatters = false,
    formatters_by_ft = {
      python = { "ruff_format" },
      rust = { "rustfmt" },
      -- goimports is gofmt plus import fixing, so running both is redundant.
      -- gofmt stays as a fallback only: it ships with the Go distribution and
      -- is always present, whereas goimports has to be installed separately.
      go = { "goimports", "gofmt", stop_after_first = true },
      terraform = { "terraform_fmt" },
      ["terraform-vars"] = { "terraform_fmt" },
      yaml = { "yamlfmt" },
      ["yaml.ansible"] = { "yamlfmt" },
      lua = { "stylua" },
      sh = { "shfmt" },
      bash = { "shfmt" },
      javascript = { "prettier" },
      typescript = { "prettier" },
      javascriptreact = { "prettier" },
      typescriptreact = { "prettier" },
      json = { "prettier" },
      jsonc = { "prettier" },
      html = { "prettier" },
      css = { "prettier" },
      markdown = { "prettier" },
    },
  },
  config = function(_, opts)
    require("conform").setup(opts)

    -- `:FormatDisable` affects the current buffer, `:FormatDisable!` everything.
    vim.api.nvim_create_user_command("FormatDisable", function(args)
      if args.bang then
        vim.g.nvimicro_disable_autoformat = true
      else
        vim.b.nvimicro_disable_autoformat = true
      end
    end, { desc = "Disable format-on-save (! = globally)", bang = true })

    vim.api.nvim_create_user_command("FormatEnable", function()
      vim.b.nvimicro_disable_autoformat = false
      vim.g.nvimicro_disable_autoformat = false
    end, { desc = "Re-enable format-on-save" })
  end,
}
