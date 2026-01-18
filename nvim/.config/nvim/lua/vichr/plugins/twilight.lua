return {
  'folke/twilight.nvim',
  opts = {},
  config = function()
    vim.keymap.set('n', '<leader>tw', ':Twilight<CR>', { noremap = true, silent = true, desc = 'Toggle Twilight' })
  end,
}
