local cmp = require'cmp'
  cmp.setup({
    snippet = {
      expand = function(args)
        -- For `vsnip` user.
        vim.fn["vsnip#anonymous"](args.body) -- For `vsnip` user.

        -- For `luasnip` user.
        -- require('luasnip').lsp_expand(args.body)

        -- For `ultisnips` user.
        -- vim.fn["UltiSnips#Anon"](args.body)
      end,
    },
    mapping = {
      ['<C-d>'] = cmp.mapping.scroll_docs(-4),
      ['<C-f>'] = cmp.mapping.scroll_docs(4),
      ['<C-Space>'] = cmp.mapping.complete(),
      ['<C-e>'] = cmp.mapping.close(),
      ['<CR>'] = cmp.mapping.confirm({ select = true }),
      ['<Tab>'] = cmp.mapping(cmp.mapping.select_next_item(), { 'i', 's' })
    },
    sources = {
      { name = 'nvim_diagnostic' },

      -- For vsnip user.
      { name = 'vsnip' },

      -- For luasnip user.
      -- { name = 'luasnip' },

      -- For ultisnips user.
      -- { name = 'ultisnips' },

      { name = 'buffer' },
    }
  })

local lsp_status = require('lsp-status')
lsp_status.register_progress()


local lspconfig = require('lspconfig')
local my_attach = function(client, bufnr)
  vim.api.nvim_buf_set_option(bufnr, 'omnifunc', 'v:lua.vim.lsp.omnifunc')
   -- Setup lspconfig.
  -- require'completion'.on_attach()
  lsp_status.on_attach(client)
end

lspconfig.rust_analyzer.setup {
  capabilities = lsp_status.capabilities,
  on_attach = my_attach,
  settings = {
    checkOnSave = {
          command = "clippy"
    }
  }
}

require('go').setup({
  goimport = 'gopls', -- if set to 'gopls' will use golsp format
  gofmt = 'gopls', -- if set to gopls will use golsp format
  max_line_len = 120,
  tag_transform = false,
  test_dir = '',
  comment_placeholder = '   ',
  lsp_cfg = true, -- false: use your own lspconfig
  lsp_gofumpt = true, -- true: set default gofmt in gopls format to gofumpt
  lsp_on_attach = true, -- use on_attach from go.nvim
  dap_debug = true
})
-- require('go.format').goimport()  -- goimport + gofmt
vim.api.nvim_exec([[ autocmd BufWritePre *.go :silent! lua require('go.format').goimport() ]], false)
lspconfig.gopls.setup { on_attach = my_attach }

lspconfig.pylsp.setup {
  cmd = {"pylsp"},
  filetypes = {"python"},
  on_attach = my_attach,
  root_dir = function(fname)
	  local root_files = {
		  'pyproject.toml',
		  'setup.py',
		  'setup.cfg',
		  'requirements.txt',
		  'Pipfile'
	  }
	  return lspconfig.util.root_pattern(unpack(root_files))(fname) or lspconfig.util.find_git_ancestor(fname) or lspconfig.util.path.dirname(fname) end,
  }
  -- settings = {
  --   pyls = {
  --     configurationSources = {"flake8", "mypy"},
  --     plugins = {
  -- 	  flake8 = {
  -- 	    enabled = true,
  -- 	    maxLineLength = 160
  -- 	  },
  --    	  pyls_mypy = {
  --         enabled = true,
  -- 	    live_mode = true
  -- 	  },
  -- 	  autopep8 = {
  -- 	    enabled = false
  -- 	  },
  --         rope = {
  -- 	    enabled = false
  -- 	  },
  --         pydocstyle = {
  -- 	    enabled = false
  -- 	  },
  -- 	  pycodestyle = {
  -- 	    enabled = false
  --         },
  --         yapf = {
  --           enabled = false
  --         }
  --     }
  --   }
  -- },
--   on_attach = my_attach
-- }

local system_name = 'Linux'
local sumneko_root_path = vim.fn.stdpath('cache')..'/lspconfig/sumneko_lua/lua-language-server'
local sumneko_binary = sumneko_root_path.."/bin/"..system_name.."/lua-language-server"

