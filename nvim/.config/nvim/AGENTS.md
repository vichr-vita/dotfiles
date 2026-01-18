# Agent Instructions for Neovim Configuration

This repository contains the Neovim configuration for the user. It is written in Lua and utilizes `lazy.nvim` for plugin management.

## 1. Build, Lint, and Test

Since this is a configuration repository, there is no traditional "build" step. However, correctness is verified through linting and formatting.

### Formatting
- **Tool:** `stylua`
- **Configuration:** `.stylua.toml`
- **Command:** `stylua .` (Runs formatter on all Lua files)
- **Rules:**
  - Indent type: Spaces
  - Indent width: 2
  - Quote style: AutoPreferSingle (Single quotes preferred)
  - No call parentheses: true (e.g., `func 'arg'` instead of `func('arg')` where unambiguous)

### Linting
- There is currently no strict linter configuration (like `.luacheckrc`) present.
- Rely on Lua Language Server (LuaLS) diagnostics within the editor if available.
- Ensure valid Lua syntax before committing.

### Testing
- **Status:** There are currently no automated tests for this configuration.
- **Verification:** Changes must be verified manually by:
  1. Reloading Neovim (`:source %` or restarting).
  2. Checking for startup errors (`:messages`).
  3. Verifying the specific functionality changed (e.g., keymaps, plugin behavior).

## 2. Code Style & Conventions

### Directory Structure
- **Entry Point:** `init.lua`
- **User Modules:** `lua/vichr/`
- **Plugin Configs:** `lua/vichr/plugins/`
- **Plugin Manager:** `lazy.nvim`

### Lua Conventions
- **Naming:**
  - Variables/Functions: `snake_case` (local variables preferred).
  - files: `snake_case.lua`.
- **Scoping:**
  - Always use `local` for variables and functions unless they strictly need to be global (which is rare).
  - Use `vim.g`, `vim.o`, `vim.opt` for Vim settings.
- **Strings:** Use single quotes `'` by default, unless the string contains a single quote.

### Plugin Configuration (`lazy.nvim`)
- Plugin specifications go in `lua/vichr/plugins/`.
- Return a table or a list of tables.
- Preferred syntax for a plugin spec:
  ```lua
  return {
    'author/plugin-name',
    dependencies = { 'dependency-plugin' },
    event = 'VeryLazy', -- Use lazy loading where possible
    config = function()
      require('plugin-name').setup({
        -- settings here
      })
    end,
  }
  ```
- **Keymaps:** Define plugin-specific keymaps within the `keys` table of the lazy spec, or inside the `config` function if complex logic is required.

### Error Handling
- Use `pcall` (protected call) when requiring modules that might not exist or might fail (e.g., local overrides).
  ```lua
  local status_ok, module = pcall(require, "module_name")
  if not status_ok then
    return
  end
  ```

### Keymappings
- Use `vim.keymap.set` instead of the older `vim.api.nvim_set_keymap`.
- Always provide a `desc` (description) for keymaps to populate `which-key` menus.
  ```lua
  vim.keymap.set('n', '<leader>x', my_func, { desc = '[X]ecute Function' })
  ```

### General Guidelines
- **Idempotency:** Configurations should be reloadable without error where possible.
- **Comments:** Comment intent ("Why"), not just action ("What").
- **Dependencies:** Do not introduce new plugins without explicit user request. Prefer configuring existing plugins.
