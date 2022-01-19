-- Automatically install packer
local install_path = vim.fn.stdpath("data") .. "/site/pack/packer/start/packer.nvim"
if vim.fn.empty(vim.fn.glob(install_path)) > 0 then
  PACKER_BOOTSTRAP = vim.fn.system({
    "git",
    "clone",
    "--depth",
    "1",
    "https://github.com/wbthomason/packer.nvim",
    install_path,
  })
  print("Installing packer close and reopen Neovim...")
  vim.cmd([[packadd packer.nvim]])
end

-- Reload vim cionfiguration of every sync to packer.lua
vim.cmd([[
  augroup packer_user_config
    autocmd!
    autocmd BufWritePost packer.lua source <afile> | PackerSync
  augroup end
]])

local packer = require("packer")

-- Use a floating window for packer instead of a vertical split window
packer.init({
  display = {
    open_fn = function()
      return require("packer.util").float({ border = "rounded" })
    end,
  },
})

return packer.startup(function(use)
  use("wbthomason/packer.nvim")
  use("nvim-lua/plenary.nvim")
  use("kyazdani42/nvim-web-devicons")
  use("nvim-telescope/telescope.nvim") -- Fuzzy finder, file navigator
  use("navarasu/onedark.nvim") -- Theme
  use("nvim-lualine/lualine.nvim") -- Status line
  use("akinsho/bufferline.nvim") -- Buffers at the top of the screen
  use("kyazdani42/nvim-tree.lua") -- Tree-like navigation
  use("windwp/nvim-autopairs")
  use("akinsho/toggleterm.nvim")
  use("lewis6991/gitsigns.nvim")
  use("satabin/hocon-vim")
  use("tpope/vim-fugitive")

  use({ "nvim-treesitter/nvim-treesitter", run = ":TSUpdate" }) -- syntax highlighting
  use({
    "numToStr/Comment.nvim",
    config = function()
      require("Comment").setup()
    end,
  })

  -- LSP
  use("neovim/nvim-lspconfig") -- Used for setting up language servers
  use("jose-elias-alvarez/null-ls.nvim") -- Formatter and linter
  use("scalameta/nvim-metals")
  -- Autocompletion
  use("hrsh7th/nvim-cmp")
  use("hrsh7th/cmp-buffer")
  use("hrsh7th/cmp-path")
  use("hrsh7th/cmp-nvim-lua")
  use("hrsh7th/cmp-nvim-lsp")
  use("hrsh7th/cmp-cmdline")
  use("ray-x/cmp-treesitter")
  use("onsails/lspkind-nvim")
  use("L3MON4D3/LuaSnip")
end)
