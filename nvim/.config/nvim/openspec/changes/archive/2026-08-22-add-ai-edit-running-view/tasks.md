## 1. Target lock lifecycle

- [x] 1.1 Capture target window and owned buffer state when a validated prompt starts a job, then use an autocmd-suppressed buffer-local transition to lock only the target and revalidate option, identity, text, and revision before staging and preflight work.
- [x] 1.2 Refactor result application and terminal finalization so validation happens while locked, successful application performs an autocmd-suppressed unlock followed by a second identity/text/revision check and one protected mutation, and every other outcome idempotently releases the lock without option callbacks.
- [x] 1.3 Preserve stale-result rejection for forced unlocks, external mutations, renamed targets, unloaded buffers, and deleted buffers without stranding buffer options.

## 2. Caret and activity UI

- [x] 2.1 Add the blend-100 hidden-cursor highlight plus one exact guarded `guicursor` override that suppresses only editing modes while a locked target is current, preserves command-line modes, follows current-buffer changes and concurrent jobs, normalizes external replacement/append/prepend/removal updates by stripping owned segments, and restores the latest clean base value.
- [x] 2.2 Add a per-job readonly scratch transcript with control-character sanitization, UTF-8-safe per-entry truncation, fixed aggregate byte/line bounds, oldest-entry removal, truncation markers, and newest-line scrolling.
- [x] 2.3 Add a non-focusable, mouse-transparent rounded float that stays inside the right edge of a visible target window, follows target visibility, clamps on resize, supports concurrent jobs, and never changes focus.
- [x] 2.4 Emit transcript phases throughout version, global config, helper, runtime config, agent, and model-run setup so feedback starts before session events.
- [x] 2.5 Present completed assistant text and allowlisted tool summaries from OpenCode JSON events while excluding reasoning, raw tool output, replacement content, session data, staging paths, and unknown payloads.
- [x] 2.6 Integrate activity and caret teardown into all terminal paths while preserving current statusline, notification, cancellation, error-float, staging, and session-cleanup behavior.

## 3. Automated coverage

- [x] 3.1 Extend fake OpenCode scenarios with completed text, safe and sensitive tool payloads, reasoning, long activity, delayed phases, and duplicate event updates needed by presentation tests.
- [x] 3.2 Add headless tests proving immediate lock, blocked ordinary edits, unrelated-buffer editing, independent concurrent jobs, successful one-step undo, forced stale mutation, hostile `OptionSet modifiable` handlers during acquisition/application/restoration, and option restoration after every terminal outcome.
- [x] 3.3 Add headless tests for guarded `guicursor` ownership across target/unrelated-buffer navigation, command-line mode coverage, external replace/append/prepend/remove updates without leaked owned segments, target redisplay, direct switches between concurrent jobs, and every final cleanup path.
- [x] 3.4 Add headless tests for float placement, focus preservation, host phases, assistant text, safe tool summaries, sensitive-field exclusion, single-event and aggregate byte/line bounds with multibyte text, auto-scroll, target hide/show, resize, concurrent views, and terminal teardown.
- [x] 3.5 Add a pseudo-terminal TUI test using default `guicursor` that verifies actual caret hiding on a locked target and visibility in unrelated buffers, command-line modes, and terminal cleanup.

## 4. Verification

- [x] 4.1 Run Stylua and the AI-edit TypeScript and headless Neovim suites, then fix all regressions.
- [x] 4.2 Run a clean Neovim startup smoke test and installed OpenCode 1.18.21 whole-buffer and visual-selection smoke edits, confirming visible activity, blocked target edits, result application, undo, cancellation, and cleanup.
