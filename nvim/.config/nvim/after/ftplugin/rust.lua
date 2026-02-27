local bufnr = vim.api.nvim_get_current_buf()

vim.keymap.set('n', '<leader>ca', function()
  vim.cmd.RustLsp 'codeAction' -- supports rust-analyzer's grouping
  -- or vim.lsp.buf.codeAction() if you don't want grouping.
end, { silent = true, buffer = bufnr, desc = '(Rust) [C]ode [A]ction' })

vim.keymap.set(
  'n',
  'K', -- Override Neovim's built-in hover keymap with rustaceanvim's hover actions
  function()
    vim.cmd.RustLsp { 'hover', 'actions' }
  end,
  { silent = true, buffer = bufnr, desc = '(Rust) hover' }
)

vim.lsp.inlay_hint.enable(true)

vim.api.nvim_buf_create_user_command(bufnr, 'IHToggle', function(_)
  vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
end, { desc = 'Format current buffer with LSP' })
