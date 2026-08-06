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

    -- New keys: Vim's built-in "a word"/"inner word" family is aw/iw, not
    -- af/if, so there is no built-in to collide with. Bound in x/o only,
    -- which is where a textobject selection is used.
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

    -- ]m/[m replace Vim's built-in next/prev "start of method" motions
    -- (brace-heuristic based) with the treesitter equivalent -- a strict
    -- improvement to the same tool. NOT ]f/[f: those are Vim's built-in
    -- "same as gf" motions (jump to the file under the cursor), a distinct
    -- and still-useful capability in a Lua config full of require(...)
    -- calls, so they stay untouched.
    vim.keymap.set({ "n", "x", "o" }, "]m", function()
      move.goto_next_start("@function.outer", "textobjects")
    end, { desc = "Next function start" })
    vim.keymap.set({ "n", "x", "o" }, "[m", function()
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
