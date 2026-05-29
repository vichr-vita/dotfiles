return {
  'nvimtools/none-ls.nvim',
  dependencies = {
    'nvimtools/none-ls-extras.nvim',
  },
  opts = function()
    -- local augroup = vim.api.nvim_create_augroup("LspFormatting", {})
    -- local null_ls = require 'null-ls'

    local opts = {
      sources = {},
      -- the on attach formatting is handled in autoformat.lua
    }
    return opts
  end,
}
