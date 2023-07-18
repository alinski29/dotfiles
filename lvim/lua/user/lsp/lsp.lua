lvim.builtin.treesitter.ensure_installed = {
  "scala", "go", "python", "javascript", "bash", "lua", "json", "hocon", "yaml"
}

local formatters = require "lvim.lsp.null-ls.formatters"
formatters.setup {
  { command = "google_java_format", filetypes = { "java" } },
  { command = "stylua",             filetypes = { "lua" } },
  { command = "shfmt",              filetypes = { "sh", "zsh" } },
  { command = "prettier",           filetypes = { "css" } },
}

local linters = require "lvim.lsp.null-ls.linters"
linters.setup {
  { name = "flake8" },
  {
    name = "shellcheck",
    args = { "--severity", "warning" },
  },
}

vim.list_extend(lvim.lsp.automatic_configuration.skipped_servers, { "pyright" })
