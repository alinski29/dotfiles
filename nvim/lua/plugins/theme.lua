local onedark = require("onedark")
local nightfox = require("nightfox")
onedark.setup({
  style = "warmer",
  code_style = {
    comments = "italic",
    keywords = "none",
    functions = "bold",
    strings = "none",
    variables = "none",
  },
})
nightfox.setup({
  options = {
    -- Compiled file's destination location
    compile_path = vim.fn.stdpath("cache") .. "/nightfox",
    compile_file_suffix = "_compiled", -- Compiled file suffix
    transparent = false, -- Disable setting background
    terminal_colors = true, -- Set terminal colors (vim.g.terminal_color_*) used in `:terminal`
    dim_inactive = false, -- Non focused panes set to alternative background
    styles = { -- Style to be applied to different syntax groups
      comments = "italic", -- Value is any valid attr-list value `:help attr-list`
      conditionals = "bold,italic",
      constants = "bold,italic",
      functions = "bold",
      keywords = "NONE",
      -- numbers = "NONE",
      -- operators = "NONE",
      -- strings = "NONE",
      -- types = "bold",
      -- variables = "NONE",
    },
    inverse = { -- Inverse highlight for different types
      match_paren = false,
      visual = false,
      search = false,
    },
    modules = {},
  }
})
-- theme.load()
vim.cmd("colorscheme nightfox")
