require'nvim-treesitter.configs'.setup {
  ensure_installed = {'python', 'go', 'julia', 'scala', 'javascript', 'html', 'json', 'lua'},
  highlight = {
    enable = true,
    additional_vim_regex_highlighting = false,
  },
  indent = {
    enable = true,
  }
}
