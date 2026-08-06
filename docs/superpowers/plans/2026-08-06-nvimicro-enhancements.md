# nvimicro Enhancements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close four gaps in the nvimicro distro — missing native LSP/finder keymaps, no escape hatch from format-on-save, three treesitter parsers with no LSP/lint behind them, no way to see which external binaries are missing, and no syntax-aware textobjects.

**Architecture:** Four independent features, each on its own branch off `main` with its own PR. Order is by cost: Task 1 is native-only (zero new plugins, zero startup cost), Task 2 is config-only (new server/linter/formatter entries, binaries stay the user's responsibility), Task 3 adds a self-contained health module, Task 4 adds the single new plugin. Tasks 1/2 both touch `lua/config/lsp.lua` and `lua/plugins/format.lua` but in disjoint regions, so they merge cleanly in any order.

**Tech Stack:** Lua, Neovim 0.11+ native APIs (`vim.lsp.config`, `vim.lsp.inlay_hint`, `vim.hl`, `vim.health`), lazy.nvim, fzf-lua, conform.nvim, nvim-lint, nvim-treesitter-textobjects (`main` branch).

## Global Constraints

- **Neovim 0.11+ required.** Verified locally against 0.12.4. Never use APIs newer than 0.11 without a guard.
- **No mason, no nvim-lspconfig.** Servers are declared with native `vim.lsp.config()` / `vim.lsp.enable()` only.
- **This distro installs no binaries.** A missing LSP server / formatter / linter is an ordinary state: the feature degrades silently, nothing errors, no user-facing message. Any new shell-out path must follow the existing `pcall` pattern in `lua/plugins/lint.lua`.
- **Startup budget: < 50ms**, measured with `:Lazy profile`. Nothing new may load at boot; every new plugin spec carries a lazy trigger (`event` / `cmd` / `keys` / `ft`).
- **Every command in this plan must be run with `NVIM_APPNAME=nvimicro`.** Without it `stdpath('data')` resolves to the shared `~/.local/share/nvim` even when `-u init.lua` is passed, and this config's plugins collide with the user's personal config. This has already caused a real nvim-treesitter branch/API mismatch.
- **One branch + one PR per task.** Each branch is cut from `main`, not from the previous task's branch.
- **Do not remove the existing `gd` / `gr` / `gI` / `K` / `<leader>rn` / `<leader>ca` mappings** in `lua/config/lsp.lua` even though Neovim 0.11 ships `grr` / `gri` / `grt` / `grn` / `gra` / `gO` natively. They are a deliberate mnemonic choice.

## Verified API facts

These were checked against the sources installed in `~/.local/share/nvimicro/lazy` and against stock Neovim 0.12.4. Do not second-guess them.

- Neovim already binds natively: `grn` rename, `gra` code action, `grr` references, `gri` implementation, `grt` type definition, `gO` document symbol, `grx` codelens run, `<C-S>` insert-mode signature help. **`gD` (declaration) and an inlay-hint toggle have no native binding** — those are the real gaps.
- `vim.highlight.on_yank` is deprecated; the current name is `vim.hl.on_yank` (`vim.hl` exists on 0.12.4).
- fzf-lua command names (from `fzf-lua/lua/fzf-lua/init.lua`): `lsp_document_symbols`, `lsp_live_workspace_symbols`, `diagnostics_document`, `diagnostics_workspace`, `git_status`, `git_commits`, `oldfiles`, `resume`.
- nvim-lint ships `hadolint` and `shellcheck` linters (`nvim-lint/lua/lint/linters/`).
- conform ships an `shfmt` formatter (`conform.nvim/lua/conform/formatters/shfmt.lua`).
- `schemastore.nvim` exposes `require("schemastore").json.schemas(opts)` returning a **list** of `{name, description, fileMatch, url}` entries — the shape `jsonls` wants. (`yaml.schemas()` returns a `url = fileMatch` map instead; do not mix them up.)
- nvim-treesitter-textobjects `main` branch has no module registration: you call `require("nvim-treesitter-textobjects").setup{}` and then bind keys yourself via `require("nvim-treesitter-textobjects.select").select_textobject(query, group)` and `require("nvim-treesitter-textobjects.move").goto_next_start(query, group)`.
- Installed on this machine: `lua-language-server`, `pyright-langserver`, `gopls`, `rust-analyzer`, `terraform-ls`, `yaml-language-server`, `ruff`, `tflint`, `yamllint`, `prettier`, `stylua`, `tree-sitter`, `fzf`. **Missing:** `bash-language-server`, `docker-langserver`, `vscode-json-language-server`, `shellcheck`, `hadolint`, `shfmt`. Task 2 and Task 3 verification depends on this — the new tools being absent is what proves the silent-degradation contract.

## File Structure

| File | Task | Responsibility after the change |
| --- | --- | --- |
| `lua/config/autocmds.lua` | 1 | Unchanged role; one deprecated call renamed. |
| `lua/config/lsp.lua` | 1, 2 | T1 adds two mappings inside the existing `LspAttach` callback. T2 appends three server tables and extends the `vim.lsp.enable` list. |
| `lua/plugins/finder.lua` | 1 | Grows from 4 to 12 fzf-lua key specs. |
| `lua/plugins/format.lua` | 1, 2 | T1 turns `format_on_save` from a table into a function gate and adds the `:FormatDisable` / `:FormatEnable` commands. T2 adds the `sh`/`bash` formatter entries. |
| `lua/plugins/lint.lua` | 2 | Two new `linters_by_ft` entries. |
| `lua/nvimicro/health.lua` | 3 | **New.** Single responsibility: report which documented external binaries are on `$PATH`. Lives under `lua/nvimicro/` because `:checkhealth <name>` resolves `lua/<name>/health.lua` on the runtimepath. |
| `lua/plugins/textobjects.lua` | 4 | **New.** The nvim-treesitter-textobjects spec plus its select/move/swap keymaps. |
| `README.md` | 1, 2, 3, 4 | Keymap table and prerequisite tables kept truthful. |
| `CLAUDE.md` | 2, 3 | Filetype-pipeline note and health-check entry point. |

---

### Task 1: Native quality-of-life pass

Branch: `feat/native-qol`

**Files:**
- Modify: `lua/config/autocmds.lua:8`
- Modify: `lua/config/lsp.lua:6-16` (inside the `LspAttach` callback)
- Modify: `lua/plugins/finder.lua`
- Modify: `lua/plugins/format.lua`
- Modify: `README.md` (keymap table)

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: the global `vim.g.nvimicro_disable_autoformat` flag and the buffer-local `vim.b[bufnr].nvimicro_disable_autoformat` flag, both read by `format_on_save` in `lua/plugins/format.lua`. No later task depends on these.

- [ ] **Step 1: Cut the branch**

```bash
git checkout main && git pull --ff-only
git checkout -b feat/native-qol
```

- [ ] **Step 2: Write the failing check for the deprecated yank highlight**

There is no test runner in this repo; the check is a headless assertion. Run it now and record that it fails:

Run:
```bash
NVIM_APPNAME=nvimicro nvim --headless -u init.lua \
  -c 'lua local s=table.concat(vim.fn.readfile("lua/config/autocmds.lua"),"\n"); print(s:find("vim%.hl%.on_yank") and "PASS" or "FAIL: still on deprecated vim.highlight")' \
  -c qa 2>&1
```
Expected: `FAIL: still on deprecated vim.highlight`

- [ ] **Step 3: Rename the deprecated call**

In `lua/config/autocmds.lua`, replace `vim.highlight.on_yank()` with:

```lua
    vim.hl.on_yank()
```

- [ ] **Step 4: Re-run the check**

Run: the same command as Step 2.
Expected: `PASS`

- [ ] **Step 5: Write the failing check for the two missing LSP mappings**

`lua-language-server` is installed, so a real `LspAttach` can be forced by opening a Lua file and waiting for a client.

Run:
```bash
NVIM_APPNAME=nvimicro nvim --headless -u init.lua -c 'e lua/config/options.lua' \
  -c 'lua vim.wait(8000, function() return #vim.lsp.get_clients({bufnr=0}) > 0 end)' \
  -c 'lua print("gD="..(vim.fn.maparg("gD","n")~="" and "OK" or "MISSING").." toggle="..(vim.fn.maparg("<leader>th","n")~="" and "OK" or "MISSING"))' \
  -c qa 2>&1 | tail -1
```
Expected: `gD=MISSING toggle=MISSING`

- [ ] **Step 6: Add the two mappings**

In `lua/config/lsp.lua`, inside the `LspAttach` callback, after the existing `map("<leader>ca", ...)` line, add:

```lua
    -- Neovim 0.11 already binds grn/gra/grr/gri/grt/gO and insert-mode <C-s>.
    -- These two have no native default.
    map("gD", vim.lsp.buf.declaration, "Goto Declaration")
    map("<leader>th", function()
      local enabled = vim.lsp.inlay_hint.is_enabled({ bufnr = ev.buf })
      vim.lsp.inlay_hint.enable(not enabled, { bufnr = ev.buf })
    end, "Toggle Inlay Hints")
```

- [ ] **Step 7: Re-run the mapping check**

Run: the same command as Step 5.
Expected: `gD=OK toggle=OK`

- [ ] **Step 8: Commit the LSP half**

```bash
git add lua/config/autocmds.lua lua/config/lsp.lua
git commit -m "feat(lsp): add gD and inlay-hint toggle, drop deprecated vim.highlight"
```

- [ ] **Step 9: Write the failing check for the new fzf-lua pickers**

lazy.nvim registers `keys` specs as stub mappings at startup, so they are visible without loading fzf-lua.

Run:
```bash
NVIM_APPNAME=nvimicro nvim --headless -u init.lua \
  -c 'lua for _,k in ipairs({"<leader>fs","<leader>fS","<leader>fd","<leader>fD","<leader>fr","<leader>fo","<leader>gs","<leader>gc"}) do io.write(k.."="..(vim.fn.maparg(k,"n")~="" and "OK" or "MISSING").." ") end print("")' \
  -c qa 2>&1 | tail -1
```
Expected: every entry `MISSING`.

- [ ] **Step 10: Add the pickers**

Replace the `keys` table in `lua/plugins/finder.lua` with:

```lua
  keys = {
    { "<leader>ff", "<cmd>FzfLua files<CR>", desc = "Find Files" },
    { "<leader>fg", "<cmd>FzfLua live_grep<CR>", desc = "Live Grep" },
    { "<leader>fb", "<cmd>FzfLua buffers<CR>", desc = "Find Buffers" },
    { "<leader>fh", "<cmd>FzfLua help_tags<CR>", desc = "Help Tags" },
    { "<leader>fo", "<cmd>FzfLua oldfiles<CR>", desc = "Recent Files" },
    { "<leader>fr", "<cmd>FzfLua resume<CR>", desc = "Resume Last Picker" },
    -- Fuzzy-searchable counterparts to the native gO / <leader>q.
    { "<leader>fs", "<cmd>FzfLua lsp_document_symbols<CR>", desc = "Document Symbols" },
    { "<leader>fS", "<cmd>FzfLua lsp_live_workspace_symbols<CR>", desc = "Workspace Symbols" },
    { "<leader>fd", "<cmd>FzfLua diagnostics_document<CR>", desc = "Buffer Diagnostics" },
    { "<leader>fD", "<cmd>FzfLua diagnostics_workspace<CR>", desc = "Workspace Diagnostics" },
    { "<leader>gs", "<cmd>FzfLua git_status<CR>", desc = "Git Status" },
    { "<leader>gc", "<cmd>FzfLua git_commits<CR>", desc = "Git Commits" },
  },
```

- [ ] **Step 11: Re-run the picker check**

Run: the same command as Step 9.
Expected: every entry `OK`.

- [ ] **Step 12: Verify each picker name actually resolves**

A wrong name would only fail at press time, so assert against fzf-lua's own command registry.

Run:
```bash
NVIM_APPNAME=nvimicro nvim --headless -u init.lua \
  -c 'lua require("lazy").load({plugins={"fzf-lua"}})' \
  -c 'lua local f=require("fzf-lua"); for _,n in ipairs({"oldfiles","resume","lsp_document_symbols","lsp_live_workspace_symbols","diagnostics_document","diagnostics_workspace","git_status","git_commits"}) do assert(type(f[n])=="function", n.." is not a picker") end print("ALL_PICKERS_OK")' \
  -c qa 2>&1 | tail -1
```
Expected: `ALL_PICKERS_OK`

- [ ] **Step 13: Commit the finder half**

```bash
git add lua/plugins/finder.lua
git commit -m "feat(finder): add symbol, diagnostic, git and resume pickers"
```

- [ ] **Step 14: Write the failing check for the format-on-save escape hatch**

Run:
```bash
NVIM_APPNAME=nvimicro nvim --headless -u init.lua \
  -c 'lua require("lazy").load({plugins={"conform.nvim"}})' \
  -c 'lua print("FormatDisable="..(vim.fn.exists(":FormatDisable")==2 and "OK" or "MISSING"))' \
  -c qa 2>&1 | tail -1
```
Expected: `FormatDisable=MISSING`

- [ ] **Step 15: Gate format-on-save**

In `lua/plugins/format.lua`, replace the `format_on_save = { ... }` line with a function, and add a `config` function that defines the toggle commands. The full spec becomes:

```lua
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
```

- [ ] **Step 16: Re-run the command check**

Run: the same command as Step 14.
Expected: `FormatDisable=OK`

- [ ] **Step 17: Verify the gate actually suppresses formatting**

`stylua` is installed, so a badly formatted Lua buffer proves the behaviour end to end. This writes only inside the scratch dir.

Run:
```bash
SCRATCH=$(mktemp -d)
printf 'local   x  =  1\n' > "$SCRATCH/a.lua"
printf 'local   x  =  1\n' > "$SCRATCH/b.lua"
NVIM_APPNAME=nvimicro nvim --headless -u init.lua \
  -c "e $SCRATCH/a.lua" -c 'w' -c qa 2>&1
NVIM_APPNAME=nvimicro nvim --headless -u init.lua \
  -c "e $SCRATCH/b.lua" -c 'FormatDisable' -c 'w' -c qa 2>&1
echo "formatted:   $(cat "$SCRATCH/a.lua")"
echo "unformatted: $(cat "$SCRATCH/b.lua")"
rm -rf "$SCRATCH"
```
Expected:
```
formatted:   local x = 1
unformatted: local   x  =  1
```

- [ ] **Step 18: Update the README keymap table**

In `README.md`, add these rows to the keymap table, keeping the existing rows intact:

```markdown
| `<leader>fo` / `<leader>fr`                               | Recent files / resume last picker                                                  |
| `<leader>fs` / `<leader>fS`                               | Document / workspace symbols                                                       |
| `<leader>fd` / `<leader>fD`                               | Buffer / workspace diagnostics                                                     |
| `<leader>gs` / `<leader>gc`                               | Git status / git commits                                                           |
| `gD`                                                      | Goto declaration                                                                   |
| `<leader>th`                                              | Toggle inlay hints                                                                 |
```

And add this paragraph under the keymap table:

```markdown
Format-on-save is on by default. `:FormatDisable` turns it off for the current
buffer, `:FormatDisable!` for the whole session, `:FormatEnable` restores both.
Neovim 0.11 already binds `grn`, `gra`, `grr`, `gri`, `grt`, `gO` and insert-mode
`<C-s>`; the mappings above are additions, not replacements.
```

- [ ] **Step 19: Confirm the startup budget still holds**

Run:
```bash
NVIM_APPNAME=nvimicro nvim --headless -u init.lua -c 'qa' 2>&1; echo "EXIT:$?"
```
Expected: no output, `EXIT:0`.

Then interactively: `NVIM_APPNAME=nvimicro nvim -u init.lua`, run `:Lazy profile`, confirm total < 50ms. Record the number in the PR body.

- [ ] **Step 20: Commit and open the PR**

```bash
git add lua/plugins/format.lua README.md
git commit -m "feat(format): add :FormatDisable/:FormatEnable escape hatch"
git push -u origin feat/native-qol
gh pr create --base main --title "feat: native quality-of-life pass" --body "$(cat <<'EOF'
## Summary
Four zero-plugin, zero-startup-cost gaps closed:

- `gD` (goto declaration) and `<leader>th` (toggle inlay hints) — the only two LSP actions with no Neovim 0.11 native binding. The existing `gd`/`gr`/`gI` mappings are untouched.
- Eight new fzf-lua pickers: document/workspace symbols, buffer/workspace diagnostics, recent files, resume, git status, git commits.
- `:FormatDisable` / `:FormatDisable!` / `:FormatEnable` — format-on-save was previously unconditional, with no escape hatch for repos whose style this distro would fight.
- `vim.highlight.on_yank` → `vim.hl.on_yank` (deprecated since 0.11).

## Verification
- Headless load clean, `EXIT:0`.
- Every new mapping present; every picker name resolves to a real `fzf-lua` function.
- End-to-end: a badly formatted Lua buffer is fixed on `:w`, and left alone after `:FormatDisable`.
- `:Lazy profile` still under the 50ms budget.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

---

### Task 2: Bash, Dockerfile and JSON support

Branch: `feat/shell-docker-json`

`lua/plugins/treesitter.lua` already compiles the `bash`, `dockerfile` and `json` parsers and already starts highlighting for the `sh`, `bash`, `dockerfile` and `json` filetypes — but no LSP server, linter or formatter is wired behind any of them. This task closes that inconsistency. Bash and Dockerfile are core SRE filetypes; `schemastore.nvim` is already a dependency but is currently used for YAML only, so `package.json` / `tsconfig.json` get no schema validation.

**Files:**
- Modify: `lua/config/lsp.lua` (append three `vim.lsp.config` blocks, extend the `vim.lsp.enable` list)
- Modify: `lua/plugins/lint.lua` (two `linters_by_ft` entries)
- Modify: `lua/plugins/format.lua` (two `formatters_by_ft` entries)
- Modify: `README.md` (LSP / formatter / linter tables)
- Modify: `CLAUDE.md` (filetype-pipeline note)

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: the server names `bashls`, `dockerls`, `jsonls` registered on `vim.lsp.config`. Task 3's health check enumerates the binaries behind them (`bash-language-server`, `docker-langserver`, `vscode-json-language-server`, `shellcheck`, `hadolint`, `shfmt`) and must stay in sync with this task.

- [ ] **Step 1: Cut the branch**

```bash
git checkout main && git pull --ff-only
git checkout -b feat/shell-docker-json
```

- [ ] **Step 2: Write the failing check**

Run:
```bash
NVIM_APPNAME=nvimicro nvim --headless -u init.lua \
  -c 'lua for _,s in ipairs({"bashls","dockerls","jsonls"}) do io.write(s.."="..(vim.lsp.config[s] and "OK" or "MISSING").." ") end print("")' \
  -c qa 2>&1 | tail -1
```
Expected: `bashls=MISSING dockerls=MISSING jsonls=MISSING`

- [ ] **Step 3: Add the three servers**

In `lua/config/lsp.lua`, insert these blocks after the existing `lua_ls` block and before the `vim.lsp.enable({...})` call:

```lua
vim.lsp.config("bashls", {
  cmd = { "bash-language-server", "start" },
  filetypes = { "sh", "bash" },
  root_markers = { ".git" },
  capabilities = capabilities,
})

vim.lsp.config("dockerls", {
  cmd = { "docker-langserver", "--stdio" },
  filetypes = { "dockerfile" },
  root_markers = { "Dockerfile", ".git" },
  capabilities = capabilities,
})

-- schemastore.nvim was already a dependency, used for YAML only. json.schemas()
-- returns a list of {name, fileMatch, url} entries, which is the shape jsonls
-- wants -- unlike yaml.schemas(), which returns a url = fileMatch map.
vim.lsp.config("jsonls", {
  cmd = { "vscode-json-language-server", "--stdio" },
  filetypes = { "json", "jsonc" },
  root_markers = { ".git" },
  capabilities = capabilities,
  settings = {
    json = {
      schemas = require("schemastore").json.schemas(),
      validate = { enable = true },
    },
  },
})
```

Then extend the enable list at the bottom of the file to read:

```lua
vim.lsp.enable({
  "pyright", "rust_analyzer", "gopls", "terraform_ls", "ansiblels",
  "helm_ls", "yamlls", "ts_ls", "tailwindcss", "lua_ls",
  "bashls", "dockerls", "jsonls",
})
```

- [ ] **Step 4: Re-run the check**

Run: the same command as Step 2.
Expected: `bashls=OK dockerls=OK jsonls=OK`

- [ ] **Step 5: Verify the silent-degradation contract**

None of the three binaries are installed on this machine. Opening a matching file must therefore attach no client, print no error, and exit 0 — that is the whole point of the no-binaries design.

Run:
```bash
SCRATCH=$(mktemp -d)
printf '#!/usr/bin/env bash\necho hi\n' > "$SCRATCH/s.sh"
printf 'FROM alpine\nRUN echo hi\n' > "$SCRATCH/Dockerfile"
printf '{"name":"x"}\n' > "$SCRATCH/p.json"
for f in s.sh Dockerfile p.json; do
  NVIM_APPNAME=nvimicro nvim --headless -u init.lua -c "e $SCRATCH/$f" \
    -c 'lua vim.wait(2000)' \
    -c 'lua print(vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0),":t").." ft="..vim.bo.filetype.." clients="..#vim.lsp.get_clients({bufnr=0}))' \
    -c qa 2>&1; echo "EXIT:$?"
done
rm -rf "$SCRATCH"
```
Expected: `s.sh ft=sh clients=0`, `Dockerfile ft=dockerfile clients=0`, `p.json ft=json clients=0`, each with `EXIT:0` and **no traceback or error message**.

- [ ] **Step 6: Verify the jsonls schema list is real**

A broken `schemastore` call would only surface when a JSON file is opened with the server installed, so assert the table directly.

Run:
```bash
NVIM_APPNAME=nvimicro nvim --headless -u init.lua \
  -c 'lua local s=vim.lsp.config.jsonls.settings.json.schemas; assert(type(s)=="table" and #s>100, "schema list too short: "..tostring(#s)); assert(s[1].url and s[1].fileMatch, "wrong entry shape"); print("SCHEMAS_OK n="..#s)' \
  -c qa 2>&1 | tail -1
```
Expected: `SCHEMAS_OK n=<some number well over 100>`

- [ ] **Step 7: Commit the LSP half**

```bash
git add lua/config/lsp.lua
git commit -m "feat(lsp): add bashls, dockerls and jsonls"
```

- [ ] **Step 8: Write the failing check for lint and format**

Run:
```bash
NVIM_APPNAME=nvimicro nvim --headless -u init.lua \
  -c 'lua require("lazy").load({plugins={"nvim-lint","conform.nvim"}})' \
  -c 'lua local l=require("lint").linters_by_ft; local c=require("conform").formatters_by_ft; print("sh_lint="..vim.inspect(l.sh).." docker_lint="..vim.inspect(l.dockerfile).." sh_fmt="..vim.inspect(c.sh))' \
  -c qa 2>&1 | tail -1
```
Expected: `sh_lint=nil docker_lint=nil sh_fmt=nil`

- [ ] **Step 9: Add the linters**

In `lua/plugins/lint.lua`, add these entries to `lint.linters_by_ft`, after the `yaml` entries:

```lua
      sh = { "shellcheck" },
      bash = { "shellcheck" },
      dockerfile = { "hadolint" },
```

- [ ] **Step 10: Add the formatters**

In `lua/plugins/format.lua`, add these entries to `formatters_by_ft`, after the `lua` entry:

```lua
      sh = { "shfmt" },
      bash = { "shfmt" },
```

Note: JSON already routes to `prettier` in that table — leave it, `jsonls` provides schema validation, not formatting.

- [ ] **Step 11: Re-run the lint/format check**

Run: the same command as Step 8.
Expected: `sh_lint={ "shellcheck" } docker_lint={ "hadolint" } sh_fmt={ "shfmt" }`

- [ ] **Step 12: Verify a missing linter still does not throw**

`shellcheck` and `hadolint` are not installed, so this exercises the `pcall` contract in `lua/plugins/lint.lua`.

Run:
```bash
SCRATCH=$(mktemp -d)
printf '#!/usr/bin/env bash\necho hi\n' > "$SCRATCH/s.sh"
NVIM_APPNAME=nvimicro nvim --headless -u init.lua -c "e $SCRATCH/s.sh" \
  -c 'lua vim.wait(2000)' -c 'w' -c 'lua print("LINT_SURVIVED")' -c qa 2>&1
echo "EXIT:$?"
rm -rf "$SCRATCH"
```
Expected: `LINT_SURVIVED`, `EXIT:0`, no traceback.

- [ ] **Step 13: Update the README tables**

Add to the **LSP servers** table in `README.md`:

```markdown
| bash-language-server        | `brew install bash-language-server`          | `npm i -g bash-language-server` | —                                             |
| dockerfile-language-server  | `npm i -g dockerfile-language-server-nodejs` | same                        | —                                             |
| vscode-json-language-server | `npm i -g vscode-langservers-extracted`      | same                        | —                                             |
```

Add to the **Formatters** table:

```markdown
| shfmt        | `brew install shfmt` / `go install mvdan.cc/sh/v3/cmd/shfmt@latest` |
```

Add to the **Linters** table:

```markdown
| shellcheck   | `brew install shellcheck` / `apt install shellcheck` |
| hadolint     | `brew install hadolint`                          |
```

Add this sentence to the Linters section prose:

```markdown
- **hadolint** and **shellcheck** cover the two filetypes this distro already
  compiled treesitter parsers for but previously left unchecked. Both are
  optional like every other tool here.
```

- [ ] **Step 14: Update CLAUDE.md**

In `CLAUDE.md`, in the "Filetype pipeline" section, replace the closing sentence with:

```markdown
Changing either means updating the matching keys in `lsp.lua` (`filetypes`),
`format.lua` (`formatters_by_ft`), `lint.lua` (`linters_by_ft`) and the
treesitter `FileType` autocmd together. The same four-way sync applies to the
plain filetypes: `sh`/`bash` (bashls + shellcheck + shfmt), `dockerfile`
(dockerls + hadolint) and `json` (jsonls + prettier).
```

- [ ] **Step 15: Commit and open the PR**

```bash
git add lua/plugins/lint.lua lua/plugins/format.lua README.md CLAUDE.md
git commit -m "feat(lint,format): add shellcheck, hadolint and shfmt"
git push -u origin feat/shell-docker-json
gh pr create --base main --title "feat: bash, Dockerfile and JSON support" --body "$(cat <<'EOF'
## Summary
The treesitter spec already compiles the `bash`, `dockerfile` and `json` parsers and starts highlighting for those filetypes, but nothing else was wired behind them. This closes that inconsistency:

- `bashls` + `shellcheck` + `shfmt` for `sh`/`bash`
- `dockerls` + `hadolint` for `dockerfile`
- `jsonls` with the full SchemaStore catalogue for `json`/`jsonc` — `schemastore.nvim` was already a dependency but was used for YAML only, so `package.json` and `tsconfig.json` got no validation

No binaries are installed by this change; the README tables list them as usual.

## Verification
- All three servers registered on `vim.lsp.config`.
- `jsonls` schema list asserted non-empty and of the right entry shape.
- Silent-degradation contract re-verified: with none of the six new binaries installed, opening a `.sh`, a `Dockerfile` and a `.json` attaches 0 clients, writes cleanly, and exits 0 with no traceback.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

---

### Task 3: `:checkhealth nvimicro`

Branch: `feat/health-check`

The no-binaries contract makes a missing tool **invisible**: a linter that never ran looks exactly like a clean file. This adds the missing counterpart — one place where absence becomes visible on demand — and makes the README's tool tables self-verifying.

**Files:**
- Create: `lua/nvimicro/health.lua`
- Modify: `README.md` (new section)
- Modify: `CLAUDE.md` (verification section)

**Interfaces:**
- Consumes: the binary names introduced in Task 2 (`bash-language-server`, `docker-langserver`, `vscode-json-language-server`, `shellcheck`, `hadolint`, `shfmt`). If Task 2 has not merged yet, still include them — they are documented in this plan and the check simply reports them missing.
- Produces: `require("nvimicro.health").check()`, invoked by `:checkhealth nvimicro`. No later task depends on it.

- [ ] **Step 1: Cut the branch**

```bash
git checkout main && git pull --ff-only
git checkout -b feat/health-check
```

- [ ] **Step 2: Write the failing check**

Run:
```bash
NVIM_APPNAME=nvimicro nvim --headless -u init.lua \
  -c 'lua print("health="..(pcall(require,"nvimicro.health") and "OK" or "MISSING"))' \
  -c qa 2>&1 | tail -1
```
Expected: `health=MISSING`

- [ ] **Step 3: Write the health module**

Create `lua/nvimicro/health.lua`:

```lua
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
```

- [ ] **Step 4: Verify the module loads and reports honestly**

The counts must match reality on this machine: `bash-language-server`, `docker-langserver`, `vscode-json-language-server`, `shellcheck`, `hadolint` and `shfmt` are known to be absent.

Run:
```bash
NVIM_APPNAME=nvimicro nvim --headless -u init.lua \
  -c 'lua local m=require("nvimicro.health"); assert(type(m.check)=="function"); print("MODULE_OK")' \
  -c qa 2>&1 | tail -1
```
Expected: `MODULE_OK`

- [ ] **Step 5: Verify `:checkhealth nvimicro` actually runs and finds the missing tools**

Run:
```bash
NVIM_APPNAME=nvimicro nvim --headless -u init.lua \
  -c 'checkhealth nvimicro' \
  -c 'lua io.write(table.concat(vim.api.nvim_buf_get_lines(0,0,-1,false),"\n").."\n")' \
  -c 'qa!' 2>&1 | grep -E 'nvimicro:|shellcheck|hadolint|shfmt|lua-language-server|tool\(s\) missing'
```
Expected: the five `nvimicro:` section headers, `lua-language-server` reported OK, `shellcheck` / `hadolint` / `shfmt` reported not on `$PATH`, and a `6 tool(s) missing`-style summary line.

- [ ] **Step 6: Verify it did not cost startup time**

The module is only required by `:checkhealth`, so it must not be loaded at boot.

Run:
```bash
NVIM_APPNAME=nvimicro nvim --headless -u init.lua \
  -c 'lua print("loaded_at_boot="..tostring(package.loaded["nvimicro.health"] ~= nil))' \
  -c qa 2>&1 | tail -1
```
Expected: `loaded_at_boot=false`

- [ ] **Step 7: Update the README**

Add this section to `README.md`, immediately after the `## Prerequisites` intro paragraph and before the `### Treesitter` heading:

```markdown
### Checking what you have

```vim
:checkhealth nvimicro
```

Lists every tool in the tables below and whether it is on your `$PATH`. Missing
tools are reported as info, not as errors — the feature that needs them is
simply off. Since nothing here warns you at runtime, this is the only place that
absence is visible.
```

- [ ] **Step 8: Update CLAUDE.md**

In `CLAUDE.md`, under "Verifying changes", add after the interactive-checks paragraph:

```markdown
`:checkhealth nvimicro` (from `lua/nvimicro/health.lua`) reports which of the
documented external binaries are on `$PATH`. Its tool list mirrors the README
tables — when you add a server, formatter or linter, add it there too.
```

- [ ] **Step 9: Commit and open the PR**

```bash
git add lua/nvimicro/health.lua README.md CLAUDE.md
git commit -m "feat(health): add :checkhealth nvimicro for external tools"
git push -u origin feat/health-check
gh pr create --base main --title "feat: :checkhealth nvimicro" --body "$(cat <<'EOF'
## Summary
The no-binaries contract makes a missing tool invisible — a linter that never ran looks exactly like a clean file. `:checkhealth nvimicro` is the counterpart: the one place, on demand, where absence becomes visible.

It walks every tool documented in the README (treesitter, LSP servers, formatters, linters), reports each as OK or missing, and closes with a count. Missing tools are reported as **info, not warn** — an absent tool is an ordinary state in this distro, not a fault. Side benefit: the README's tool tables are now machine-checkable.

## Verification
- `:checkhealth nvimicro` runs headlessly and correctly reports the six tools absent on the test machine while marking the installed ones OK.
- `package.loaded["nvimicro.health"]` is `false` after a normal startup — zero cost to the 50ms budget.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

---

### Task 4: Treesitter textobjects

Branch: `feat/treesitter-textobjects`

The design doc (`docs/superpowers/specs/2026-08-06-nvimicro-design.md`) justifies treesitter with "Base highlighting/**textobjects** moderne", but `nvim-treesitter-textobjects` was never installed — a spec-to-code gap. This is the only task that adds a plugin.

**Files:**
- Create: `lua/plugins/textobjects.lua`
- Modify: `README.md` (keymap table)

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: nothing other tasks rely on.

**Critical API note:** the `main` branch has no module-registration system (that was the `master` branch, which this repo deliberately does not use — `lua/plugins/treesitter.lua` pins `branch = "main"`). You call `require("nvim-treesitter-textobjects").setup{}` and bind every key yourself through `require("nvim-treesitter-textobjects.select").select_textobject(query, group)` and `require("nvim-treesitter-textobjects.move").goto_next_start(query, group)`. Do not write a `textobjects = { select = { keymaps = ... } }` block inside the nvim-treesitter config — that form does not exist on `main`.

- [ ] **Step 1: Cut the branch**

```bash
git checkout main && git pull --ff-only
git checkout -b feat/treesitter-textobjects
```

- [ ] **Step 2: Write the failing check**

Run:
```bash
NVIM_APPNAME=nvimicro nvim --headless -u init.lua \
  -c 'lua print("af="..(vim.fn.maparg("af","o")~="" and "OK" or "MISSING"))' \
  -c qa 2>&1 | tail -1
```
Expected: `af=MISSING`

- [ ] **Step 3: Create the plugin spec**

Create `lua/plugins/textobjects.lua`:

```lua
-- lua/plugins/textobjects.lua
--
-- The main branch has no module registration (that was master, which
-- lua/plugins/treesitter.lua deliberately does not use): setup() takes only
-- behaviour options and every mapping is bound by hand against the capture
-- groups in the plugin's own queries/*/textobjects.scm.
return {
  "nvim-treesitter/nvim-treesitter-textobjects",
  branch = "main",
  dependencies = { "nvim-treesitter/nvim-treesitter" },
  event = { "BufReadPost", "BufNewFile" },
  config = function()
    require("nvim-treesitter-textobjects").setup({
      select = {
        -- Jump forward to the textobject if the cursor is not inside one.
        lookahead = true,
      },
      move = {
        set_jumps = true,
      },
    })

    local select = require("nvim-treesitter-textobjects.select")
    local move = require("nvim-treesitter-textobjects.move")

    -- af/if would collide with the built-in "a word"/"inner word" family only
    -- in operator/visual mode, which is exactly where they are wanted.
    local objects = {
      ["af"] = "@function.outer",
      ["if"] = "@function.inner",
      ["ac"] = "@class.outer",
      ["ic"] = "@class.inner",
      ["aa"] = "@parameter.outer",
      ["ia"] = "@parameter.inner",
    }
    for lhs, query in pairs(objects) do
      vim.keymap.set({ "x", "o" }, lhs, function()
        select.select_textobject(query, "textobjects")
      end, { desc = "Select " .. query })
    end

    -- ]f/[f mirror the ]h/[h hunk motions already bound in git.lua.
    vim.keymap.set({ "n", "x", "o" }, "]f", function()
      move.goto_next_start("@function.outer", "textobjects")
    end, { desc = "Next function start" })
    vim.keymap.set({ "n", "x", "o" }, "[f", function()
      move.goto_previous_start("@function.outer", "textobjects")
    end, { desc = "Prev function start" })
    -- NOT ]c/[c: those are Vim's built-in diff-mode next/prev change motions
    -- and rebinding them globally breaks :diffthis navigation. ]]/[[ are the
    -- built-in section motions, which treesitter supersedes meaningfully.
    vim.keymap.set({ "n", "x", "o" }, "]]", function()
      move.goto_next_start("@class.outer", "textobjects")
    end, { desc = "Next class start" })
    vim.keymap.set({ "n", "x", "o" }, "[[", function()
      move.goto_previous_start("@class.outer", "textobjects")
    end, { desc = "Prev class start" })
  end,
}
```

- [ ] **Step 4: Install the plugin**

Run:
```bash
NVIM_APPNAME=nvimicro nvim --headless -u init.lua -c 'Lazy! sync' -c qa 2>&1 | tail -5
```
Expected: nvim-treesitter-textobjects cloned, no errors.

- [ ] **Step 5: Re-run the mapping check**

The spec is `event`-triggered, so open a real file.

Run:
```bash
NVIM_APPNAME=nvimicro nvim --headless -u init.lua -c 'e lua/config/options.lua' \
  -c 'lua for _,k in ipairs({"af","if","ac","ic","aa","ia"}) do io.write(k.."="..(vim.fn.maparg(k,"o")~="" and "OK" or "MISSING").." ") end print("")' \
  -c qa 2>&1 | tail -1
```
Expected: every entry `OK`.

- [ ] **Step 6: Verify a textobject actually selects something**

Assert behaviour, not just binding presence. `daf` on a Lua function must delete the whole function.

Run:
```bash
SCRATCH=$(mktemp -d)
cat > "$SCRATCH/t.lua" <<'LUA'
local function keep_me()
  return 1
end

local function delete_me()
  return 2
end
LUA
NVIM_APPNAME=nvimicro nvim --headless -u init.lua -c "e $SCRATCH/t.lua" \
  -c 'lua vim.wait(3000, function() return vim.treesitter.highlighter.active[vim.api.nvim_get_current_buf()] ~= nil end)' \
  -c 'lua vim.api.nvim_win_set_cursor(0, {6, 2}); vim.cmd("normal daf")' \
  -c 'lua local t=table.concat(vim.api.nvim_buf_get_lines(0,0,-1,false),"|"); print((t:find("delete_me") and "FAIL: still there" or "PASS: function deleted").." | "..(t:find("keep_me") and "PASS: neighbour intact" or "FAIL: ate too much"))' \
  -c 'qa!' 2>&1 | tail -1
rm -rf "$SCRATCH"
```
Expected: `PASS: function deleted | PASS: neighbour intact`

- [ ] **Step 7: Verify the motions work**

Run:
```bash
SCRATCH=$(mktemp -d)
cat > "$SCRATCH/t.lua" <<'LUA'
local function one()
  return 1
end

local function two()
  return 2
end
LUA
NVIM_APPNAME=nvimicro nvim --headless -u init.lua -c "e $SCRATCH/t.lua" \
  -c 'lua vim.wait(3000, function() return vim.treesitter.highlighter.active[vim.api.nvim_get_current_buf()] ~= nil end)' \
  -c 'lua vim.api.nvim_win_set_cursor(0, {1, 0}); vim.cmd("normal ]f"); print("line="..vim.api.nvim_win_get_cursor(0)[1])' \
  -c 'qa!' 2>&1 | tail -1
rm -rf "$SCRATCH"
```
Expected: `line=5` (cursor moved to the start of `two`).

- [ ] **Step 8: Confirm the startup budget still holds**

This is the only task adding a plugin, so the budget check matters most here.

Run:
```bash
NVIM_APPNAME=nvimicro nvim --headless -u init.lua -c 'qa' 2>&1; echo "EXIT:$?"
```
Expected: no output, `EXIT:0`.

Then interactively: `NVIM_APPNAME=nvimicro nvim -u init.lua`, `:Lazy profile`, confirm total < 50ms and that `nvim-treesitter-textobjects` is **not** in the startup list (it is `BufReadPost`-triggered). Record the number in the PR body.

- [ ] **Step 9: Update the README**

Add these rows to the keymap table in `README.md`:

```markdown
| `af` / `if`                                               | Select a/inner function (operator + visual mode)                                   |
| `ac` / `ic`                                               | Select a/inner class                                                               |
| `aa` / `ia`                                               | Select a/inner parameter                                                           |
| `]f` / `[f`                                               | Next/prev function start                                                           |
| `]]` / `[[`                                               | Next/prev class start                                                              |
```

And add to the `## Structure` section's plugin list context, in the prose after the table:

```markdown
Textobjects come from `nvim-treesitter-textobjects` (`main` branch, matching
`nvim-treesitter`) and need the relevant parser compiled — a filetype whose
parser is still building falls back to Vim's built-in `af`/`if`, which do
nothing useful. Give a cold first launch a moment.
```

- [ ] **Step 10: Commit and open the PR**

```bash
git add lua/plugins/textobjects.lua lazy-lock.json README.md
git commit -m "feat(treesitter): add syntax-aware textobjects and motions"
git push -u origin feat/treesitter-textobjects
gh pr create --base main --title "feat: treesitter textobjects" --body "$(cat <<'EOF'
## Summary
Closes a spec-to-code gap: the design doc justifies treesitter with "highlighting/**textobjects**", but `nvim-treesitter-textobjects` was never installed.

Adds `af`/`if` (function), `ac`/`ic` (class), `aa`/`ia` (parameter) in operator and visual mode, plus `]f`/`[f` and `]c`/`[c` motions — mirroring the `]h`/`[h` hunk motions already in `git.lua`.

Pinned to `branch = "main"` to match `nvim-treesitter`. The `main` branch has no module registration, so `setup{}` takes behaviour options only and every mapping is bound explicitly — the `master`-era `textobjects = { select = { keymaps = ... } }` form does not exist and would silently do nothing.

## Verification
- All six textobject mappings present in operator-pending mode.
- Behavioural: `daf` inside a Lua function deletes exactly that function and leaves its neighbour intact.
- Behavioural: `]f` from line 1 lands on the next function's start line.
- Lazy-loaded on `BufReadPost`; `:Lazy profile` still under the 50ms budget.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

---

## Out of scope

Deliberately not in this plan, and not to be added opportunistically:

- **Bigfile guard** and **extra gitsigns keymaps** (`diffthis`, `toggle_current_line_blame`) — both real gaps, both deferred by the user's chosen order. Follow-up work.
- **`mini.surround` / `mini.pairs` / `mini.clue`** — deferred for the same reason.
- **Codelens refresh** — `grx` is bound natively but nothing calls `vim.lsp.codelens.refresh()`, so it is a dead key. Worth a small follow-up PR; not part of the four features requested.
- **DAP, toggleterm, mason, AI chat/agentic editing, colorschemes** — excluded by the design doc.
