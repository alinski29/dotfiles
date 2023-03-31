lvim.plugins = {
  { "catppuccin/nvim", as = "catappucin" },
  "rebelot/kanagawa.nvim",
  "lewis6991/gitsigns.nvim",
  "olexsmir/gopher.nvim",
  {
    "scalameta/nvim-metals",
    config = function()
      require("user.metals").config()
    end,
  },
}
