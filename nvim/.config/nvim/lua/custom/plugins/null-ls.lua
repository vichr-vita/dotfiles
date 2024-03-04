return {
  "nvimtools/none-ls.nvim",
  opts = function()
    -- local augroup = vim.api.nvim_create_augroup("LspFormatting", {})
    local null_ls = require("null-ls")

    local opts = {
      sources = {
        -- js/ts
        -- null_ls.builtins.diagnostics.eslint_d,
        null_ls.builtins.formatting.prettier,
        -- python
      },
      -- the on attach formatting is handled in autoformat.lua
    }
    return opts
  end
}
