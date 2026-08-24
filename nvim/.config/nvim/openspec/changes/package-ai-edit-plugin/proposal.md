## Why

AI edit is implemented and tested as private dotfiles code, so other Neovim users cannot install it without copying files and reconstructing its OpenCode requirements. Publishing it as a standalone plugin gives it one installable source, documented runtime boundaries, and repeatable release checks.

## What Changes

- Publish the implementation as the public `vichr-vita/ai-edit.nvim` repository with a conventional Neovim runtime layout.
- **BREAKING**: Replace the private `require('vichr.ai_edit')` module with the public `require('ai_edit')` API and move the trusted `stage_text` helper with it.
- Add Lazy installation and setup documentation, complete option and usage references, lualine integration, troubleshooting, security boundaries, contributor checks, and license details.
- State and check all runtime prerequisites, including supported Neovim versions and operating-system families, bounded OpenCode compatibility, provider/model configuration, first-run network access, and trusted-worktree limits.
- Add `:checkhealth ai_edit`, Vim help, repository metadata, formatting configuration, and automated tests suitable for a standalone plugin.
- Add CI for supported Neovim versions and platforms, fake-OpenCode regressions, installed OpenCode boundary checks, and an opt-in real OAuth smoke test.
- Release an initial version only after a clean install from the public repository passes documented smoke tests.
- Replace the dotfiles-local implementation with a Lazy plugin specification and retain the current model, status, and lualine configuration as consumer settings.

## Capabilities

### New Capabilities

- `ai-edit-plugin-distribution`: Installation, public module/API layout, prerequisite diagnostics, user and contributor documentation, CI, licensing, and release readiness for the standalone plugin.

### Modified Capabilities

- `opencode-buffer-editing`: Replace local-only setup with a documented public plugin API while preserving edit behavior and defaults.

## Impact

- Moves `lua/vichr/ai_edit.lua`, its trusted TypeScript helper, and `tests/ai_edit/` into the standalone plugin repository under public module paths.
- Changes require paths, internal cache/augroup identifiers where needed, test paths, and error prefixes.
- Adds README, Vim help, health checks, CI workflows, repository metadata, and a complete MIT license to the plugin repository.
- Updates this Neovim configuration to install `vichr-vita/ai-edit.nvim` through Lazy instead of loading local source.
- Supports stable OpenCode versions `>=1.18.21 <2.0.0`, with an exact matching helper SDK; no new agent permission or runtime Neovim plugin dependency is introduced.
