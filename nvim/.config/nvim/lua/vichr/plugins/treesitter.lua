local languages = { 'c', 'cpp', 'go', 'lua', 'python', 'rust', 'tsx', 'typescript', 'vimdoc', 'vim', 'sql', 'html', 'css', 'markdown', 'markdown_inline' }

return {
  -- Highlight, edit, and navigate code
  'nvim-treesitter/nvim-treesitter',
  branch = 'main',
  lazy = false,
  dependencies = {
    {
      'nvim-treesitter/nvim-treesitter-textobjects',
      branch = 'main',
      config = function()
        require('nvim-treesitter-textobjects').setup {
          select = {
            lookahead = true,
          },
          move = {
            set_jumps = true,
          },
        }

        vim.keymap.set({ 'x', 'o' }, 'aa', function()
          require('nvim-treesitter-textobjects.select').select_textobject('@parameter.outer', 'textobjects')
        end)
        vim.keymap.set({ 'x', 'o' }, 'ia', function()
          require('nvim-treesitter-textobjects.select').select_textobject('@parameter.inner', 'textobjects')
        end)
        vim.keymap.set({ 'x', 'o' }, 'af', function()
          require('nvim-treesitter-textobjects.select').select_textobject('@function.outer', 'textobjects')
        end)
        vim.keymap.set({ 'x', 'o' }, 'if', function()
          require('nvim-treesitter-textobjects.select').select_textobject('@function.inner', 'textobjects')
        end)
        vim.keymap.set({ 'x', 'o' }, 'ac', function()
          require('nvim-treesitter-textobjects.select').select_textobject('@class.outer', 'textobjects')
        end)
        vim.keymap.set({ 'x', 'o' }, 'ic', function()
          require('nvim-treesitter-textobjects.select').select_textobject('@class.inner', 'textobjects')
        end)

        vim.keymap.set({ 'n', 'x', 'o' }, ']m', function()
          require('nvim-treesitter-textobjects.move').goto_next_start('@function.outer', 'textobjects')
        end)
        vim.keymap.set({ 'n', 'x', 'o' }, ']]', function()
          require('nvim-treesitter-textobjects.move').goto_next_start('@class.outer', 'textobjects')
        end)
        vim.keymap.set({ 'n', 'x', 'o' }, ']M', function()
          require('nvim-treesitter-textobjects.move').goto_next_end('@function.outer', 'textobjects')
        end)
        vim.keymap.set({ 'n', 'x', 'o' }, '][', function()
          require('nvim-treesitter-textobjects.move').goto_next_end('@class.outer', 'textobjects')
        end)
        vim.keymap.set({ 'n', 'x', 'o' }, '[m', function()
          require('nvim-treesitter-textobjects.move').goto_previous_start('@function.outer', 'textobjects')
        end)
        vim.keymap.set({ 'n', 'x', 'o' }, '[[', function()
          require('nvim-treesitter-textobjects.move').goto_previous_start('@class.outer', 'textobjects')
        end)
        vim.keymap.set({ 'n', 'x', 'o' }, '[M', function()
          require('nvim-treesitter-textobjects.move').goto_previous_end('@function.outer', 'textobjects')
        end)
        vim.keymap.set({ 'n', 'x', 'o' }, '[]', function()
          require('nvim-treesitter-textobjects.move').goto_previous_end('@class.outer', 'textobjects')
        end)

        vim.keymap.set('n', '<leader>a', function()
          require('nvim-treesitter-textobjects.swap').swap_next '@parameter.inner'
        end)
        vim.keymap.set('n', '<leader>A', function()
          require('nvim-treesitter-textobjects.swap').swap_previous '@parameter.inner'
        end)
      end,
    },
  },
  build = ':TSUpdate',
  config = function()
    require('nvim-treesitter').setup {}

    vim.api.nvim_create_autocmd('FileType', {
      pattern = languages,
      callback = function()
        vim.treesitter.start()
        vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
      end,
    })

    -- Diagnostic keymaps
    vim.keymap.set('n', '[d', vim.diagnostic.goto_prev, { desc = 'Go to previous diagnostic message' })
    vim.keymap.set('n', ']d', vim.diagnostic.goto_next, { desc = 'Go to next diagnostic message' })
    vim.keymap.set('n', '<leader>e', vim.diagnostic.open_float, { desc = 'Open floating diagnostic message' })
    vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostics list' })
  end,
}
