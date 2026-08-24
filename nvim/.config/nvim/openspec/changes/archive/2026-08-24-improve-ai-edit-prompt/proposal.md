## Why

The AI edit prompt is larger than needed and detached from the code being edited. Its input starts against the border, and submitted instructions cannot be recalled for reuse or refinement.

## What Changes

- Reduce the default prompt dimensions from 60 percent width by 30 percent height to 50 percent width by 20 percent height.
- Position the prompt near the invocation cursor: below cursors in the upper half of the editor and above cursors in the lower half, with bounded fallback placement on small screens.
- Add space between the source cursor and prompt plus an inset between the prompt border and editable text.
- Keep a bounded, session-local history of submitted AI edit instructions, including multiline prompts.
- Let users browse older and newer instructions with `<C-p>`/`<C-n>` or boundary-aware `<Up>`/`<Down>`, then return to the draft that existed before history navigation.
- Add automated coverage for dimensions, cursor-relative placement, clamping, padding, history ordering, multiline restoration, draft restoration, and excluded submissions.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `opencode-buffer-editing`: Change floating-prompt sizing and placement requirements and add session-local prompt history behavior.

## Impact

- Updates prompt state, layout, keymaps, and setup defaults in `lua/vichr/ai_edit.lua`.
- Extends prompt-focused headless Neovim tests under `tests/ai_edit/`.
- Adds no dependency, OpenCode permission, or persistent storage.
