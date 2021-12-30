 -- This file can be loaded by calling `lua require('plugins')` from your init.vim

-- Only required if you have packer configured as `opt`
vim.cmd [[packadd packer.nvim]]
-- Only if your version of Neovim doesn't have https://github.com/neovim/neovim/pull/12632 merged
-- vim._update_package_paths()

return require('packer').startup(function()
  -- Packer can manage itself
  use 'wbthomason/packer.nvim'
  use 'neovim/nvim-lspconfig'
  use 'nvim-lua/lsp-status.nvim'
  use 'nvim-lua/lsp_extensions.nvim'
  use 'mfussenegger/nvim-lint'
  use {
    "hrsh7th/nvim-cmp",
    requires = {
      "hrsh7th/cmp-buffer", "hrsh7th/cmp-nvim-lsp",
      'hrsh7th/cmp-nvim-lua', 'hrsh7th/cmp-path', 'hrsh7th/cmp-calc',
      'hrsh7th/cmp-emoji'
        }
    }
    -- use {
    --     'tzachar/cmp-tabnine',
    --     run = './install.sh',
    --     requires = 'hrsh7th/nvim-cmp'
    -- }
  -- use 'nvim-lua/completion-nvim'
  use 'ray-x/go.nvim'
  -- use 'mfussenegger/nvim-dap'
  -- use 'mfussenegger/nvim-dap-ui'
  -- use 'theHamsta/nvim-dap-virtual-text'
  use 'kyazdani42/nvim-web-devicons'
  use 'akinsho/nvim-bufferline.lua'
  use 'navarasu/onedark.nvim'
 -- use 'monsonjeremy/onedark.nvim'
  use 'terrortylor/nvim-comment'
  use {'nvim-treesitter/nvim-treesitter', run = ':TSUpdate'}  -- Treesitter parsing
  use {'folke/trouble.nvim', branch = 'main'}
  use {'lewis6991/gitsigns.nvim', requires = { 'nvim-lua/plenary.nvim' }}
  use {'hoob3rt/lualine.nvim', requires = {'kyazdani42/nvim-web-devicons', opt = true}}
  use 'ojroques/vim-oscyank'
  use {
    'nvim-telescope/telescope.nvim',
    requires = {{'nvim-lua/popup.nvim'}, {'nvim-lua/plenary.nvim'}}
  }
  use 'rrethy/vim-illuminate'
end)
