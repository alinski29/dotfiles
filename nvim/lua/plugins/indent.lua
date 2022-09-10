vim.opt.list = true
-- vim.opt.listchars:append("eol:↴")
-- vim.opt.listchars:append("space:⋅")

require("indent_blankline").setup({
  show_end_of_line = false,
  space_char_blankline = " ",
  -- char = "",
  show_trailing_blankline_indent = true,
  show_current_context = false,
  show_current_context_start = true,
})
