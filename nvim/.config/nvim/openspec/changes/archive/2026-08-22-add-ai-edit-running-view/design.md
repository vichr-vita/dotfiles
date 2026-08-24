## Context

`vichr.ai_edit` snapshots the target buffer, closes the prompt, and runs several OpenCode preflight processes before starting `opencode run --format json`. The job keeps the captured `changedtick` and rejects the staged result if the buffer changes. The target remains writable during that wait, so ordinary typing can trigger the stale-result path. Current feedback is an animated lualine component plus start and terminal notifications.

OpenCode 1.18.21 JSON mode emits completed `text`, optional completed `reasoning`, completed or failed `tool_use`, `step_start`, `step_finish`, and error events. It does not emit partial assistant text or ordinary running-tool updates. Useful early feedback must therefore also come from host lifecycle phases.

## Goals / Non-Goals

**Goals:**

- Prevent ordinary target-buffer edits from invalidating an active request.
- Make the lock visually clear by hiding the caret only while a window displays the locked target.
- Show immediate and useful progress before and during the model run.
- Preserve one-step undo, per-buffer concurrency, cancellation, stale-result defense, and editor use in other buffers.
- Restore every owned buffer, window, and float resource on every terminal path.

**Non-Goals:**

- Interactive follow-up chat, approval UI, transcript persistence, or direct float input.
- Showing model reasoning, raw tool output, complete tool inputs, private staging paths, or session identifiers.
- Locking Neovim globally or preventing navigation to other buffers and windows.
- Removing the final buffer identity and revision checks.

## Decisions

### Make the job own a temporary `modifiable` lock

After a non-empty instruction passes the existing snapshot checks, record the target window and pre-run buffer state, register the job, and set the target buffer's `modifiable` option to false before staging or preflight work. Perform owned lock and restore transitions through buffer context with `:noautocmd setlocal` so a synchronous `OptionSet` handler cannot re-enable or mutate the buffer inside the transition. Recheck the option, text, identity, and `changedtick` after acquisition before continuing. Buffer-local locking covers every window displaying the target while leaving unrelated buffers usable. The prompt remains editable before submission.

Keep the captured `changedtick` check. A user or plugin can explicitly set `modifiable` back to true, and external code can replace or unload the buffer. Such changes still discard the staged result instead of merging it.

For successful application, first validate buffer identity, text, and revision while the lock is held. Set `modifiable` to true with an autocmd-suppressed owned transition, then immediately repeat identity, text, and `changedtick` validation before the existing single `nvim_buf_set_lines` or `nvim_buf_set_text` mutation. Keep unlock, second validation, and mutation in one protected scheduled callback with no event-loop yield. An idempotent finalizer restores the pre-run option with the same autocmd suppression on no-op, cancellation, timeout, error, stale result, and failed application. Protected calls ensure a Neovim API error cannot strand a valid buffer in the locked state.

Keeping the buffer writable and intercepting editing keys was rejected. Mappings cannot cover commands, paste, macros, plugins, or API mutations and would still permit revision races.

### Hide the active caret with an owned `guicursor` override

Define a dedicated cursor highlight with `blend=100`, which Neovim documents as hidden in the TUI. Default `guicursor` entries do not name the `Cursor` highlight and therefore use host-terminal colors, so window-local `winhighlight` remaps cannot hide the default caret. While the current window displays a locked target, append a temporary `guicursor` override that binds normal, visual, operator, insert, replace, and showmatch modes to the hidden group. Exclude command-line modes so `:AIEditCancel` and other commands retain their configured caret.

Because `guicursor` is global, use one central owner rather than per-job copies. Give the hidden override one exact, uniquely named comma-delimited option segment. `BufEnter`, `WinEnter`, job start, and job finish synchronize the override from the current buffer: locked targets activate it, unrelated buffers restore the saved base value, and switching directly between two locked targets keeps it active. An `OptionSet` guard distinguishes internal writes from user or plugin changes. If another component replaces, appends, prepends, or removes `guicursor` content while suppression is active, strip every exact owned segment from the resulting value before recording it as the new base, then append one owned segment again. The final release restores the latest normalized base value, never a value containing the hidden override.

