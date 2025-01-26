-- Fuzzy Finder (files, lsp, etc)
return {
  'nvim-telescope/telescope.nvim',
  branch = '0.1.x',
  dependencies = {
    'nvim-lua/plenary.nvim',
    {
      'nvim-telescope/telescope-fzf-native.nvim',
      -- NOTE: If you are having trouble with this installation,
      --       refer to the README for telescope-fzf-native for more instructions.
      build = 'make',
    }

  },
  config = function()
    -- [[ Configure Telescope ]]
    -- See `:help telescope` and `:help telescope.setup()`

    local telescope_default_config = {
      defaults = vim.tbl_extend("force",
        require("telescope.themes").get_ivy(),
        {
          file_ignore_patterns = {
            "node_modules",
            ".git",
            "venv",
          },
          mappings = {
            i = {
              ['<C-u>'] = false,
              ['<C-d>'] = false,
            },
          }
        }),
      pickers = {
        find_files = {
          hidden = true
        }
      },
      extension = {
        fzf = {}
      }
    }

    require("telescope").load_extension("fzf")

    -- Merge tables
    local function merge_two_tables(t1, t2)
      for k, v in pairs(t2) do
        if (type(v) == "table") and (type(t1[k] or false) == "table") then
          merge_two_tables(t1[k], t2[k])
        else
          t1[k] = v
        end
      end
      return t1
    end


    -- Load project-specific Telescope configuration
    local function load_project_config()
      local project_config = vim.fn.getcwd() .. '/.telescope.lua'
      if vim.fn.filereadable(project_config) == 1 then
        local config = dofile(project_config)
        return config
      end
      return {}
    end



    -- Override Telescope configuration with project-specific settings
    local telescope_project_config = load_project_config()
    local final_config = merge_two_tables(telescope_default_config, telescope_project_config)
    -- print("Telescope configuration:")
    -- print(vim.inspect(final_config))
    require('telescope').setup(final_config)


    -- Enable telescope fzf native, if installed
    -- pcall(require('telescope').load_extension, 'fzf')

    -- See `:help telescope.builtin`
    vim.keymap.set('n', '<leader>?', require('telescope.builtin').oldfiles, { desc = '[?] Find recently opened files' })
    vim.keymap.set('n', '<leader><space>', require('telescope.builtin').buffers, { desc = '[ ] Find existing buffers' })
    vim.keymap.set('n', '<leader>/', function()
      -- You can pass additional configuration to telescope to change theme, layout, etc.
      require('telescope.builtin').current_buffer_fuzzy_find(require('telescope.themes').get_dropdown {
        winblend = 10,
        previewer = false,
      })
    end, { desc = '[/] Fuzzily search in current buffer' })

    vim.keymap.set('n', '<leader>gf', require('telescope.builtin').git_files, { desc = 'Search [G]it [F]iles' })
    vim.keymap.set('n', '<leader>sf', require('telescope.builtin').find_files, { desc = '[S]earch [F]iles' })
    vim.keymap.set('n', '<leader>sh', require('telescope.builtin').help_tags, { desc = '[S]earch [H]elp' })
    vim.keymap.set('n', '<leader>sw', require('telescope.builtin').grep_string, { desc = '[S]earch current [W]ord' })
    vim.keymap.set('n', '<leader>sg', require('telescope.builtin').live_grep, { desc = '[S]earch by [G]rep' })
    vim.keymap.set('n', '<leader>sd', require('telescope.builtin').diagnostics, { desc = '[S]earch [D]iagnostics' })
  end
}
