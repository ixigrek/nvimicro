# nvimicro Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a lazy.nvim-based micro Neovim distro for DevOps/SRE + web development (Python, Rust, Go, Terraform, Ansible, Helm, ArgoCD, YAML, Web) with native LSP config, minimal plugin count, and sub-50ms startup.

**Architecture:** `init.lua` bootstraps lazy.nvim, which loads `lua/config/*.lua` (options, keymaps, autocmds, LSP) and one file per plugin under `lua/plugins/*.lua`, each lazy-loaded on `event`/`ft`/`cmd`. LSP servers are wired via the native `vim.lsp.config()`/`vim.lsp.enable()` API (no nvim-lspconfig, no mason) and must already exist in `$PATH`.

**Tech Stack:** Neovim 0.11+, Lua, lazy.nvim, blink.cmp, fzf-lua, neo-tree.nvim, mini.statusline, gitsigns.nvim, conform.nvim, nvim-lint, copilot.lua, nvim-treesitter, schemastore.nvim (data-only dependency for yaml-language-server).

## Global Constraints

- Neovim 0.11+ required (uses `vim.lsp.config`/`vim.lsp.enable` native API).
- No mason.nvim, no nvim-lspconfig — LSP servers configured directly via `vim.lsp.config()`.
- No DAP/debugger, no toggleterm (use native `:terminal`), no AI chat/agent plugin — Copilot provides inline completion only.
- Startup budget: < 50ms measured via `:Lazy profile`; nothing loads at boot except colorscheme + mini.statusline + treesitter core.
- LSP servers, formatters, linters are installed manually by the user via brew/apt/cargo — not automated by Neovim. This plan documents exact binary names in a README but does not install them.
- Every plugin file lives under `lua/plugins/<name>.lua`, one plugin (or tightly-coupled pair) per file.

---

### Task 1: Foundation — bootstrap, options, keymaps, autocmds, colorscheme

**Files:**
- Create: `init.lua`
- Create: `lua/config/options.lua`
- Create: `lua/config/keymaps.lua`
- Create: `lua/config/autocmds.lua`

**Interfaces:**
- Consumes: nothing (first task)
- Produces: `vim.g.mapleader = " "` set before lazy bootstrap; lazy.nvim available as global plugin manager for all subsequent `lua/plugins/*.lua` files (auto-imported via `{ import = "plugins" }`); `lua/config/autocmds.lua` defines an `ansible`/`helm` filetype-detection autocmd group named `"nvimicro_ftdetect"` that later tasks (Task 4 LSP) rely on for `yaml.ansible` and `helm` filetypes.

- [ ] **Step 1: Create `lua/config/options.lua` with base settings**

```lua
-- lua/config/options.lua
local opt = vim.opt

opt.number = true
opt.relativenumber = true
opt.mouse = "a"
opt.clipboard = "unnamedplus"
opt.breakindent = true
opt.undofile = true
opt.ignorecase = true
opt.smartcase = true
opt.signcolumn = "yes"
opt.updatetime = 250
opt.timeoutlen = 300
opt.splitright = true
opt.splitbelow = true
opt.list = true
opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }
opt.inccommand = "split"
opt.cursorline = true
opt.scrolloff = 8
opt.confirm = true
opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2

vim.g.mapleader = " "
vim.g.maplocalleader = " "
```

- [ ] **Step 2: Create `lua/config/keymaps.lua` with base keymaps**

```lua
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
```

- [ ] **Step 3: Create `lua/config/autocmds.lua` with highlight-on-yank and ansible/helm ftdetect**

```lua
-- lua/config/autocmds.lua
local augroup = vim.api.nvim_create_augroup("nvimicro_ftdetect", { clear = true })

vim.api.nvim_create_autocmd("TextYankPost", {
  desc = "Highlight yanked text",
  group = vim.api.nvim_create_augroup("nvimicro_highlight_yank", { clear = true }),
  callback = function()
    vim.highlight.on_yank()
  end,
})

vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  desc = "Detect Ansible playbooks/roles as yaml.ansible",
  group = augroup,
  pattern = { "*/playbooks/*.yml", "*/playbooks/*.yaml", "*/roles/*/tasks/*.yml", "*/roles/*/tasks/*.yaml" },
  callback = function(ev)
    vim.bo[ev.buf].filetype = "yaml.ansible"
  end,
})

vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  desc = "Detect Helm chart templates",
  group = augroup,
  pattern = { "*/templates/*.yaml", "*/templates/*.yml", "*/templates/*.tpl" },
  callback = function(ev)
    if vim.fn.filereadable(vim.fn.fnamemodify(ev.file, ":h:h") .. "/Chart.yaml") == 1 then
      vim.bo[ev.buf].filetype = "helm"
    end
  end,
})
```

