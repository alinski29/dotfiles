

-- Start language servers
local lsp = require'lspconfig'
local capabilities = require('cmp_nvim_lsp').update_capabilities(vim.lsp.protocol.make_client_capabilities())

lsp.julials.setup{
   cmd = {
    "julia",
    "--project=~/.local/share/language-servers/julia",
    "--startup-file=no",
    "--history-file=no",
    "-e", "using LanguageServer, LanguageServer.SymbolServer; runserver()",
  },
  single_file_support = true,
  capabilities = capabilities
}


lsp.sumneko_lua.setup{
  capabilities = capabilities,
  single_file_support = true,
}

lsp.bashls.setup{
  capabilities = capabilities
}


lsp.gopls.setup{
  cmd = { "gopls" },
  -- single_file_support = true,
  capabilities = capabilities,
}

-- Replace <YOUR_LSP_SERVER> with each lsp server you've enabled.
