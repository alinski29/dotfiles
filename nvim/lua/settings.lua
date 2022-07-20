vim.cmd([[
  syntax on
  filetype plugin indent on
  set whichwrap+=<,>,h,l,[,]
  set clipboard^=unnamed,unnamedplus
]])

local opts = {
  background = "dark",
  hidden = true,
  fileencoding = "utf-8",
  cmdheight = 2,
  ruler = true,
  mouse = "a",
  splitbelow = true,
  splitright = true,
  cursorline = true,
  relativenumber = true,
  -- 2. Set 'tabstop' and 'shiftwidth' to whatever you prefer and use 'expandtab'.
  -- This way you will always insert spaces.
  -- The formatting will never be messed up when 'tabstop' is changed.
  tabstop = 2,
  updatetime = 500,
  shiftwidth = 2,
  expandtab = true,
  smarttab = true,
  smartindent = true,
  scrolloff = 8,
  sidescrolloff = 8,
  number = true,
  timeoutlen = 500,
  clipboard = "unnamedplus",
  title = true,
  smartcase = true,
  ignorecase = true,
  termguicolors = true,
  wildmenu = true,
  wildignore = "*/node_modules/*,*/.git/*,DS_Store,*/venv/*,*/__pycache__/*,*.pyc,*/.idea/*,*/.vscode/*",
  completeopt = { "menu", "menuone", "noselect" },
}

local g = vim.opt_global
g.shortmess:remove("F") -- required by scala metals
g.completeopt = "menu,menuone,noselect"

for k, v in pairs(opts) do
  vim.opt[k] = v
end
