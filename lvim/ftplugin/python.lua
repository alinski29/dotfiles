require("swenv").setup({
  post_set_venv = function()
    vim.cmd("LspRestart")
  end,
})

local formatters = require "lvim.lsp.null-ls.formatters"
formatters.setup {
  { command = "black", filetypes = { "python" } },
}
