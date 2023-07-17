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