- [ ] **Step 4: Create `init.lua` bootstrapping lazy.nvim**

```lua
-- init.lua
require("config.options")

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  spec = {
    { import = "plugins" },
  },
  install = { colorscheme = { "habamax" } },
  checker = { enabled = false },
  performance = {
    rtp = {
      disabled_plugins = { "gzip", "tarPlugin", "tohtml", "tutor", "zipPlugin" },
    },
  },
})

vim.cmd.colorscheme("habamax")

require("config.keymaps")
require("config.autocmds")
require("config.lsp")
```

Note: `require("config.lsp")` is called here but the file doesn't exist yet — Task 4 creates it. For this task, temporarily comment that line out or create an empty `lua/config/lsp.lua` with just `-- placeholder, filled in Task 4` removed once Task 4 lands. To keep Task 1 self-contained and testable, create a minimal `lua/config/lsp.lua` now:

```lua
-- lua/config/lsp.lua (minimal stub, expanded in Task 4)
```

**Files (amended):**
- Create: `lua/config/lsp.lua` (stub, expanded in Task 4)

- [ ] **Step 5: Verify startup has no errors**

Run: `nvim --headless -u init.lua -c "qa" 2>&1; echo "EXIT:$?"`
Expected: no Lua error output, ends with `EXIT:0`

- [ ] **Step 6: Verify colorscheme applied and leader key set**

Run: `nvim --headless -u init.lua -c "lua print('leader='..vim.g.mapleader..' colors='..vim.g.colors_name)" -c "qa" 2>&1`
Expected: output contains `leader=  colors=habamax` (leader is a literal space)

- [ ] **Step 7: Commit**

```bash
git add init.lua lua/config/options.lua lua/config/keymaps.lua lua/config/autocmds.lua lua/config/lsp.lua
git commit -m "feat: bootstrap lazy.nvim, base options/keymaps/autocmds"
```

---

### Task 2: Treesitter

**Files:**
- Create: `lua/plugins/treesitter.lua`

**Interfaces:**
- Consumes: lazy.nvim plugin spec convention from Task 1 (`{ import = "plugins" }` auto-loads this file)
- Produces: treesitter parsers installed for languages used by later filetype/LSP tasks: `lua, python, rust, go, gomod, gowork, terraform, hcl, yaml, helm, dockerfile, bash, json, toml, markdown, markdown_inline, javascript, typescript, tsx, html, css`

- [ ] **Step 1: Create `lua/plugins/treesitter.lua`**

```lua
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
```

- [ ] **Step 2: Verify plugin loads and configures without error**

Run: `nvim --headless -u init.lua -c "lua require('lazy').load({plugins={'nvim-treesitter'}})" -c "lua print('TS_OK')" -c "qa" 2>&1`
Expected: output contains `TS_OK`, no error output

- [ ] **Step 3: Commit**

```bash
git add lua/plugins/treesitter.lua
git commit -m "feat: add nvim-treesitter with devops+web parsers"
```

---

### Task 3: Completion — blink.cmp

**Files:**
- Create: `lua/plugins/completion.lua`

**Interfaces:**
- Consumes: nothing from earlier plugin tasks
- Produces: `require('blink.cmp').get_lsp_capabilities()` — a function returning an LSP client capabilities table, consumed by Task 4 (`lua/config/lsp.lua`) to merge into every `vim.lsp.config()` entry.

- [ ] **Step 1: Create `lua/plugins/completion.lua`**

```lua
-- lua/plugins/completion.lua
return {
  "saghen/blink.cmp",
  event = "InsertEnter",
  version = "*",
  opts = {
    keymap = { preset = "default" },
    appearance = { nerd_font_variant = "mono" },
    completion = {
      documentation = { auto_show = true, auto_show_delay_ms = 200 },
    },
    sources = {
      default = { "lsp", "path", "snippets", "buffer" },
    },
  },
  opts_extend = { "sources.default" },
}
```

- [ ] **Step 2: Verify plugin loads and `get_lsp_capabilities` is callable**

