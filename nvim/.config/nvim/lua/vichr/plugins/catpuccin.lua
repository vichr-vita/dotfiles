return {
  "catppuccin/nvim",
  name = "catppuccin",
  priority = 1000,
  config = function()
    -- -- Custom colorscheme
    -- -- vim.cmd("colorscheme vichr")
    -- ---@diagnostic disable-next-line: missing-fields
    require("catppuccin").setup({
      flavour = "mocha",             -- latte, frappe, macchiato, mocha
      transparent_background = true, -- disables setting the background color.
      show_end_of_buffer = false,    -- shows the '~' characters after the end of buffers
      term_colors = true,            -- sets terminal colors (e.g. `g:terminal_color_0`)
      dim_inactive = {
        enabled = false,             -- dims the background color of inactive window
        shade = "dark",
        percentage = 0.15,           -- percentage of the shade to apply to the inactive window
      },
      color_overrides = {},
      ---@diagnostic disable-next-line: missing-fields
      integrations = {
        cmp = true,
        gitsigns = true,
        treesitter = true,
        notify = false,
      }
    })

    vim.cmd "colorscheme catppuccin"
  end
}
