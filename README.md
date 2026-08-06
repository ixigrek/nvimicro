# nvimicro

Ultra-light Neovim distro for DevOps/SRE (Python, Rust, Go, Terraform, Ansible,
Helm, ArgoCD, YAML) + web development. Requires Neovim 0.11+.

No `mason.nvim`: LSP servers, formatters and linters are **your** system
packages, installed once and shared with everything else on the machine. A tool
that is missing is an ordinary state — the feature that needs it degrades
quietly, nothing errors.

## Running nvimicro

Always set `NVIM_APPNAME=nvimicro` so this config's plugins/state/cache are
fully isolated from your personal Neovim setup — otherwise `stdpath('data')`
resolves to your regular `~/.local/share/nvim`, and any plugin already
installed there for a different config can collide with this one (wrong
branch, wrong version, confusing errors).

```bash
NVIM_APPNAME=nvimicro nvim -u init.lua
```

Alias this in your shell for convenience:

```bash
alias nvimicro='NVIM_APPNAME=nvimicro nvim -u /path/to/nvimicro/init.lua'
```

Use a terminal with a [Nerd Font](https://www.nerdfonts.com/) — the file
explorer, statusline and completion menu render icons through
`nvim-web-devicons` and will show tofu boxes otherwise.

## Prerequisites

This distro does **not** install LSP servers, formatters, or linters for you
(no mason.nvim). Install these via your system package manager before use.

### Treesitter

| Tool | Install (macOS/brew) | Install (apt) |
|---|---|---|
| tree-sitter CLI | `brew install tree-sitter-cli` (NOT the plain `tree-sitter` formula — that one is library-only) | see https://github.com/tree-sitter/tree-sitter/releases |
| C compiler | usually preinstalled (Xcode CLT / build-essential) | `apt install build-essential` |

Both are required: `nvim-treesitter`'s `main` branch compiles every parser
locally. Parsers land in `~/.local/share/nvimicro/site/parser/`, not in the
plugin directory. Installation is async — a cold first launch highlights with
regular `syntax` until the parser finishes building, then picks it up.

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
| typescript-language-server | `npm i -g typescript-language-server` | same | — |
| tailwindcss-language-server | `npm i -g @tailwindcss/language-server` | same | — |
| lua-language-server | `brew install lua-language-server` | see releases page | — |

Servers resolve their project root from markers (`Cargo.toml`, `go.mod`,
`pyproject.toml`, `.terraform`, …) and fall back to `.git`. A Rust file with no
`Cargo.toml` above it makes rust-analyzer fail with *"Failed to discover
workspace"* — that is the marker missing, not a config bug.

`:LspInfo` does **not** exist here (it ships with `nvim-lspconfig`, which this
distro deliberately does not use). The native equivalents:

```vim
:checkhealth vim.lsp
:lua =vim.lsp.get_clients({ bufnr = 0 })
```

#### TypeScript: one extra prerequisite

`ts_ls` needs the `typescript` **package inside the workspace's
`node_modules`**. A global `tsc` binary is not enough.

```bash
npm i -D typescript@5
```

Pin the major version. `npm i typescript` now resolves to TypeScript 7 (the
native Go port), which dropped `tsserver.js`; `typescript-language-server` then
dies during `initialize` and surfaces as a raw Lua traceback out of
`vim/lsp/client.lua`. TypeScript 7 projects need tsgo's own language server,
which neither `ts_ls` nor `vtsls` can drive.

#### YAML schemas

`yamlls` gets Kubernetes schemas for files under `**/k8s/**` and
`**/manifests/**`, Helm `Chart.yaml`/`Chart.lock` schemas from SchemaStore, and
CRD schemas (ArgoCD `Application`, etc.) automatically from the
[datreeio/CRDs-catalog](https://github.com/datreeio/CRDs-catalog) via
`kubernetesCRDStoreEnabled`. Helm `templates/*.yaml` are detected as `helm` when
a sibling `Chart.yaml` exists; `playbooks/*.yml` and `roles/*/tasks/*.yml` as
`yaml.ansible`.

### Formatters

| Tool | Install |
|---|---|
| ruff (python format+lint) | `brew install ruff` / `pip install ruff` |
| rustfmt | `rustup component add rustfmt` |
| gofmt | bundled with the Go distribution |
| goimports | `go install golang.org/x/tools/cmd/goimports@latest` |
| terraform (fmt) | `brew install terraform` |
| yamlfmt | `brew install yamlfmt` |
| stylua | `brew install stylua` |
| prettier | `npm i -g prettier` |

Format on save is on, plus `<leader>cf` on demand.

- **Go**: `goimports` is preferred and `gofmt` is only a fallback — `goimports`
  is `gofmt` plus import fixing, so running both is redundant. `go install`
  puts it in `~/go/bin`, which is often not on `$PATH`; without
  `export PATH="$HOME/go/bin:$PATH"` Go formatting silently degrades to plain
  `gofmt` and unused imports survive.
- **`lsp_format = "fallback"`** hands formatting to the LSP only when *no*
  formatter is configured for the filetype — not when a configured one is
  missing from `$PATH`. Absent `stylua`, a `.lua` write reports
  *"Formatters unavailable for lua file"* and writes cleanly; it does not fall
  back to `lua_ls`.
- **ruff format** never reflows comments or strings (same policy as Black).

### Linters

| Tool | Install |
|---|---|
| ruff | `brew install ruff` / `pip install ruff` |
| tflint | `brew install tflint` |
| yamllint | `brew install yamllint` / `pip install yamllint` |
| ansible-lint | `pip install ansible-lint` |
| eslint | `npm i -g eslint` |

Linters run on read, write and leaving insert mode. A linter that is not
installed is skipped silently.

- **tflint** is pinned to the buffer's own Terraform root (`.tflint.hcl` /
  `.terraform`, else the file's directory) instead of Neovim's cwd, so opening
  a `.tf` from anywhere still reports its issues and a monorepo root does not
  make tflint walk the whole tree.
- **ruff** lints with its own defaults (`E4,E7,E9,F`). `E501` line-too-long is
  off — enabling it belongs in a project's `pyproject.toml`/`ruff.toml`, not in
  a global distro setting.
- **yamllint**'s defaults flag `missing document start "---"` on every
  Kubernetes/Helm file. Silence it with a project-local `.yamllint`; the distro
  does not override it for you.
- Pyright's "unnecessary" hints are disabled (`disableTaggedHints`) because they
  duplicate ruff's `F401`. Pyright's real errors are untouched.

### AI completion

Copilot is wired into `blink.cmp` as a completion source (no ghost text, no
panel). Needs Node.js, plus a one-off authentication:

```vim
:Copilot auth
```

## Structure

- `init.lua` — bootstraps lazy.nvim
- `lua/config/` — options, keymaps, autocmds, LSP config
- `lua/plugins/` — one file per plugin, lazy-loaded

## Keymaps

Leader is `<Space>`.

| Keys | Action |
|---|---|
| `<leader>ff` | Find files |
| `<leader>fg` | Live grep |
| `<leader>fb` | Find buffers |
| `<leader>fh` | Help tags |
| `<leader>e` | Toggle file explorer |
| `gd` / `gr` / `gI` | Goto definition/references/implementation |
| `K` | Hover docs |
| `<leader>rn` | Rename symbol |
| `<leader>ca` | Code action |
| `<leader>cf` | Format buffer |
| `[d` / `]d` | Previous/next diagnostic |
| `<leader>q` | Diagnostics to location list |
| `]h` / `[h` | Next/prev git hunk |
| `<leader>hs` / `<leader>hr` / `<leader>hp` / `<leader>hb` | Stage/reset/preview hunk, blame line |
| `<C-h>` / `<C-j>` / `<C-k>` / `<C-l>` | Move focus between windows |
| `<Esc>` | Clear search highlight |
| `<C-y>` / `<C-CR>` | Accept completion (`<C-CR>` needs a terminal speaking the Kitty keyboard protocol) |

Diagnostics render as gutter signs everywhere plus the full text underneath the
cursor's line only (native `virtual_lines`), which avoids the horizontal
overflow `virtual_text` hits when one line carries several diagnostics.
`vim.diagnostic.config()` is read at startup — a long-lived session started
before a config change keeps the old rendering until you restart.

## Performance

Run `:Lazy profile` to inspect startup time. Budget: < 50ms.
