return {
  "nvimtools/none-ls.nvim",
  opts = function()
    local augroup = vim.api.nvim_create_augroup("LspFormatting", {})
    local null_ls = require("null-ls")

    local opts = {
      sources = {
        -- js/ts
        -- null_ls.builtins.diagnostics.eslint_d,
        null_ls.builtins.formatting.prettier,
        -- python
        -- null_ls.builtins.diagnostics.mypy,
        null_ls.builtins.diagnostics.mypy.with({
          extra_args = function()
            local virtual = os.getenv("VIRTUAL_ENV") or os.getenv("CONDA_PREFIX") or "/usr"
            return { "--python-executable", virtual .. "/bin/python3" }
          end,
        }),

        -- null_ls.builtins.diagnostics.ruff,
      },
      -- the on attach formatting is handled in autoformat.lua
    }
    return opts
  end
}
