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
      sh = { "shellcheck" },
      bash = { "shellcheck" },
      dockerfile = { "hadolint" },
      javascript = { "eslint" },
      typescript = { "eslint" },
      javascriptreact = { "eslint" },
      typescriptreact = { "eslint" },
    }

    -- nvim-lint ships tflint as `--recursive` from Neovim's cwd, and its parser
    -- keeps only issues whose path equals the buffer's path relative to that
    -- same cwd. Open a .tf from anywhere else -- which fzf-lua and neo-tree
    -- invite -- and every issue is discarded; open Neovim at a monorepo root and
    -- tflint walks the whole tree. Pin the process to the buffer's own Terraform
    -- root instead, and match on absolute paths.
    local tflint_severity = {
      warning = vim.diagnostic.severity.WARN,
      ["error"] = vim.diagnostic.severity.ERROR,
      notice = vim.diagnostic.severity.INFO,
    }

    lint.linters.tflint = function()
      local linter = vim.deepcopy(require("lint.linters.tflint"))
      local fname = vim.api.nvim_buf_get_name(0)

      if fname ~= "" then
        linter.cwd = vim.fs.root(fname, { ".tflint.hcl", ".terraform" }) or vim.fs.dirname(fname)
      end

      linter.parser = function(output, bufnr, linter_cwd)
        local issues = (vim.json.decode(output) or {}).issues or {}
        local buf_path = vim.fs.normalize(vim.api.nvim_buf_get_name(bufnr))
        local diagnostics = {}

        for _, issue in ipairs(issues) do
          local path = issue.range.filename
          if not vim.startswith(path, "/") then
            path = (linter_cwd or vim.fn.getcwd()) .. "/" .. path
          end
          if vim.fs.normalize(path) == buf_path then
            table.insert(diagnostics, {
              lnum = assert(tonumber(issue.range.start.line)),
              end_lnum = assert(tonumber(issue.range["end"].line)),
              col = assert(tonumber(issue.range.start.column)),
              end_col = assert(tonumber(issue.range["end"].column)),
              severity = tflint_severity[issue.rule.severity],
              source = "tflint",
              message = string.format(
                "%s (%s)\nReference: %s",
                issue.message,
                issue.rule.name,
                issue.rule.link
              ),
            })
          end
        end

        return diagnostics
      end

      return linter
    end

    vim.api.nvim_create_autocmd({ "BufWritePost", "BufReadPost", "InsertLeave" }, {
      group = vim.api.nvim_create_augroup("nvimicro_lint", { clear = true }),
      callback = function()
        -- A linter absent from $PATH raises ENOENT out of try_lint. This distro
        -- installs no binaries, so that is an ordinary state: skip quietly
        -- rather than throw a traceback on every write.
        pcall(lint.try_lint, nil, { ignore_errors = true })
      end,
    })

    -- The BufReadPost that lazy-loads this plugin has already fired by the time
    -- the autocmd above exists, so the very first buffer opened would never be
    -- linted. Catch up on every buffer already listed.
    --
    -- pcall because a linter binary that is not installed raises ENOENT out of
    -- try_lint, and this distro installs no binaries of its own -- an absent
    -- linter is an ordinary state, not an error, and must not abort the loop
    -- for every other buffer.
    vim.schedule(function()
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buflisted then
          pcall(vim.api.nvim_buf_call, buf, function()
            lint.try_lint(nil, { ignore_errors = true })
          end)
        end
      end
    end)
  end,
}