Run: `nvim --headless -u init.lua -c "lua require('lazy').load({plugins={'blink.cmp'}})" -c "lua local caps = require('blink.cmp').get_lsp_capabilities(); print('CAPS_OK='..tostring(type(caps)=='table'))" -c "qa" 2>&1`
Expected: output contains `CAPS_OK=true`

- [ ] **Step 3: Commit**

```bash
git add lua/plugins/completion.lua
git commit -m "feat: add blink.cmp completion"
```

---

### Task 4: LSP — native `vim.lsp.config` for all DevOps/web servers

**Files:**
- Modify: `lua/config/lsp.lua` (replace stub from Task 1)

**Interfaces:**
- Consumes: `require('blink.cmp').get_lsp_capabilities()` from Task 3; `yaml.ansible` and `helm` filetypes from Task 1's `autocmds.lua`
- Produces: buffer-local LSP keymaps applied on `LspAttach` (`gd`, `gr`, `gI`, `K`, `<leader>rn`, `<leader>ca`) available in every buffer with an attached LSP client — later tasks do not add their own LSP keymaps.

- [ ] **Step 1: Add `schemastore.nvim` as a lazy-loaded data dependency**

```lua
-- lua/plugins/schemastore.lua
return {
  "b0o/schemastore.nvim",
  lazy = true,
}
```

**Files (amended):**
- Create: `lua/plugins/schemastore.lua`

- [ ] **Step 2: Write `lua/config/lsp.lua`**

```lua
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
      schemas = require("schemastore").yaml.schemas({
        select = {
          "kubernetes/kubernetes",
          "argo-cd/Application",
          "helm-values.json",
        },
      }),
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
```

- [ ] **Step 3: Verify config loads without error and servers are registered**

Run: `nvim --headless -u init.lua -c "lua print('PYRIGHT='..tostring(vim.lsp.config.pyright ~= nil)..' YAMLLS='..tostring(vim.lsp.config.yamlls ~= nil))" -c "qa" 2>&1`
Expected: output contains `PYRIGHT=true YAMLLS=true`, no Lua errors

- [ ] **Step 4: Verify yaml.ansible ftdetect + ansiblels filetype match**

Run: `mkdir -p /tmp/nvimicro-test/playbooks && echo "- hosts: all" > /tmp/nvimicro-test/playbooks/site.yml && nvim --headless -u init.lua -c "e /tmp/nvimicro-test/playbooks/site.yml" -c "lua print('FT='..vim.bo.filetype)" -c "qa" 2>&1`
Expected: output contains `FT=yaml.ansible`

- [ ] **Step 5: Commit**

```bash
git add lua/config/lsp.lua lua/plugins/schemastore.lua
git commit -m "feat: configure native LSP servers for devops+web stack"
```

---

### Task 5: Finder — fzf-lua

**Files:**
- Create: `lua/plugins/finder.lua`

**Interfaces:**
- Consumes: nothing from earlier tasks
- Produces: keymaps `<leader>ff`, `<leader>fg`, `<leader>fb`, `<leader>fh` available globally (no other task binds these)

- [ ] **Step 1: Create `lua/plugins/finder.lua`**

```lua
-- lua/plugins/finder.lua
return {
  "ibhagwan/fzf-lua",
  cmd = "FzfLua",
  keys = {
    { "<leader>ff", "<cmd>FzfLua files<CR>", desc = "Find Files" },
    { "<leader>fg", "<cmd>FzfLua live_grep<CR>", desc = "Live Grep" },
    { "<leader>fb", "<cmd>FzfLua buffers<CR>", desc = "Find Buffers" },
    { "<leader>fh", "<cmd>FzfLua help_tags<CR>", desc = "Help Tags" },
  },
  opts = {},
}
```

- [ ] **Step 2: Verify plugin loads without error**

Run: `nvim --headless -u init.lua -c "lua require('lazy').load({plugins={'fzf-lua'}})" -c "lua print('FZF_OK')" -c "qa" 2>&1`
Expected: output contains `FZF_OK`

- [ ] **Step 3: Commit**

```bash
git add lua/plugins/finder.lua
git commit -m "feat: add fzf-lua finder"
```

---

### Task 6: Explorer — neo-tree.nvim

**Files:**
- Create: `lua/plugins/explorer.lua`

**Interfaces:**
- Consumes: nothing from earlier tasks
- Produces: keymap `<leader>e` (toggle explorer), available globally

