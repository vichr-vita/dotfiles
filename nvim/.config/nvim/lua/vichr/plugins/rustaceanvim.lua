return {
  'mrcjkb/rustaceanvim',
  version = '^8', -- Recommended
  lazy = false, -- this plugin is already lazy
  init = function()
    vim.g.rustaceanvim = function()
      local on_attach = require 'vichr.config.lsp_config'
      return {
        tools = {},
        server = {
          on_attach = on_attach,
          default_settings = {
            ['rust-analyzer'] = {},
          },
        },
        dap = {},
      }
    end
  end,
}
