vim.cmd [[packadd packer.nvim]]

return require('packer').startup(function()
  -- Packer can manage itself
  use 'wbthomason/packer.nvim'
 
  -- Colorscheme
  -- use {'dracula/vim', as = 'dracula'}
  -- use 'shaunsingh/nord.nvim'
  use 'navarasu/onedark.nvim'

  -- use({
  --     'rose-pine/neovim',
  --     as = 'rose-pine',
  --     tag = 'v0.1.0', -- Optional tag release
  --     config = function()
  --         vim.cmd('colorscheme rose-pine')
  --     end
  --})
  

  -- Better syntax highlighting
  use {
    'nvim-treesitter/nvim-treesitter',
    run = ":TSUpdate"
  }

  -- Fuzzy finder, file navigator
  use {
    'nvim-telescope/telescope.nvim',
    requires = { {'nvim-lua/plenary.nvim'} }
  }

  -- Status line
  use {
    'nvim-lualine/lualine.nvim',
    requires = {'kyazdani42/nvim-web-devicons', opt = true}
  }

  -- Buffers at the top of the screen
  use {
    'akinsho/bufferline.nvim',
    requires = 'kyazdani42/nvim-web-devicons'
  }

  use {
    'numToStr/Comment.nvim',
    config = function()
        require('Comment').setup()
    end
  }

  use {'neovim/nvim-lspconfig'}
 
  -- Autocompletion
  use 'hrsh7th/nvim-cmp'
  use 'hrsh7th/cmp-buffer'
  use 'hrsh7th/cmp-path'
  use 'hrsh7th/cmp-nvim-lua'
  use 'hrsh7th/cmp-nvim-lsp'
  use 'hrsh7th/cmp-cmdline'
  use 'ray-x/cmp-treesitter'
  use 'onsails/lspkind-nvim'
  use 'L3MON4D3/LuaSnip'
  
  use {
    'kyazdani42/nvim-tree.lua',
    requires = {
      'kyazdani42/nvim-web-devicons', -- optional, for file icon
    },
 }
 
  use 'windwp/nvim-autopairs'

  -- Terminal
  use {"akinsho/toggleterm.nvim"}

  use({'scalameta/nvim-metals', requires = { "nvim-lua/plenary.nvim" }})
end)
