## 1. Cursor-relative prompt layout

- [x] 1.1 Capture and validate the invocation cursor's editor screen position and add geometry calculation for 50-by-20-percent defaults, horizontal cursor centering, upper/lower-half placement, one-row source gap, opposite-side fallback, clamping from the normal 20-by-3 frame minimum to a hard 3-by-3 minimum, and graceful rejection for unresolved coordinates or when neither cursor side can fit that shell.
- [x] 1.2 Replace the single prompt float with an owned frame and focused inner input float that provide one-row/one-column text inset while preserving the title, prompt-local options, and insert-mode startup.
- [x] 1.3 Unify frame and input teardown so submit, Escape, validation failure, and externally closed windows cannot leak either float, while preserving Enter and `<C-j>` behavior.

## 2. Instruction history

- [x] 2.1 Add exact module-local instruction history with a fixed 100-entry bound, recording only non-empty submissions accepted after target snapshot validation and dropping oldest entries on overflow.
- [x] 2.2 Add prompt-local history navigation over immutable per-navigation snapshots using unconditional `<C-p>`/`<C-n>` plus `<Up>` on the first line and `<Down>` on the last line, while preserving native arrows inside multiline input, exact recalled text, end-cursor placement, draft restoration, and snapshot refresh.

## 3. Automated coverage

- [x] 3.1 Add headless prompt tests for new default and overridden dimensions, upper/lower placement, source gap, horizontal centering, opposite-side fallback, 18-to-22-column clamping, centered-cursor no-side-fit rejection in 7-to-9 usable rows, unresolved-coordinate rejection, text inset, focus, and complete float cleanup.
- [x] 3.2 Add headless history tests for cross-buffer ordering, `<C-p>`/`<C-n>` navigation, first-line `<Up>` and last-line `<Down>` navigation, native arrows within multiline input, exact multiline recall, older/newer bounds, draft restoration and refresh, 100-entry eviction, concurrent mutation during navigation, and exclusion of cancelled, whitespace-only, and stale-target input.

## 4. Verification

- [x] 4.1 Run Stylua, AI edit headless and TUI tests, and a clean Neovim startup smoke test; fix regressions.
