# nvimicro — Design

**Date**: 2026-08-06
**Statut**: Approuvé

## Objectif

Micro-distro Neovim orientée développement, ultra rapide au démarrage, efficiente en fonctionnalités (pas de bloat). Cible principale : usage DevOps/SRE (Python, Rust, Go, Terraform, Ansible, ArgoCD, Helm, YAML) + développement Web, sur machine locale principale (pas de contrainte SSH/air-gap).

## Contraintes

- Neovim 0.11+ requis (API `vim.lsp.config` native)
- Machine locale — pas besoin de tolérer offline/air-gapped/SSH minimal
- Philosophie : minimum de plugins, chaque ajout doit se justifier par rapport à un équivalent natif
- Pas de gestion de binaires par Neovim (pas de mason) — l'utilisateur installe les LSP servers/formatters/linters via son gestionnaire système (brew/apt/cargo)

## Architecture

```
init.lua                  # bootstrap lazy.nvim, require config.*
lua/config/
  options.lua              # vim.opt, réglages de base
  keymaps.lua               # mappings globaux
  autocmds.lua               # autocommandes
  lsp.lua                    # vim.lsp.config(...) + vim.lsp.enable(...) par serveur
lua/plugins/
  completion.lua              # blink.cmp
  finder.lua                    # fzf-lua
  explorer.lua                    # neo-tree.nvim
  statusline.lua                    # mini.statusline
  git.lua                             # gitsigns.nvim
  format.lua                            # conform.nvim
  lint.lua                                # nvim-lint
  ai.lua                                    # copilot.lua + source blink
  treesitter.lua                              # nvim-treesitter
```

- `lazy.nvim` gère l'installation/lazy-load des plugins (`event`/`ft`/`cmd` triggers). Rien n'est chargé au boot sauf colorscheme, statusline, treesitter core.
- LSP configuré via l'API native `vim.lsp.config()` / `vim.lsp.enable()` (pas de nvim-lspconfig, pas de mason). Chaque serveur = une table `cmd`/`filetypes`/`root_markers` dans `lua/config/lsp.lua`.
- Aucun plugin manager de binaires : les serveurs LSP, formatters et linters doivent être présents dans le `PATH` (installation manuelle documentée dans le README, pas automatisée par Neovim).

## Composants

| Domaine | Plugin | Chargement (lazy trigger) | Justification |
|---|---|---|---|
| Plugin manager | lazy.nvim | — (bootstrap) | Standard, lazy-load fin, `:Lazy profile` pour mesurer perf |
| Completion | blink.cmp | `InsertEnter` | Rust-backed, plus rapide que nvim-cmp |
| Finder | fzf-lua | `cmd` (Files/Grep/Buffers...) | Binaire fzf natif, rapide sur gros repos |
| Explorer | neo-tree.nvim | `cmd` (Neotree toggle) | Sidebar avec git status inline, utile pour repos IaC multi-fichiers |
| Statusline | mini.statusline | au boot (léger) | Minimaliste, faible overhead |
| Git | gitsigns.nvim | `event = BufReadPre` | Hunks/blame gutter |
| Format | conform.nvim | `event = BufWritePre` (format on save) | Multi-formatter par filetype |
| Lint | nvim-lint | `event = BufWritePost` | Lint async multi-outils |
| AI | copilot.lua + source blink-cmp | `InsertEnter` | Complétion inline uniquement, pas de chat/agent |
| Syntax | nvim-treesitter | `event = BufReadPost` | Base highlighting/textobjects moderne, requis |

## LSP servers (installation manuelle, hors Neovim)

| Langage/Domaine | Serveur | Formatter | Linter |
|---|---|---|---|
| Python | pyright ou ruff (LSP) | ruff format | ruff |
| Rust | rust-analyzer | rustfmt | rust-analyzer (intégré) |
| Go | gopls | gofmt / goimports | go vet (via gopls) |
| Terraform | terraform-ls | terraform fmt | tflint |
| Ansible | ansible-language-server | — | ansible-lint |
| Helm | helm-ls | — | — |
| YAML (k8s/ArgoCD/Helm) | yaml-language-server + SchemaStore | — | yamllint |
| Web/TS | vtsls (ou ts_ls), tailwindcss-language-server | prettier | eslint |
| Lua (config elle-même) | lua-language-server | stylua | — |

`yaml-language-server` doit être configuré avec les schémas SchemaStore pertinents (Kubernetes, Helm `values.yaml`, ArgoCD `Application`) pour la validation YAML.

## Hors scope (exclu explicitement)

- DAP / debugger
- Terminal flottant en plugin (toggleterm) — `:terminal` natif suffit
- Mason / gestion automatique de binaires
- Chat IA / edit agentic — uniquement complétion inline Copilot
- Support offline/air-gapped/SSH minimal (hors contrainte pour cette distro)

## Budget performance

- Startup cible : < 50ms mesuré via `:Lazy profile`
- Aucun plugin non-essentiel chargé avant la première interaction (insert mode, commande, ou lecture de buffer selon le cas)

## Structure de test/validation

- Vérification manuelle du startup time après chaque ajout de plugin (`:Lazy profile`)
- Test des LSP par filetype représentatif (au moins un fichier `.tf`, `.yaml` ArgoCD, `.py`, `.go`, `.rs` d'exemple) pour valider `vim.lsp.config`
