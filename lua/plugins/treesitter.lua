-- lua/plugins/treesitter.lua
return {
  "nvim-treesitter/nvim-treesitter",
  branch = "main",
  build = ":TSUpdate",
  lazy = false,
  config = function()
    local ensure_installed = {
      "lua", "vim", "vimdoc",
      "python", "rust", "go", "gomod", "gowork",
      "terraform", "hcl",
      "yaml", "helm",
      "dockerfile", "bash",
      "json", "toml", "markdown", "markdown_inline",
      "javascript", "typescript", "tsx", "html", "css",
    }
    require("nvim-treesitter").install(ensure_installed)

    -- jsonc (tsconfig.json, .eslintrc.json, ...) is JSON-with-comments; the
    -- json grammar parses it fine, so reuse the compiled json parser instead
    -- of pulling in a separate one.
    vim.treesitter.language.register("json", "jsonc")

    vim.api.nvim_create_autocmd("FileType", {
      pattern = {
        "lua", "vim", "help",
        "python", "rust", "go", "gomod", "gowork",
        "terraform", "terraform-vars", "hcl",
        "yaml", "yaml.ansible", "helm",
        "dockerfile", "sh", "bash",
        "json", "jsonc", "toml", "markdown",
        "javascript", "javascriptreact", "typescript", "typescriptreact",
        "html", "css",
      },
      callback = function()
        local ok = pcall(vim.treesitter.start)
        if not ok then
          return
        end
        vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
      end,
    })
  end,
}
