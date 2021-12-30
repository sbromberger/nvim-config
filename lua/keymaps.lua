local map = vim.api.nvim_set_keymap

map('n', '<C-L>', ':noh<CR><C-L>', { noremap = true})
map('n', '<esc>', [[<Cmd>lua CloseHover()<CR>]], {noremap=true, silent=true})

-- activate visual mode in normal mode, and map in visual mode
map('n', '<S-Down>', 'Vj', {noremap=true, silent=true})
map('n', '<S-Up>', 'Vk', {noremap=true, silent=true})
map('v', '<S-Down>', 'j', {noremap=true, silent=true})
map('v', '<S-Up>', 'k', {noremap=true, silent=true})
map('v', '<C-Down>', '<C-f>', {noremap=true, silent=true})
map('v', '<C-Up>', '<C-b>', {noremap=true, silent=true})

map('n', '<C-Down>', '<C-f>', {noremap=true, silent=true})
map('n', '<C-Up>', '<C-b>', {noremap=true, silent=true})

-- switch between tabs
map('n', '<C-Left>', ':bprev<CR>', {noremap=true, silent=true})
map('n', '<C-Right>', ':bnext<CR>', {noremap=true, silent=true})

--  shift between quickfix and editing window
map('n', '<Tab>', '<C-w><C-w>', {noremap=true, silent=true})

-- ^G provides details
map('n', '<C-G>', '1<C-G>', {noremap=true, silent=true})

-- navigate popups
-- inoremap <expr> <Tab>   pumvisible() ? "\<C-n>" : "\<Tab>"
-- inoremap <expr> <S-Tab> pumvisible() ? "\<C-p>" : "\<S-Tab>"
--

-- completion and lsp
-- nnoremap <silent> gd    <cmd>lua vim.lsp.buf.declaration()<CR>
-- nnoremap <silent> <c-]> <cmd>lua vim.lsp.buf.definition()<CR>
-- nnoremap <silent> K     <cmd>lua vim.lsp.buf.hover()<CR>
-- nnoremap <silent> gD    <cmd>lua vim.lsp.buf.implementation()<CR>
-- nnoremap <silent> <c-k> <cmd>lua vim.lsp.buf.signature_help()<CR>
-- nnoremap <silent> 1gD   <cmd>lua vim.lsp.buf.type_definition()<CR>
-- nnoremap <silent> gr    <cmd>lua vim.lsp.buf.references()<CR>
-- nnoremap <silent> g0    <cmd>lua vim.lsp.buf.document_symbol()<CR>
-- nnoremap <silent> gh    <cmd>lua vim.lsp.diagnostic.show_line_diagnostics()<CR>
map('n', 'gd', [[<cmd>lua vim.lsp.buf.declaration()<CR>]], {noremap=true, silent=true})
map('n', '<c-]>', [[<cmd>lua vim.lsp.buf.definition()<CR>]], {noremap=true, silent=true})
map('n', 'K', [[<cmd>lua vim.lsp.buf.hover()<CR>]], {noremap=true, silent=true})
map('n', 'gD', [[<cmd>lua vim.lsp.buf.implementation()<CR>]], {noremap=true, silent=true})
map('n', '<c-k>', [[<cmd>lua vim.lsp.buf.signature_help()<CR>]], {noremap=true, silent=true})
map('n', '1gD', [[<cmd>lua vim.lsp.buf.type_definition()<CR>]], {noremap=true, silent=true})
map('n', 'gr', [[<cmd>lua vim.lsp.buf.references()<CR>]], {noremap=true, silent=true})
map('n', 'g0', [[<cmd>lua vim.lsp.buf.document_symbol()<CR>]], {noremap=true, silent=true})
map('n', 'gh', [[<cmd>lua vim.diagnostic.open_float(0, { scope = "line", border = "single" })<CR>]], {noremap=true, silent=true})
-- map('n', 'gh', [[<cmd>lua vim.lsp.diagnostic.show_line_diagnostics()<CR>]], {noremap=true, silent=true})
map('n', '<c-t>', ':Telescope<CR>', {noremap=true, silent=true})

-- inoremap <expr> <Tab>   pumvisible() ? "\<C-n>" : "\<Tab>"
-- inoremap <expr> <S-Tab> pumvisible() ? "\<C-p>" : "\<S-Tab>"
--
map('n', '<c-n>', [[<cmd>lua require('trouble').next({skip_groups=true, jump=true})<CR>]], {noremap=true, silent=true})
map('n', '<c-p>', [[<cmd>lua require('trouble').previous({skip_groups=true, jump=true})<CR>]], {noremap=true, silent=true})

map('n', '<c-p>', [[<cmd>lua require('trouble').previous({skip_groups=true, jump=true})<CR>]], {noremap=true, silent=true})

-- map('i', '<tab>', [[<cmd>lua require('completion').smart_tab()<CR>]], {noremap=true, silent=true})
-- map('i', '<s-tab>', [[<cmd>lua require('completion').smart_s_tab()<CR>]], {noremap=true, silent=true})
