local opts = {}

opts = require("lvim.lsp").get_common_opts()
require('lspconfig').julials.setup(opts)
