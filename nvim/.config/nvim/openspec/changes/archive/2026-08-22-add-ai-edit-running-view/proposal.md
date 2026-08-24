## Why

AI edits leave the target buffer writable while OpenCode runs. One accidental keystroke changes the buffer revision and discards the result after a long wait, while the statusline spinner gives little useful feedback about current work.

## What Changes

- Lock the target buffer from prompt submission through terminal cleanup so normal editing cannot invalidate the captured revision.
- Hide the caret in the target window while it is locked, then restore buffer and window state on success, no-op, failure, cancellation, timeout, or stale-result rejection.
- Keep the revision check as a final defense against forced unlocks and external buffer mutation.
- Open a small, non-focusable activity float on the right side of the target window as soon as work starts.
- Show the submitted request, host preflight phases, concise tool activity, completed assistant text, and terminal state without exposing raw tool output, staging paths, or model reasoning.
- Bound and auto-scroll the activity transcript, then close it when the run reaches a terminal outcome. Existing notifications and detailed error float remain.
- Add headless coverage for lock ownership, caret restoration, activity rendering, event sanitization, concurrent buffers, and every terminal cleanup path.

## Capabilities

### New Capabilities

- `ai-edit-running-view`: Target-buffer locking, caret suppression, live OpenCode activity display, and restoration guarantees during asynchronous AI edits.

### Modified Capabilities

None.

## Impact

- Updates `lua/vichr/ai_edit.lua` job lifecycle, JSON event presentation, and floating-window management.
- Extends the fake OpenCode event stream and headless Neovim tests under `tests/ai_edit/`.
- Uses existing Neovim APIs and OpenCode 1.18.21 JSON events. No new dependency or OpenCode permission is added.
