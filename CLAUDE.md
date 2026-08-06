# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A Neovim configuration (a "micro-distro"), not an application. There is no build
step, no package to publish, and no test suite. The source of truth for target
behaviour is `docs/superpowers/specs/2026-08-06-nvimicro-design.md` (design, in
French) and `docs/superpowers/plans/2026-08-06-nvimicro-implementation.md`
(implementation plan, with per-task verification commands). Requires Neovim 0.11+.

## Verifying changes

Always set `NVIM_APPNAME=nvimicro`. Without it, `stdpath('data')` resolves to the
user's shared `~/.local/share/nvim` even when `-u init.lua` is passed, and this
config's plugins collide with whatever personal config is installed there (this
has already caused a real nvim-treesitter branch/API mismatch).

```bash
# does it start clean?
NVIM_APPNAME=nvimicro nvim --headless -u init.lua -c "qa" 2>&1; echo "EXIT:$?"

# install/update plugins headlessly
NVIM_APPNAME=nvimicro nvim --headless -u init.lua -c "Lazy! sync" -c "qa" 2>&1

# force-load one lazy plugin and assert it loads
NVIM_APPNAME=nvimicro nvim --headless -u init.lua \
  -c "lua require('lazy').load({plugins={'blink.cmp'}})" -c "lua print('OK')" -c "qa" 2>&1

# inspect state (LSP config registered, filetype detection, …)
NVIM_APPNAME=nvimicro nvim --headless -u init.lua \
  -c "lua print(vim.bo.filetype)" -c "qa" 2>&1
```

Interactive checks: `NVIM_APPNAME=nvimicro nvim -u init.lua`, then `:Lazy profile`
(startup budget is **< 50ms**) and `:checkhealth vim.lsp` /
`:lua =vim.lsp.get_clients({bufnr=0})` to confirm a server attached. `:LspInfo`
does not exist here — it ships with nvim-lspconfig, which this distro
deliberately does not use.

`:checkhealth nvimicro` (from `lua/nvimicro/health.lua`) reports which of the
documented external binaries are on `$PATH`. Its tool list mirrors the README
tables — when you add a server, formatter or linter, add it there too.

## Architecture

`init.lua` prepends its own directory to the runtimepath (so `nvim -u
/path/to/init.lua` works from anywhere), loads `config.options` **before**
`lazy.setup()` — the leader key must be set before any plugin registers a
mapping — bootstraps lazy.nvim, then loads `config.keymaps`, `config.autocmds`,
`config.lsp` after. The rtp is re-prepended after `lazy.setup()` because lazy
rewrites it.

`lua/plugins/*.lua` is imported wholesale by lazy (`{ import = "plugins" }`); one
file per plugin, each returning a single spec table. Adding a plugin = adding a
file, nothing to register. Every spec must carry a lazy trigger (`event`, `cmd`,
`keys`, `ft`) — only the colorscheme, mini.statusline and treesitter load at boot.

`lua/config/lsp.lua` uses the **native** `vim.lsp.config()` / `vim.lsp.enable()`
API: no nvim-lspconfig, no mason. Each server is one table of
`cmd`/`filetypes`/`root_markers`/`capabilities`, and the enable list at the
bottom must be kept in sync when a server is added. Note this file calls
`require("blink.cmp").get_lsp_capabilities()` at the top level, which forces
blink.cmp to load at startup despite its `InsertEnter` trigger — keep that in
mind when touching startup cost.

### The no-binaries contract

This distro installs no LSP servers, formatters or linters; they come from the
user's system package manager (README documents them per tool). **A missing tool
is an ordinary state, not an error** — any code path that shells out must degrade
silently. `lua/plugins/lint.lua` wraps every `try_lint` in `pcall` for exactly
this reason. Do not add error reporting for absent binaries.

### Filetype pipeline

Two custom filetypes are produced by autocmds in `lua/config/autocmds.lua` and
consumed everywhere downstream:

- `yaml.ansible` — path-pattern based (`*/playbooks/*.y{a,}ml`, `*/roles/*/tasks/*.y{a,}ml`)
- `helm` — `*/templates/*.{yaml,yml,tpl}` **only if** a sibling `../Chart.yaml` exists

Changing either means updating the matching keys in `lsp.lua` (`filetypes`),
`format.lua` (`formatters_by_ft`), `lint.lua` (`linters_by_ft`) and the
treesitter `FileType` autocmd together. The same four-way sync applies to the
plain filetypes: `sh`/`bash` (bashls + shellcheck + shfmt), `dockerfile`
(dockerls + hadolint) and `json` (jsonls + prettier).

### Deliberate deviations worth preserving

These carry explanatory comments in-file; do not "simplify" them away:

- **tflint** (`lint.lua`) is re-wrapped so it runs from the buffer's own
  Terraform root and matches issues on absolute paths — upstream nvim-lint runs
  `--recursive` from Neovim's cwd and drops every issue when the file was opened
  from elsewhere.
- **pyright** has `disableTaggedHints` under the `pyright` settings scope (not
  `python.analysis`), because its unused-symbol hints duplicate ruff's `F401`.
- **yamlls** disables the schemastore URL and combines `schemastore.nvim`'s Helm
  entries with yaml-language-server's special `kubernetes` schema key, globbed to
  `**/k8s/**` and `**/manifests/**` (a bare `**/*.yaml` false-positives).
- **nvim-treesitter** tracks the `main` branch: parsers compile locally into
  `stdpath('data')/site/parser/`, installation is async, and the API is
  `require("nvim-treesitter").install(...)` plus a `FileType` autocmd calling
  `vim.treesitter.start()` — the `master`-branch `configs.setup{}` form does not
  exist here.

### Out of scope by design

DAP/debugger, terminal plugins, mason, AI chat/agentic editing (Copilot is a
completion source only), and offline/air-gapped support. Diagnostics use native
`virtual_lines = { current_line = true }`, not `virtual_text`.
