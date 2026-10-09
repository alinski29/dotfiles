return {
  { "EdenEast/nightfox.nvim", priority = 1000 },
  {
    "catppuccin/nvim",
    name = "catppuccin",
    -- priority = 1000,
    opts = function(_, opts)
      if (vim.g.colors_name or ""):find("catppuccin") then
        opts.highlights = require("catppuccin.special.bufferline").get_theme()
      end
    end,
  },
  -- { "ellisonleao/gruvbox.nvim" },
  { "olimorris/onedarkpro.nvim" },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "nightfox",
    },
  },
}
