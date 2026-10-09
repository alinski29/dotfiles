return {
  "folke/snacks.nvim",
  opts = {
    explorer = {
      -- Keep Snacks Explorer enabled, but don't auto-open it on startup
      -- or when opening Neovim with a directory.
      replace_netrw = false,
    },
    picker = {
      sources = {
        files = {
          hidden = true,
          ignored = true,
        },
        grep = {
          hidden = true,
          ignored = true,
        },
        explorer = {
          hidden = true,
          ignored = true,
          layout = { preset = "right", preview = false },
        },
      },
    },
  },
}
