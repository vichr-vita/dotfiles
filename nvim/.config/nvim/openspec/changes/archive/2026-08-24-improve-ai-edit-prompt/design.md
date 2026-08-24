## Context

`open_prompt` currently creates one editor-relative floating window, sizes it from `width` and `height` fractions, and centers it in the editor. The prompt buffer begins in the first content cell, so Neovim's one-cell border is its only separation from editable text. Prompt state is discarded when the window closes.

Invocation already captures the target window. Cursor-relative placement also needs the source cursor's screen position before focus moves into the prompt. History can remain module-local because AI edit is configured once per Neovim process and the requested behavior does not require durable storage.

## Goals / Non-Goals

**Goals:**

- Keep the prompt visually connected to the invocation point without covering the source cursor.
- Make the default prompt smaller while preserving configurable fractional dimensions and small-screen clamping.
- Give editable text a visible inset from the rounded frame.
- Recall accepted single-line or multiline instructions across AI edit invocations during the current Neovim session.
- Preserve existing submit, newline, cancel, target validation, and asynchronous job behavior.

**Non-Goals:**

- Persistent, searchable, editable, project-specific, or model-specific history.
- History management commands or a new setup option for the fixed history bound.
- Following a source cursor after the prompt opens.
- Changing the running activity float, error float, OpenCode request, or staging lifecycle.

## Decisions

### Capture screen position and choose a vertical side

Capture the invocation cursor and convert it to editor screen coordinates before opening any float. Center the frame horizontally on that column, then clamp it inside usable editor bounds.

Use the cursor's screen half as the primary vertical rule: upper half places the frame below, lower half places it above. Keep one clear screen row between the source cursor and frame. If the preferred side cannot hold the frame, use the opposite side when it fits; otherwise use the side with more room and shrink the frame. The normal 20-column by 3-row frame-content minimum applies when it fits; constrained geometry can reduce frame content to a hard 3-by-3 minimum, leaving a 1-by-1 inner input after padding. If Neovim cannot resolve a usable source screen position, report the geometry error instead of reverting to detached centered placement. When neither side can contain the hard-minimum shell plus source gap, report the geometry error rather than covering the cursor or calling `nvim_open_win` with invalid dimensions.

This uses captured editor coordinates rather than `relative = 'cursor'`, whose reference changes when focus enters the prompt. Position remains stable for the prompt lifetime.

### Use a frame float around an inset input float

Create a non-focusable outer scratch float for the rounded border and title. Open the editable prompt buffer in a borderless inner float one row and one column inside that frame, with the corresponding width and height reduction. Give the input float a higher `zindex`, transfer focus directly to it, and close both windows through one idempotent cleanup function.

A second float keeps actual buffer text free of synthetic leading spaces and blank lines. Prefixing prompt lines was rejected because users could delete the padding and submission would need to distinguish layout bytes from instruction bytes.

The configured `width` and `height` continue to describe the frame's editor-relative content dimensions. Defaults become `0.5` and `0.2`. Calculate the normal 20-by-3 minimum first, then clamp against actual editor and side capacity down to the hard 3-by-3 frame-content minimum so the inner input always remains positive.

### Keep bounded process-local instruction history

Maintain one module-level list with a fixed 100-entry limit. Add an instruction only after non-empty submission passes the target snapshot checks and is accepted as a job. Cancellation, whitespace rejection, and stale prompt rejection do not add entries. On overflow, discard the oldest entry. Store only exact instruction text, including embedded newlines; do not write history to ShaDa or another file.

Each prompt captures an immutable copy of current history plus its exact draft when navigation starts. It then owns an index into that snapshot, so another concurrently open prompt can append or evict global entries without shifting the active sequence. `<C-p>` moves toward older snapshot entries and `<C-n>` moves toward newer entries unconditionally. `<Up>` performs older navigation only from the first input line, and `<Down>` performs newer navigation only from the last input line; elsewhere they retain native multiline cursor movement. Moving newer past the snapshot's most recent entry restores the captured draft and exits history navigation; later older navigation starts a fresh snapshot that includes newer global submissions. Replacing input from history preserves multiline text and puts the input cursor at its end. Opening another prompt starts with a blank draft while sharing accumulated session history.

Keeping `<C-p>` and `<C-n>` as unconditional controls makes history navigation available from any input line. Boundary-aware arrows provide familiar prompt behavior without sacrificing vertical movement inside multiline instructions.

## Risks / Trade-offs

- [Layered floats can diverge during cleanup] -> Route submit, Escape, and buffer/window teardown through one function that validates and closes both owned windows.
- [Small screens cannot preserve preferred dimensions and spacing] -> Clamp the normal frame down to a documented 3-by-3 frame-content minimum and reject when neither cursor side can fit that shell plus the source gap.
- [Concurrent prompts mutate shared history during navigation] -> Browse an immutable per-navigation snapshot and refresh it only after returning to the draft.
- [Screen rows include tablines, statuslines, and command area] -> Base calculations on resolved screen coordinates and tested usable editor bounds rather than target buffer line numbers.
- [History retains sensitive prompts in memory] -> Bound it to 100 entries, keep it process-local, and never persist it.
- [History mappings replace insert completion mappings inside the prompt] -> Scope mappings to the prompt buffer and intercept arrows only at first/last-line history boundaries; other multiline movement and all other buffers remain unaffected.

## Migration Plan

1. Refactor prompt geometry and lifecycle around the frame and input windows.
2. Add module-local history and prompt-local navigation state.
3. Update default dimensions and automated prompt tests.

Rollback restores the single centered float and removes module-local history. No stored data requires migration or cleanup.

## Open Questions

None.
