require("swenv").setup({
  post_set_venv = function()
    vim.cmd("LspRestart")
  end,
})

local lsp_manager = require "lvim.lsp.manager"
local pyright_opts = {
  single_file_support = true,
  settings = {
    pyright = {
      disableLanguageServices = false,
      disableOrganizeImports = true,
    },
    python = {
      venvPath = "/home/alinski/.pyenv/versions/",
      analysis = {
        autoImportCompletions = true,
        autoSearchPaths = true,
        diagnosticMode = "workspace", -- openFilesOnly, workspace
        typeCheckingMode = "basic",   -- off, basic, strict
        useLibraryCodeForTypes = true,
        logLevel = "Warning",
      },
    },
  },
}

lsp_manager.setup("pyright", pyright_opts)

local formatters = require "lvim.lsp.null-ls.formatters"
formatters.setup {
  { command = "black", filetypes = { "python" }, args = { "--line-length", "98" } },
  { command = "isort", filetypes = { "python" } },
}

local linters = require "lvim.lsp.null-ls.linters"
linters.setup { { command = "flake8", args = { "--ignore=E203,E501" }, filetypes = { "python" } } }

local status_ok, which_key = pcall(require, "which-key")
if not status_ok then
  return
end

local mappings = {
  C = {
    name = "Python",
    c = { "<cmd>lua require('swenv.api').pick_venv()<cr>", "Choose Env" },
  },
}

local opts = {
  mode = "n",     -- NORMAL mode
  prefix = "<leader>",
  buffer = nil,   -- Global mappings. Specify a buffer number for buffer local mappings
  silent = true,  -- use `silent` when creating keymaps
  noremap = true, -- use `noremap` when creating keymaps
  nowait = true,  -- use `nowait` when creating keymaps
}

which_key.register(mappings, opts)
