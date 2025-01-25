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
        ensure_installed = { "prettier", "black", "debugpy", "pylint" } -- non-lsp
      }
    },
    'williamboman/mason-lspconfig.nvim',

    -- Useful status updates for LSP
    -- NOTE: `opts = {}` is the same as calling `require('fidget').setup({})`
    {
      'j-hui/fidget.nvim',
      opts = {
        notification = {
          window = {
            winblend = 0
          }
        }
      }
    },
    -- Additional lua configuration, makes nvim stuff amazing!
    'folke/neodev.nvim',
  },
}
