return {
  'github/copilot.vim',
  config = function()
    vim.g.copilot_no_tab_map = true
    vim.keymap.set('i', '<C-J>', 'copilot#Accept("<CR>")', { silent = true, expr = true, desc = 'Copilot: Accept suggestion' })
    vim.g.copilot_filetypes = {
      ['*'] = false,
      ['javascript'] = true,
      ['typescript'] = true,
      ['lua'] = false,
      ['rust'] = true,
      ['c'] = true,
      ['c#'] = true,
      ['c++'] = true,
      ['go'] = true,
      ['python'] = true,
      ['svelte'] = true,
      ['typescriptreact'] = true,
    }
  end,
}
