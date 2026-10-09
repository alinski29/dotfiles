return {
  "MeanderingProgrammer/render-markdown.nvim",
  ft = { "markdown", "gitcommit" },
  dependencies = {
    "nvim-treesitter/nvim-treesitter",
    -- Pick one icon provider if you don't already have one installed.
    "nvim-tree/nvim-web-devicons",
  },
  opts = {
    preset = "lazy",
  },
}
