-- lua/nvimicro/health.lua
--
-- This distro installs no binaries: a missing LSP server, formatter or linter
-- degrades silently by design. That makes absence invisible -- a linter that
-- never ran looks exactly like a clean file. This is the one place where it
-- becomes visible, on demand, via :checkhealth nvimicro.
local M = {}

-- Mirrors the tool tables in README.md. Keep the two in sync.
local groups = {
  {
    name = "Treesitter",
    tools = {
      { bin = "tree-sitter", why = "compiles parsers (nvim-treesitter main branch)" },
    },
  },
  {
    name = "LSP servers",
    tools = {
      { bin = "pyright-langserver", why = "python" },
      { bin = "rust-analyzer", why = "rust" },
      { bin = "gopls", why = "go" },
      { bin = "terraform-ls", why = "terraform" },
      { bin = "ansible-language-server", why = "yaml.ansible" },
      { bin = "helm_ls", why = "helm" },
      { bin = "yaml-language-server", why = "yaml" },
      { bin = "typescript-language-server", why = "javascript, typescript" },
      { bin = "tailwindcss-language-server", why = "html, css, jsx, tsx" },
      { bin = "lua-language-server", why = "lua" },
      { bin = "bash-language-server", why = "sh, bash" },
      { bin = "docker-langserver", why = "dockerfile" },
      { bin = "vscode-json-language-server", why = "json, jsonc" },
    },
  },
  {
    name = "Formatters",
    tools = {
      { bin = "ruff", why = "python (format + lint)" },
      { bin = "rustfmt", why = "rust" },
      { bin = "goimports", why = "go (gofmt fallback is bundled with Go)" },
      { bin = "terraform", why = "terraform fmt" },
      { bin = "yamlfmt", why = "yaml, yaml.ansible" },
      { bin = "stylua", why = "lua" },
      { bin = "prettier", why = "js, ts, json, html, css, markdown" },
      { bin = "shfmt", why = "sh, bash" },
    },
  },
  {
    name = "Linters",
    tools = {
      { bin = "tflint", why = "terraform" },
      { bin = "yamllint", why = "yaml" },
      { bin = "ansible-lint", why = "yaml.ansible" },
      { bin = "eslint", why = "js, ts" },
      { bin = "shellcheck", why = "sh, bash" },
      { bin = "hadolint", why = "dockerfile" },
    },
  },
}

function M.check()
  vim.health.start("nvimicro: Neovim")
  if vim.fn.has("nvim-0.11") == 1 then
    vim.health.ok("Neovim " .. tostring(vim.version()))
  else
    vim.health.error("Neovim 0.11+ required, found " .. tostring(vim.version()))
  end

  local missing = 0
  for _, group in ipairs(groups) do
    vim.health.start("nvimicro: " .. group.name)
    for _, tool in ipairs(group.tools) do
      if vim.fn.executable(tool.bin) == 1 then
        vim.health.ok(tool.bin .. " -- " .. tool.why)
      else
        missing = missing + 1
        -- info, not warn: an absent tool is an ordinary state in this distro.
        vim.health.info(tool.bin .. " not on $PATH -- " .. tool.why .. " is disabled")
      end
    end
  end

  vim.health.start("nvimicro: summary")
  if missing == 0 then
    vim.health.ok("every documented tool is on $PATH")
  else
    vim.health.info(
      missing .. " tool(s) missing. This is not an error: the features that need "
        .. "them stay off. Install commands are in the README."
    )
  end
end

return M
