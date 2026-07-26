return {
  'folke/sidekick.nvim',
  event = 'VeryLazy',
  opts = {
    nes = {
      enabled = true,
    },
  },
  config = function(_, opts)
    require('sidekick').setup(opts)

    -- Copilot's `edits` array contains alternative suggestions. Sidekick
    -- currently renders and applies every item, corrupting text when their
    -- ranges overlap. Keep one alternative until Sidekick supports cycling.
    local nes = require 'sidekick.nes'
    local handler = nes._handler
    nes._handler = function(err, result, ctx, config)
      if result and result.edits and #result.edits > 1 then
        result = vim.deepcopy(result)
        result.edits = { result.edits[1] }
      end

      return handler(err, result, ctx, config)
    end

    vim.lsp.inline_completion.enable()
  end,
  keys = {
    {
      '<C-j>',
      function()
        if require('sidekick').nes_jump_or_apply() then
          return
        end

        if vim.lsp.inline_completion.get() then
          return
        end

        return '<C-j>'
      end,
      mode = { 'i', 'n' },
      expr = true,
      desc = 'Sidekick: Apply next edit or inline completion',
    },
  },
}