- [ ] **Step 1: Create `lua/plugins/explorer.lua`**

```lua
-- lua/plugins/explorer.lua
return {
  "nvim-neo-tree/neo-tree.nvim",
  branch = "v3.x",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-tree/nvim-web-devicons",
    "MunifTanjim/nui.nvim",
  },
  cmd = "Neotree",
  keys = {
    { "<leader>e", "<cmd>Neotree toggle<CR>", desc = "Toggle Explorer" },
  },
  opts = {
    filesystem = {
      follow_current_file = { enabled = true },
      use_libuv_file_watcher = true,
    },
  },
}
```

- [ ] **Step 2: Verify plugin loads without error**

Run: `nvim --headless -u init.lua -c "lua require('lazy').load({plugins={'neo-tree.nvim'}})" -c "lua print('NEOTREE_OK')" -c "qa" 2>&1`
Expected: output contains `NEOTREE_OK`

- [ ] **Step 3: Commit**

```bash
git add lua/plugins/explorer.lua
git commit -m "feat: add neo-tree.nvim explorer"
```

---

### Task 7: Statusline — mini.statusline

**Files:**
- Create: `lua/plugins/statusline.lua`

**Interfaces:**
- Consumes: nothing from earlier tasks
- Produces: nothing consumed by later tasks (leaf plugin)

- [ ] **Step 1: Create `lua/plugins/statusline.lua`**

```lua
-- lua/plugins/statusline.lua
return {
  "echasnovski/mini.statusline",
  version = "*",
  event = "VeryLazy",
  opts = {
    use_icons = true,
  },
}
```

- [ ] **Step 2: Verify plugin loads without error**

Run: `nvim --headless -u init.lua -c "lua require('lazy').load({plugins={'mini.statusline'}})" -c "lua print('STATUSLINE_OK')" -c "qa" 2>&1`
Expected: output contains `STATUSLINE_OK`

- [ ] **Step 3: Commit**

```bash
git add lua/plugins/statusline.lua
git commit -m "feat: add mini.statusline"
```

---

### Task 8: Git — gitsigns.nvim

**Files:**
- Create: `lua/plugins/git.lua`

**Interfaces:**
- Consumes: nothing from earlier tasks
- Produces: keymaps `]h`, `[h` (hunk nav), `<leader>hs`, `<leader>hr`, `<leader>hp`, `<leader>hb` (buffer-local, set in gitsigns `on_attach`)

- [ ] **Step 1: Create `lua/plugins/git.lua`**

```lua
-- lua/plugins/git.lua
return {
  "lewis6991/gitsigns.nvim",
  event = { "BufReadPre", "BufNewFile" },
  opts = {
    on_attach = function(bufnr)
      local gs = require("gitsigns")
      local map = function(mode, l, r, desc)
        vim.keymap.set(mode, l, r, { buffer = bufnr, desc = desc })
      end
      map("n", "]h", gs.next_hunk, "Next Hunk")
      map("n", "[h", gs.prev_hunk, "Prev Hunk")
      map("n", "<leader>hs", gs.stage_hunk, "Stage Hunk")
      map("n", "<leader>hr", gs.reset_hunk, "Reset Hunk")
      map("n", "<leader>hp", gs.preview_hunk, "Preview Hunk")
      map("n", "<leader>hb", gs.blame_line, "Blame Line")
    end,
  },
}
```

- [ ] **Step 2: Verify plugin loads without error**

Run: `nvim --headless -u init.lua -c "lua require('lazy').load({plugins={'gitsigns.nvim'}})" -c "lua print('GITSIGNS_OK')" -c "qa" 2>&1`
Expected: output contains `GITSIGNS_OK`

- [ ] **Step 3: Commit**

```bash
git add lua/plugins/git.lua
git commit -m "feat: add gitsigns.nvim"
```

---

### Task 9: Format — conform.nvim

**Files:**
- Create: `lua/plugins/format.lua`

**Interfaces:**
- Consumes: nothing from earlier tasks (formatter binaries must be in `$PATH`, documented in Task 12 README)
- Produces: nothing consumed by later tasks (leaf plugin); keymap `<leader>cf` for manual format

- [ ] **Step 1: Create `lua/plugins/format.lua`**