lspconfig.sumneko_lua.setup {
	on_attach = my_attach,
	cmd = {sumneko_binary, "-E", sumneko_root_path .. "/main.lua"};
	settings = {
	  Lua = {
	    runtime = {
	      -- Tell the language server which version of Lua you're using (most likely LuaJIT in the case of Neovim)
	      version = 'LuaJIT',
	      -- Setup your lua path
	      path = vim.split(package.path, ';'),
	    },
	    diagnostics = {
	      -- Get the language server to recognize the `vim` global
	      globals = {'vim'},
		disable = {'undefined-global'}
	    },
	    workspace = {
	      -- Make the server aware of Neovim runtime files
	      library = {
		[vim.fn.expand('$VIMRUNTIME/lua')] = true,
		[vim.fn.expand('$VIMRUNTIME/lua/vim/lsp')] = true,
	      },
	    },
	    -- Do not send telemetry data containing a randomized but unique identifier
	    telemetry = {
	      enable = false,
	    },
	  },
	},
}

vim.lsp.handlers["textDocument/publishDiagnostics"] = vim.lsp.with(
  vim.lsp.diagnostic.on_publish_diagnostics, {
    -- This will disable virtual text, like doing:
    -- let g:diagnostic_enable_virtual_text = 0
    virtual_text = false,

    -- This is similar to:
    -- let g:diagnostic_show_sign = 1
    -- To configure sign display,
    --  see: ":help vim.lsp.diagnostic.set_signs()"
    signs = true,

    -- This is similar to:
    -- "let g:diagnostic_insert_delay = 1"
    update_in_insert = false,
  }
)

require("trouble").setup {
  auto_open = true,
  auto_close = true,
  use_lsp_diagnostic_signs = false,
}

require('nvim-treesitter.configs').setup {
  ensure_installed ={"go", "rust", "python", "lua"}, -- one of "all", "maintained" (parsers with maintainers), or a list of languages
  highlight = {
    enable = true,              -- false will disable the whole extension
  },
incremental_selection = {
    enable = true,
    keymaps = {
      init_selection = '<CR>',
      scope_incremental = '<CR>',
      node_incremental = '<TAB>',
      node_decremental = '<S-TAB>',
    },
  },
  -- incremental_selection = {
  --     enable = true,
  --     keymaps = {
  --       init_selection = "gnn",
  --       node_incremental = "grn",
  --       scope_incremental = "grc",
  --       node_decremental = "grm",
  --     },
      -- indent = {
      --   enable = true
      -- }
  -- },
}

vim.fn.sign_define("DiagnosticSignError", {text="", texthl = "DiagnosticError"})
vim.fn.sign_define("DiagnosticSignWarn", {text="", texthl = "DiagnosticWarn"})
vim.fn.sign_define("DiagnosticSignInfo", {text="ⓘ", texthl = "DiagnosticSignInfo"})
vim.fn.sign_define("DiagnosticSignHint", {text="", texthl = "DiagnosticSignHint"})

-- vim.fn.sign_define(DiagnosticSignError text=Q texthl=DiagnosticSignError linenl= numhl=
-- vim.fn.sign_define(DiagnosticSignWarn text=Q texthl=DiagnosticSignWarn linenl= numhl=
-- vim.fn.sign_define(DiagnosticSignInfo text=Q texthl=DiagnosticSignInfo linenl= numhl=
-- vim.fn.sign_define(DiagnosticSignHint text=Q texthl=DiagnosticSignHint linenl= numhl=
-- vim.fn.sign_define("DiagnosticSignError", {text="Q"})
-- vim.fn.sign_define("DiagnosticSignWarn", {text="T",texthl=DiagnosticSignWarn, linenl="", numhl=""})
-- vim.fn.sign_define("DiagnosticSignInfo", {text="Q"})
-- vim.fn.sign_define("DiagnosticSignHint", {text="Q"})
-- local map = vim.api.nvim_set_keymap

-- map('i', '<tab>', [[<cmd>lua require('completion').completion_trigger()<CR>]], {noremap=true, silent=true})
-- map('i', '<tab>', [[<cmd>lua require('completion').smart_tab()<CR>]], {noremap=true, silent=true})
-- map('i', '<s-tab>', [[<cmd>lua require('completion').smart_s_tab()<CR>]], {noremap=true, silent=true})
-- map('i', '<s-tab>', [[<cmd>lua require('completion').smart_s_tab()<CR>]], {noremap=true, silent=true})
--
require('lint').linters_by_ft = {
  go = {'golangcilint',}
}
vim.api.nvim_exec([[ autocmd BufWritePost <buffer> :silent! lua require('lint').try_lint() ]], false)
-- vim.api.nvim_exec([[ autocmd DiagnosticChanged <buffer> :silent! Trouble() ]], false)
vim.diagnostic.config({virtual_text = false})
