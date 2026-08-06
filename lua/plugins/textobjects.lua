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

    -- Upstream bug workaround: with no compiled parser for the buffer,
    -- nvim-treesitter-textobjects.shared.find_best_range returns `{}`
    -- (its own annotation says `Range6?`, i.e. it should return nil), and
    -- `{}` is truthy. move.lua then indexes range[3] on that empty table
    -- and throws "attempt to perform arithmetic on a nil value" -- a
    -- visible E5108 traceback on every buffer without a parser (any
    -- filetype nvim-treesitter hasn't compiled yet, gitcommit/conf/text/
    -- zsh/sql/xml/diff/make always). ]m/[m/]]/[[ replace *built-in* Vim
    -- motions globally, so this has to fail safe: skip the treesitter
    -- call and fall through to the built-in motion it replaces. The
    -- select textobjects (af/if/...) don't have this problem -- selecting
    -- nothing is already a clean no-op -- so they are left alone.
    local function has_parser()
      local ok, parser = pcall(vim.treesitter.get_parser, 0, nil, { error = false })
      return ok and parser ~= nil
    end

    local function ts_move(fn, query, builtin)
      return function()
        if not has_parser() then
          vim.cmd("normal! " .. vim.v.count1 .. builtin)
          return
        end
        fn(query, "textobjects")
      end
    end

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
    vim.keymap.set(
      { "n", "x", "o" },
      "]m",
      ts_move(move.goto_next_start, "@function.outer", "]m"),
      { desc = "Next function start" }
    )
    vim.keymap.set(
      { "n", "x", "o" },
      "[m",
      ts_move(move.goto_previous_start, "@function.outer", "[m"),
      { desc = "Prev function start" }
    )
    -- NOT ]c/[c: those are Vim's built-in diff-mode next/prev change motions
    -- and rebinding them globally breaks :diffthis navigation. ]]/[[ are the
    -- built-in section motions, which treesitter supersedes meaningfully.
    vim.keymap.set(
      { "n", "x", "o" },
      "]]",
      ts_move(move.goto_next_start, "@class.outer", "]]"),
      { desc = "Next class start" }
    )
    vim.keymap.set(
      { "n", "x", "o" },
      "[[",
      ts_move(move.goto_previous_start, "@class.outer", "[["),
      { desc = "Prev class start" }
    )
  end,
}