Window-local remapping was rejected because Neovim's default `guicursor` does not reference remappable cursor highlight groups. A per-window highlight namespace has the same limitation and can replace a namespace already used by another plugin. Moving focus into the activity float was rejected because the float must not capture commands and `:AIEditCancel` must remain buffer-aware.

### Keep one bounded activity model per job

Create a readonly scratch buffer when the lock starts. Store structured activity entries in the job and render text into that buffer through short internal `modifiable` sections. Before storage, truncate every entry at UTF-8 boundaries to fit the byte and line caps; for oversized assistant text, retain the newest portion and prepend one truncation marker. Then enforce aggregate byte and line bounds by dropping oldest entries first. Replace embedded control characters that cannot be represented safely in a Neovim text buffer. A single model event therefore cannot bypass bounds or remove all newest content.

Seed the transcript with a bounded copy of the submitted request and a host phase. Update phases before version checking, global configuration resolution, helper preparation, runtime configuration checking, agent checking, and model execution. These entries cover the period before OpenCode emits session events.

Map OpenCode events through a small presentation allowlist:

- Completed `text` becomes assistant text.
- Completed or failed `tool_use` becomes a concise label derived from the tool name and selected safe fields. `stage_text` reports target/context reads or submission without paths or replacement content.
- Step events may update the current phase without dumping their payload.
- Reasoning, raw tool output, session IDs, timestamps, staging paths, and unknown payloads are not rendered.

Presentation never affects existing event validation. The same parser still records errors, sessions, and exact `stage_text` submit cardinality from the original event.

Passing `--thinking` was rejected. It would expose provider reasoning and still would not guarantee incremental output.

### Anchor a passive float to a visible target window

Open one non-focusable, mouse-transparent rounded float per visible job. Anchor it inside the right edge of a window displaying the target. Derive width and height from that window and clamp both for narrow layouts. Use wrapping and keep the newest rendered line visible. Recompute placement on resize and when the target moves between windows.

If no window displays the target, keep collecting bounded activity but close the float. Reopen it with current content when the target becomes visible. If several windows display one target, prefer the current window and otherwise the initiating window. Concurrent jobs keep separate transcript buffers and may show separate floats in separate target windows.

The float never changes current window or buffer. Terminal finalization closes it and deletes its scratch buffer before existing success or failure feedback. Detailed failures continue to open in the existing centered error float.

A split window was rejected because it changes layout. A cursor-relative float was rejected because its position would move and obscure the edit target.

## Risks / Trade-offs

- [A user or plugin force-enables `modifiable`] -> Retain buffer identity, text, and `changedtick` validation before application.
- [`OptionSet` mutates during owned lock transitions] -> Use autocmd-suppressed option writes and validate after both lock and unlock.
- [A global cursor override affects another buffer] -> Synchronize on current-buffer changes, exclude command-line modes, and restore the latest saved base whenever the current buffer is not locked.
- [`guicursor` changes during suppression] -> Guard internal writes, strip exact owned segments before capturing the new base, and append exactly one hidden override.
- [OpenCode emits large or malformed display content] -> Allowlist event fields, sanitize controls, and enforce byte and line caps.
- [OpenCode emits no text until completion] -> Show host phases and completed tool activity as the primary live signal.
- [A GUI does not honor cursor blend] -> Buffer locking and activity feedback still work; tests verify Neovim highlight state rather than terminal pixels.
- [Target is hidden or its window closes] -> Close only the view, retain job activity, and restore it when the target is visible again.
- [Unlock and application diverge after an API error] -> Run validation, unlock, mutation, and restoration under one protected main-loop callback.

## Migration Plan

1. Add lock, caret, transcript, and float state to each job without changing OpenCode permissions or staging behavior.
2. Extend fake events and headless tests for lifecycle phases, assistant text, tool summaries, concurrent jobs, navigation, resizing, forced stale mutation, and all terminal outcomes.
3. Add a pseudo-terminal TUI check that starts with default `guicursor` and verifies actual cursor visibility on locked-target, unrelated-buffer, command-line, and cleanup transitions.
4. Run formatting, headless AI-edit tests, clean startup, and installed OpenCode smoke checks.

Rollback removes the running-view lifecycle and restores the previous writable-buffer plus statusline-only behavior. No data migration exists.

## Open Questions

None.
