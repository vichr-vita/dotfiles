return {
  -- Set lualine as statusline
  'nvim-lualine/lualine.nvim',
  dependencies = { 'vichr-vita/ai-edit.nvim' },
  -- See `:help lualine.txt`
  opts = function()
    local ai_edit = require 'ai_edit'
    return {
      options = {
        icons_enabled = true,
        theme = 'catppuccin',
        -- component_separators = '|',
        -- section_separators = '',
      },
      sections = {
        lualine_c = {
          'filename',
          { '%=', padding = 0, separator = '' },
          {
            ai_edit.statusline,
            color = ai_edit.statusline_color,
            separator = '',
          },
        },
      },
    }
  end,
}
