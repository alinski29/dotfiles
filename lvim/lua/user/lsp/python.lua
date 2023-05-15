require("swenv").setup({
  post_set_venv = function()
    vim.cmd("LspRestart")
  end,
})
