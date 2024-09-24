local opts = {}

local lsp_manager = require "lvim.lsp.manager"
lsp_manager.setup("julials", opts)
require('lspconfig').julials.setup(opts)


