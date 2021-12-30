local utils = require('utils')
vim.g.mapleader = ','
vim.opt.shortmess:append({ I = true })
vim.opt.shortmess:append({ c = true})  -- disables splash screen
vim.opt.redrawtime = 10000
vim.opt.timeoutlen = 1000
vim.opt.ttimeoutlen = 10	-- sets delay for escape char
vim.opt.splitbelow = true
vim.opt.signcolumn = "auto:1-3"
vim.opt.number = true
vim.opt.showmode = false    			-- disable show mode since liteline has it already
vim.opt.history = 1000 			-- save 1000 ex commands
vim.opt.inccommand = "nosplit"  		-- live substition
vim.opt.cursorline = true
vim.opt.undofile = true
vim.opt.completeopt = "menuone,noinsert,noselect"
vim.opt.wildoptions = "pum"
vim.opt.termguicolors = true
vim.opt.scrolloff = 10
vim.opt.scrolljump = 5
vim.opt.laststatus = 2
vim.opt.hidden = true


function CloseHover()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local config = vim.api.nvim_win_get_config(win);
    if config.relative ~= "" then
      vim.api.nvim_win_close(win, false)
    end
  end
end

local autocmds = {
	textyank = {
		{'TextYankPost', '*', 'silent! lua vim.highlight.on_yank({timeout=250})'},
		{'TextYankPost', '*', 'if v:event.operator is "y" && v:event.regname is "" | OSCYankReg " | endif'}
--		{'BufWritePre', '*.go', 'silent! lua setupgo()'}
	};
}

utils.nvim_create_augroups(autocmds)