```lua
-- lua/plugins/format.lua
return {
  "stevearc/conform.nvim",
  event = { "BufWritePre" },
  cmd = "ConformInfo",
  keys = {
    {
      "<leader>cf",
      function()
        require("conform").format({ async = true, lsp_fallback = true })
      end,
      desc = "Format Buffer",
    },
  },
  opts = {
    format_on_save = { timeout_ms = 1000, lsp_fallback = true },
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
```

- [ ] **Step 2: Verify plugin loads without error**

Run: `nvim --headless -u init.lua -c "lua require('lazy').load({plugins={'conform.nvim'}})" -c "lua print('CONFORM_OK')" -c "qa" 2>&1`
Expected: output contains `CONFORM_OK`

- [ ] **Step 3: Commit**

```bash
git add lua/plugins/format.lua
git commit -m "feat: add conform.nvim format-on-save"
```

---

### Task 10: Lint — nvim-lint

**Files:**
- Create: `lua/plugins/lint.lua`

**Interfaces:**
- Consumes: nothing from earlier tasks (linter binaries must be in `$PATH`, documented in Task 12 README)
- Produces: nothing consumed by later tasks (leaf plugin)

- [ ] **Step 1: Create `lua/plugins/lint.lua`**

```lua
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
```

- [ ] **Step 2: Verify plugin loads without error**

Run: `nvim --headless -u init.lua -c "lua require('lazy').load({plugins={'nvim-lint'}})" -c "lua print('LINT_OK')" -c "qa" 2>&1`
Expected: output contains `LINT_OK`

- [ ] **Step 3: Commit**

```bash
git add lua/plugins/lint.lua
git commit -m "feat: add nvim-lint with devops+web linters"
```

---

### Task 11: AI — copilot.lua + blink.cmp source

**Files:**
- Modify: `lua/plugins/completion.lua`
- Create: `lua/plugins/ai.lua`

**Interfaces:**
- Consumes: `lua/plugins/completion.lua` from Task 3 (adds `copilot` to `sources.default` and defines the `copilot` source provider)
- Produces: nothing consumed by later tasks (final leaf plugin)

- [ ] **Step 1: Create `lua/plugins/ai.lua`**

```lua
-- lua/plugins/ai.lua
return {
  "zbirenbaum/copilot.lua",
  cmd = "Copilot",
  event = "InsertEnter",
  opts = {
    suggestion = { enabled = false },
    panel = { enabled = false },
  },
}
```

- [ ] **Step 2: Modify `lua/plugins/completion.lua` to add the Copilot source**

Change the `sources` block from:

```lua
    sources = {
      default = { "lsp", "path", "snippets", "buffer" },
    },
```

to:

```lua
    sources = {
      default = { "lsp", "path", "snippets", "buffer", "copilot" },
      providers = {
        copilot = {
          name = "copilot",
          module = "blink-copilot",
          score_offset = 100,
          async = true,
        },
      },
    },
```

And add `"giuxtaposition/blink-cmp-copilot"` as a dependency in the same file, changing the plugin table's top-level fields to include:

```lua
  dependencies = { "zbirenbaum/copilot.lua", "giuxtaposition/blink-cmp-copilot" },
```

Full resulting `lua/plugins/completion.lua`:

```lua
-- lua/plugins/completion.lua
return {
  "saghen/blink.cmp",
  event = "InsertEnter",
  version = "*",
  dependencies = { "zbirenbaum/copilot.lua", "giuxtaposition/blink-cmp-copilot" },
  opts = {
    keymap = { preset = "default" },
    appearance = { nerd_font_variant = "mono" },
    completion = {
      documentation = { auto_show = true, auto_show_delay_ms = 200 },
    },
    sources = {
      default = { "lsp", "path", "snippets", "buffer", "copilot" },
      providers = {
        copilot = {
          name = "copilot",
          module = "blink-copilot",
          score_offset = 100,
          async = true,
        },
      },
    },
  },
  opts_extend = { "sources.default" },
}
```

- [ ] **Step 3: Verify both plugins load without error**

Run: `nvim --headless -u init.lua -c "lua require('lazy').load({plugins={'copilot.lua','blink-cmp-copilot','blink.cmp'}})" -c "lua print('AI_OK')" -c "qa" 2>&1`
Expected: output contains `AI_OK`

- [ ] **Step 4: Commit**

```bash
git add lua/plugins/ai.lua lua/plugins/completion.lua
git commit -m "feat: add copilot.lua completion source to blink.cmp"
```

