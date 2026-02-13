return {
  'github/copilot.vim',
  config = function()
    vim.g.copilot_no_tab_map = true
    -- Keep an explicit accept mapping and add a "dummy" <Plug> mapping.
    -- Explanation: copilot.vim's built-in Tab mapping can conflict with nvim-cmp
    -- and produce stray characters after acceptance. We disable the default
    -- Tab map and provide two ways to accept suggestions:
    -- 1) a direct user mapping (<C-J>) for manual acceptance
    -- 2) a <Plug> dummy mapping that completion plugins (nvim-cmp) can
    --    invoke programmatically. This avoids leftover characters by letting
    --    cmp drive the acceptance via feedkeys.
    vim.keymap.set('i', '<C-J>', 'copilot#Accept("<CR>")', { silent = true, expr = true, desc = 'Copilot: Accept suggestion' })
    vim.keymap.set(
      'i',
      '<Plug>(vimrc:copilot-dummy-map)',
      'copilot#Accept("")',
      { silent = true, expr = true, desc = 'Copilot dummy accept' }
    )
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
