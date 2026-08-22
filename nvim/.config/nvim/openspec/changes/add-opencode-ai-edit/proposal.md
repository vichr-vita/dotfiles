## Why

Small AI-assisted edits currently require switching from Neovim to a separate OpenCode session and manually naming the target file or selection. A focused in-editor prompt can shorten that loop while preserving normal buffer review, undo, and save behavior.

## What Changes

- Add `<leader>ai` for whole-buffer and visual-selection edit requests.
- Open a centered multiline prompt and execute the instruction through headless OpenCode.
- Run a restricted, runtime-generated OpenCode agent against isolated staging content rather than the real file.
- Ship a small audited OpenCode tool that provides paginated staging reads and revision-checked replacements only for the host-selected staging file; disable stock mutation tools, formatters, LSP servers, project configuration and extensions, and external user-installed plugins.
- Trust OpenCode 1.18.21's complete inseparable bundled provider/auth plugin set as pinned host code so real provider OAuth remains available, while keeping injected plugin configuration empty and all non-bundled plugin sources disabled.
- Preflight the exact OpenCode executable version, final merged configuration, and exact safe tools; abort before registry loading or session creation if the executable differs, any MCP server is configured, or managed settings undo any safety control.
- Apply a validated result as one unsaved Neovim buffer change so one `u` reverts it.
- Reject unsupported buffers, oversized input, blockwise selections, concurrent requests for one buffer, stale results, and failed or timed-out runs without changing the buffer.
- Add per-buffer asynchronous execution, cancellation, status notifications, and detailed error display.

## Capabilities

### New Capabilities

- `opencode-buffer-editing`: Prompt-driven, single-buffer edits through a scoped headless OpenCode agent, including visual selection handling, undo behavior, concurrency, and failure safety.

### Modified Capabilities

None.

## Impact

- Adds a local Lua module, an audited TypeScript OpenCode staging tool, and a Neovim setup entry for prompt UI, process management, staging, validation, and buffer application.
- Requires an `opencode` executable compatible with `opencode run`, named runtime agents, JSON event output, and `OPENCODE_CONFIG_CONTENT`.
- Uses existing Neovim APIs only; no new Neovim plugin dependency.
- Inherits trusted global OpenCode model/provider configuration and OpenCode 1.18.21's complete bundled provider/auth plugins, disables every project extension and external user-installed plugin, and lets the restricted agent read project source and instruction files as text.
- Treats the containing worktree as trusted for reads; OpenCode path checks do not prevent an in-project symlink from resolving outside the worktree.
