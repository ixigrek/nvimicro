-- lua/config/lsp.lua
local capabilities = require("blink.cmp").get_lsp_capabilities()

vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("nvimicro_lsp_attach", { clear = true }),
  callback = function(ev)
    local map = function(keys, func, desc)
      vim.keymap.set("n", keys, func, { buffer = ev.buf, desc = "LSP: " .. desc })
    end
    map("gd", vim.lsp.buf.definition, "Goto Definition")
    map("gr", vim.lsp.buf.references, "Goto References")
    map("gI", vim.lsp.buf.implementation, "Goto Implementation")
    map("K", vim.lsp.buf.hover, "Hover Documentation")
    map("<leader>rn", vim.lsp.buf.rename, "Rename")
    map("<leader>ca", vim.lsp.buf.code_action, "Code Action")
  end,
})

vim.diagnostic.config({
  virtual_text = { spacing = 4 },
  severity_sort = true,
})

vim.lsp.config("pyright", {
  cmd = { "pyright-langserver", "--stdio" },
  filetypes = { "python" },
  root_markers = { "pyproject.toml", "setup.py", "setup.cfg", "requirements.txt", "Pipfile", ".git" },
  capabilities = capabilities,
})

vim.lsp.config("rust_analyzer", {
  cmd = { "rust-analyzer" },
  filetypes = { "rust" },
  root_markers = { "Cargo.toml", ".git" },
  capabilities = capabilities,
})

vim.lsp.config("gopls", {
  cmd = { "gopls" },
  filetypes = { "go", "gomod", "gowork", "gotmpl" },
  root_markers = { "go.mod", "go.work", ".git" },
  capabilities = capabilities,
})

vim.lsp.config("terraform_ls", {
  cmd = { "terraform-ls", "serve" },
  filetypes = { "terraform", "terraform-vars" },
  root_markers = { ".terraform", ".git" },
  capabilities = capabilities,
})

vim.lsp.config("ansiblels", {
  cmd = { "ansible-language-server", "--stdio" },
  filetypes = { "yaml.ansible" },
  root_markers = { "ansible.cfg", ".git" },
  capabilities = capabilities,
})

vim.lsp.config("helm_ls", {
  cmd = { "helm_ls", "serve" },
  filetypes = { "helm" },
  root_markers = { "Chart.yaml" },
  capabilities = capabilities,
})

vim.lsp.config("yamlls", {
  cmd = { "yaml-language-server", "--stdio" },
  filetypes = { "yaml" },
  root_markers = { ".git" },
  capabilities = capabilities,
  settings = {
    yaml = {
      schemaStore = { enable = false, url = "" },
      -- NOTE: the brief specified select = { "kubernetes/kubernetes", "argo-cd/Application",
      -- "helm-values.json" } but none of those names exist in schemastore.nvim's current
      -- catalog (verified against b0o/schemastore.nvim @ a652fcc) — see task-4-report.md.
      -- schemastore.org's catalog has no generic Kubernetes core-resources schema and no
      -- Helm values.yaml schema, and its "Argo CD" entry has no fileMatch (so selecting it
      -- is inert). Using the real, functional Helm entries instead.
      -- yaml-language-server's special "kubernetes" schema key enables its bundled
      -- Kubernetes schema for matching files. kubernetesCRDStoreEnabled defaults to
      -- true (kubernetesCRDStoreUrl defaults to the datreeio/CRDs-catalog), so once a
      -- file matches this glob and declares apiVersion/kind, ArgoCD's Application CRD
      -- (and other CRDs) are looked up automatically — no manual ArgoCD fileMatch/URL
      -- needed. Scoped to k8s/ and manifests/ directory conventions deliberately, since
      -- there's no unique filename for raw k8s manifests (unlike Helm's Chart.yaml) and
      -- a bare **/*.yaml glob would false-positive on unrelated YAML.
      schemas = vim.tbl_extend("force",
        require("schemastore").yaml.schemas({
          select = {
            "Helm Chart.yaml",
            "Helm Chart.lock",
          },
        }),
        {
          kubernetes = { "**/k8s/**/*.yaml", "**/k8s/**/*.yml", "**/manifests/**/*.yaml", "**/manifests/**/*.yml" },
        }
      ),
    },
  },
})

vim.lsp.config("ts_ls", {
  cmd = { "typescript-language-server", "--stdio" },
  filetypes = { "javascript", "javascriptreact", "javascript.jsx", "typescript", "typescriptreact", "typescript.tsx" },
  root_markers = { "package.json", "tsconfig.json", ".git" },
  capabilities = capabilities,
})

vim.lsp.config("tailwindcss", {
  cmd = { "tailwindcss-language-server", "--stdio" },
  filetypes = { "html", "css", "javascriptreact", "typescriptreact" },
  root_markers = { "tailwind.config.js", "tailwind.config.ts", "package.json" },
  capabilities = capabilities,
})

vim.lsp.config("lua_ls", {
  cmd = { "lua-language-server" },
  filetypes = { "lua" },
  root_markers = { ".luarc.json", ".luarc.jsonc", ".git" },
  capabilities = capabilities,
  settings = {
    Lua = {
      diagnostics = { globals = { "vim" } },
      workspace = { checkThirdParty = false },
    },
  },
})

vim.lsp.enable({
  "pyright", "rust_analyzer", "gopls", "terraform_ls", "ansiblels",
  "helm_ls", "yamlls", "ts_ls", "tailwindcss", "lua_ls",
})
