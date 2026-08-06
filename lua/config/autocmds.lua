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
