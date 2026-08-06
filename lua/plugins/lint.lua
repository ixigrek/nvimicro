-- lua/plugins/lint.lua
return {
  "mfussenegger/nvim-lint",
  event = { "BufWritePost", "BufReadPost", "InsertLeave" },
  config = function()
    local lint = require("lint")
    lint.linters_by_ft = {
      python = { "ruff" },
      terraform = { "tflint" },
      ["terraform-vars"] = { "tflint" },
      yaml = { "yamllint" },
      ["yaml.ansible"] = { "ansible_lint" },
      javascript = { "eslint" },
      typescript = { "eslint" },
      javascriptreact = { "eslint" },
      typescriptreact = { "eslint" },
    }

    vim.api.nvim_create_autocmd({ "BufWritePost", "BufReadPost", "InsertLeave" }, {
      group = vim.api.nvim_create_augroup("nvimicro_lint", { clear = true }),
      callback = function()
        lint.try_lint()
      end,
    })
  end,
}
