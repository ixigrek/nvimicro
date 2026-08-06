-- lua/plugins/completion.lua
return {
  "saghen/blink.cmp",
  event = "InsertEnter",
  version = "*",
  dependencies = { "zbirenbaum/copilot.lua", "giuxtaposition/blink-cmp-copilot" },
  opts = {
    keymap = {
      preset = "default",
      -- <C-CR> needs a terminal speaking the Kitty keyboard protocol to be told
      -- apart from <CR>; the preset's <C-y> stays bound as a fallback for
      -- terminals that cannot.
      ["<C-CR>"] = { "select_and_accept", "fallback" },
    },
    appearance = { nerd_font_variant = "mono" },
    completion = {
      documentation = { auto_show = true, auto_show_delay_ms = 200 },
    },
    sources = {
      default = { "lsp", "path", "snippets", "buffer", "copilot" },
      providers = {
        copilot = {
          name = "copilot",
          -- giuxtaposition/blink-cmp-copilot exposes lua/blink-cmp-copilot;
          -- "blink-copilot" is a different plugin (fang2hou) and fails to load
          module = "blink-cmp-copilot",
          score_offset = 100,
          async = true,
        },
      },
    },
  },
  opts_extend = { "sources.default" },
}
