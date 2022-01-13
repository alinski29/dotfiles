vim.cmd [[
  syntax on
  filetype plugin indent on
]]


-- set completeopt=menu,menuone,noselect
local opt = vim.o
local bopt = vim.bo
local g = vim.g

vim.opt_global.shortmess:remove("F")

g.completeopt='menu,menuone,noselect'
opt.completeopt='menu,menuone,noselect'

g.mapleader = ' '
-- Theming
-- g.onedark_style = 'cool'
opt.background = 'dark'
opt.showtabline=2
opt.hidden = true
opt.encoding = 'utf-8'
opt.fileencoding = 'utf-8'
opt.ruler = true
opt.mouse = 'a'
opt.splitbelow = true
opt.splitright = true
opt.cursorline = true
opt.relativenumber = true

-- 2. Set 'tabstop' and 'shiftwidth' to whatever you prefer and use 'expandtab'.
-- This way you will always insert spaces.
-- The formatting will never be messed up when 'tabstop' is changed.
opt.showtabline = 1
opt.tabstop = 2
-- opt.softtabstop = 2
opt.shiftwidth = 2
opt.expandtab = true
opt.smarttab = true
opt.autoindent = true
opt.smartindent = true

opt.number = true
opt.clipboard = 'unnamedplus'
opt.title = true
opt.smartcase = true
opt.ignorecase = true
opt.termguicolors = true
opt.wildmenu = true
opt.wildignore = '*/node_modules/*,*/.git/*,DS_Store,*/venv/*,*/__pycache__/*,*.pyc,*/.idea/*,*/.vscode/*'
