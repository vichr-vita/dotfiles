-- NOTE: This is where your plugins related to LSP can be installed.
--  The configuration is done below. Search for lspconfig to find it below.
return {
  -- LSP Configuration & Plugins
  'neovim/nvim-lspconfig',

  dependencies = {
    -- Automatically install LSPs to stdpath for neovim
    {
      'williamboman/mason.nvim',
      config = true,
      opts = {
        ensure_installed = { 'prettier', 'black', 'debugpy', 'pylint' }, -- non-lsp
        PATH = 'append',
      },
    },
    'williamboman/mason-lspconfig.nvim',
    -- 'saghen/blink.cmp', -- removed in favor of hrsh7th/nvim-cmp

    -- Useful status updates for LSP
    -- NOTE: `opts = {}` is the same as calling `require('fidget').setup({})`
    {
      'j-hui/fidget.nvim',
      opts = {
        notification = {
          window = {
            winblend = 0,
          },
        },
      },
    },
    -- Additional lua configuration, makes nvim stuff amazing!
    'folke/neodev.nvim',
  },
  config = function()
    -- Enable the following language servers
    --  Feel free to add/remove any LSPs that you want here. They will automatically be installed.
    --
    --  Add any additional override configuration in the following tables. They will be passed to
    --  the `settings` field of the server config. You must look up that documentation yourself.
    local servers = {
      -- clangd = {},
      gopls = {
        gopls = {
          analyses = {
            unusedparams = true,
          },
          staticcheck = true,
          -- gofumpt = true,
        },
      },
      pyright = {},
      lua_ls = {
        Lua = {
          workspace = { checkThirdParty = false },
          telemetry = { enable = false },
        },
      },
      -- ts_ls = {
      --   -- cmd = { 'typescript-language-server', '--stdio' },
      --   initializationOptions = {
      --     tsserver = {
      --       path = '/Some/path/node_modules/typescript/lib',
      --     },
      --   },
      --   typescript = {
      --     tsdk = { '/Some/path/node_modules/typescript/lib' },
      --   },
      -- },
      eslint = {},
    }

    -- Setup neovim lua configuration
    require('neodev').setup()

    -- Specify how the border looks like
    local border = {
      { '┌', 'FloatBorder' },
      { '─', 'FloatBorder' },
      { '┐', 'FloatBorder' },
      { '│', 'FloatBorder' },
      { '┘', 'FloatBorder' },
      { '─', 'FloatBorder' },
      { '└', 'FloatBorder' },
      { '│', 'FloatBorder' },
    }

    -- Add border to the diagnostic popup window
    vim.diagnostic.config {
      virtual_text = {
        prefix = '■ ', -- Could be '●', '▎', 'x', '■', , 
      },
      float = { border = border },
    }

    -- Add the border on hover and on signature help popup window
    local handlers = {
      ['textDocument/hover'] = vim.lsp.with(vim.lsp.handlers.hover, { border = border }),
      ['textDocument/signatureHelp'] = vim.lsp.with(vim.lsp.handlers.signature_help, { border = border }),
    }

    local on_attach = require 'vichr.config.lsp_config'

    local capabilities = vim.lsp.protocol.make_client_capabilities()
    local ok_cmp, cmp_nvim_lsp = pcall(require, 'cmp_nvim_lsp')
    if ok_cmp and cmp_nvim_lsp and cmp_nvim_lsp.default_capabilities then
      capabilities = cmp_nvim_lsp.default_capabilities(capabilities)
    end

    -- Ensure the servers above are installed and configure them using the
    -- new native `vim.lsp.config()` API. mason-lspconfig v2 removed
    -- `setup_handlers()` and the `handlers` setting; servers should be
    -- registered with `vim.lsp.config()` (or via an {after/}lsp/*.lua file)
    -- before calling `mason-lspconfig.setup()` so mason can install them.
    local mason_lspconfig = require 'mason-lspconfig'

    for server_name, server_settings in pairs(servers) do
      if server_name ~= 'rust_analyzer' then
        local server_opts = {
          capabilities = capabilities,
          on_attach = on_attach,
          settings = server_settings,
          handlers = handlers,
        }

        -- Preferred new API
        vim.lsp.config(server_name, server_opts)
      end
    end

    mason_lspconfig.setup {
      ensure_installed = vim.tbl_keys(servers),
      -- mason-lspconfig v2 introduced `automatic_enable` to replace the
      -- old handlers-based automatic setup. Allow mason to enable servers
      -- configured through `vim.lsp.config()`.
      automatic_enable = true,
    }

  end,
}
