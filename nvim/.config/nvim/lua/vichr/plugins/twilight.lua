return {
  'folke/twilight.nvim',
  opts = {},
  config = function()
    vim.api.nvim_set_keymap('n', '<leader>tw', ':Twilight<CR>', { noremap = true, silent = true })
  end,
}
