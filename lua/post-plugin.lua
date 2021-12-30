
-- vim.g.onedark_italic_keywords = false
-- vim.g.onedark_colors = {
-- 	-- bg = "#141619",
-- 	-- bg_statusline = "#323642",
-- 	-- fg_sidebar = "#ff0000",
-- 	-- fg_gutter = "#abb2bf",
-- 	-- bg_gutter = "#141619",
-- 	-- border_highlight = "#ff0000"
-- }
vim.g.onedark_style = 'deep'
require('onedark').setup()

require('bufferline').setup {
  options = {
    show_buffer_close_icons = false,
    show_close_icon = false,
    separator_style = {"", ""},
    indicator_icon = ''
  },
  highlights = {
    buffer_selected = {
      gui = "bold",
      guibg = "#abb2bf",
      guifg = "#242b38",
    },
  },
}

require('gitsigns').setup {
  -- signs = {
    -- add          = {hl = 'GitSignsAdd'   , text = '+', numhl='GitSignsAddNr'   , linehl='GitSignsAddLn'},
    -- change       = {hl = 'GitSignsChange', text = '~', numhl='GitSignsChangeNr', linehl='GitSignsChangeLn'},
    -- delete       = {hl = 'GitSignsDelete', text = '-', numhl='GitSignsDeleteNr', linehl='GitSignsDeleteLn'},
    -- topdelete    = {hl = 'GitSignsDelete', text = '‾', numhl='GitSignsDeleteNr', linehl='GitSignsDeleteLn'},
    -- changedelete = {hl = 'GitSignsChange', text = '~', numhl='GitSignsChangeNr', linehl='GitSignsChangeLn'},
    -- }
}

require('lualine').setup {
  options = {
    theme = 'onedark',
    component_separators = {'│', '│'},
    section_separators = '',
  },
  sections = {
    lualine_c = {{'diagnostics', sources = {'nvim_diagnostic'}}},
  },
  extensions = {'quickfix'}
}

require('nvim_comment').setup()