---

### Task 12: README — manual binary install instructions

**Files:**
- Create: `README.md`

**Interfaces:**
- Consumes: exact binary/package names from Tasks 4, 9, 10
- Produces: nothing (documentation leaf)

- [ ] **Step 1: Create `README.md`**

```markdown
# nvimicro

Ultra-light Neovim distro for DevOps/SRE (Python, Rust, Go, Terraform, Ansible,
Helm, ArgoCD, YAML) + web development. Requires Neovim 0.11+.

## Prerequisites

This distro does **not** install LSP servers, formatters, or linters for you
(no mason.nvim). Install these via your system package manager before use.

### LSP servers

| Tool | Install (macOS/brew) | Install (apt) | Install (cargo/other) |
|---|---|---|---|
| pyright | `npm i -g pyright` | `npm i -g pyright` | — |
| rust-analyzer | `brew install rust-analyzer` | `apt install rust-analyzer` | `rustup component add rust-analyzer` |
| gopls | `go install golang.org/x/tools/gopls@latest` | same | same |
| terraform-ls | `brew install hashicorp/tap/terraform-ls` | see releases page | — |
| ansible-language-server | `npm i -g @ansible/ansible-language-server` | same | — |
| helm_ls | `brew install helm-ls` | see releases page | `go install github.com/mrjosh/helm-ls@latest` |
| yaml-language-server | `npm i -g yaml-language-server` | same | — |
| typescript-language-server | `npm i -g typescript-language-server typescript` | same | — |
| tailwindcss-language-server | `npm i -g @tailwindcss/language-server` | same | — |
| lua-language-server | `brew install lua-language-server` | see releases page | — |

### Formatters

| Tool | Install |
|---|---|
| ruff (python format+lint) | `brew install ruff` / `pip install ruff` |
| rustfmt | `rustup component add rustfmt` |
| gofmt, goimports | bundled with Go / `go install golang.org/x/tools/cmd/goimports@latest` |
| terraform (fmt) | `brew install terraform` |
| yamlfmt | `brew install yamlfmt` |
| stylua | `brew install stylua` |
| prettier | `npm i -g prettier` |

### Linters

| Tool | Install |
|---|---|
| ruff | `brew install ruff` / `pip install ruff` |
| tflint | `brew install tflint` |
| yamllint | `brew install yamllint` / `pip install yamllint` |
| ansible-lint | `pip install ansible-lint` |
| eslint | `npm i -g eslint` |

## Structure

- `init.lua` — bootstraps lazy.nvim
- `lua/config/` — options, keymaps, autocmds, LSP config
- `lua/plugins/` — one file per plugin, lazy-loaded

## Keymaps

| Keys | Action |
|---|---|
| `<leader>ff` | Find files |
| `<leader>fg` | Live grep |
| `<leader>fb` | Find buffers |
| `<leader>e` | Toggle file explorer |
| `gd` / `gr` / `gI` | Goto definition/references/implementation |
| `K` | Hover docs |
| `<leader>rn` | Rename symbol |
| `<leader>ca` | Code action |
| `<leader>cf` | Format buffer |
| `]h` / `[h` | Next/prev git hunk |
| `<leader>hs` / `<leader>hr` / `<leader>hp` / `<leader>hb` | Stage/reset/preview hunk, blame line |

## Performance

Run `:Lazy profile` to inspect startup time. Budget: < 50ms.
```

- [ ] **Step 2: Verify markdown file is well-formed (no broken table syntax)**

Run: `grep -c '^|' README.md`
Expected: a nonzero count (tables present); manually eyeball rendering in an editor/GitHub preview

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: add README with manual binary install instructions"
```

---

## Final Verification (after all tasks)

- [ ] Run `nvim --headless -u init.lua -c "Lazy! sync" -c "qa"` to install all plugins fresh
- [ ] Run `nvim -u init.lua` interactively, open a `.tf`, a `.yaml` under `templates/` in a chart with `Chart.yaml`, a `.py`, a `.go`, and a `playbooks/*.yml` file; for each confirm `:LspInfo` shows an attached client matching the table in Task 4
- [ ] Run `:Lazy profile` and confirm total startup time is under 50ms
- [ ] Run `:checkhealth` and confirm no errors under `lazy`, `treesitter`, `blink.cmp` sections (missing external binaries are expected and fine — those come from README prerequisites)
