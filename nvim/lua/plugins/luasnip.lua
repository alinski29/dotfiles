local ls = require("luasnip")
local types = require("luasnip.util.types")

ls.config.set_config({
  -- This tells LuaSnip to remember to keep around the last snippet.
  -- You can jump back into it even if you move outside of the selection.
  history = true,
  updateevents = "TextChanged,TextChangedI",
  enable_autosnippets = true,

  -- highlights
  ext_opts = {
    [types.choiceNode] = {
      active = {
        virt_text = { { "<-", "Error" } },
      },
    },
  },
})

_G.snip_jumb_back = function()
  if ls.jumpable(-1) then
    ls.jump(-1)
  end
end


-- vim.api.nvim_set_keymap("i", "<C-j>", "v: lua.snip_jumb_back<CR>", { silent = true })


-- ls.snippets = {
--  all = {
--     -- Available in any filetype
--     ls.parser.parse_snippet("expand", "-- this is what was expanded!"),
--   },
--   lua = {
--     ls.parser.parse_snippet("lf", "local $1 = function($2)\n  $0\nend")
--   }
-- }
--

--
--
--
-- -- vim.keymap.set("n", "<leader><leader>s", "<cmd>source ~/.config/nvim/lua/plugins/luasnip.lua")
-- vim.api.nvim_set_keymap("n", "<leader><leader>s", "<cmd>source ~/.config/nvim/lua/plugins/luasnip.lua")
