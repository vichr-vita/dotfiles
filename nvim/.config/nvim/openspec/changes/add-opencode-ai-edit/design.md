## Context

This Neovim config has no reusable asynchronous job or floating-input abstraction. It targets modern Neovim APIs, uses `lazy.nvim`, and already maps local behavior with `vim.keymap.set`. OpenCode 1.18.21 supports noninteractive `opencode run`, named primary agents, newline-delimited JSON output, and config injection through `OPENCODE_CONFIG_CONTENT`.

Directly letting OpenCode edit the real file conflicts with the required undo behavior. Neovim may retain stale buffer text, reload an external write outside the desired undo history, or overwrite the agent result. The edit therefore needs an isolated staging target followed by one Neovim buffer API mutation.

## Goals / Non-Goals

**Goals:**

- Make small whole-buffer and visual-selection edits without leaving Neovim.
- Preserve unsaved buffer content as agent input.
- Guarantee that a successful result is one unsaved, undoable buffer change.
- Enforce one-file or one-selection mutation through a host-bound staging tool.
- Keep Neovim responsive and protect edits made while a request runs.
- Reuse trusted global OpenCode model/provider configuration and real OAuth while retaining project source context.

**Non-Goals:**

- Multi-file edits, blockwise visual edits, chat sessions, prompt history, diff approval UI, automatic save, or automatic formatting.
- Publishing a reusable Neovim plugin or supporting older Neovim versions.
- Merging a result into a buffer that changed after submission.
- Giving the agent shell, web, task, question, skill, or unrestricted write access.
- Treating project reads as an operating-system sandbox; v1 runs only in trusted worktrees because OpenCode follows symlinks after lexical path checks.

## Decisions

### Keep the feature local with one audited OpenCode helper

Add `lua/vichr/ai_edit.lua` with `setup`, prompt, staging, process, and apply behavior. Place trusted OpenCode config and `stage_text` TypeScript source beside the module. Load the Lua module from the existing Neovim configuration. A small setup table accepts `keymap`, `command`, `timeout_ms`, `max_bytes`, `width`, and `height` while retaining the agreed defaults.

This avoids a new Neovim plugin dependency and public API. At first use, build the helper in a unique private directory keyed by cache format, OpenCode version, helper-source hash, and executable. Let OpenCode install its exact `@opencode-ai/plugin` package there, verify trusted source and installed package versions, recursively remove write permission, and atomically rename the complete directory into its content-addressed destination. Concurrent first uses build independently and accept only the verified atomic winner; later uses never rewrite or bootstrap through the published cache. Never point OpenCode at checked-in source. Bootstrap or offline dependency failures abort the edit with an actionable error.

### Snapshot in-memory text into a private staging directory

At submission, capture buffer identity, absolute path, changed tick, mode, range, and current text. Use a unique directory under `stdpath('cache')` or the system temporary directory.

Normal mode writes the whole buffer to the mutable staging target. Visual mode writes selected text to the mutable target and the full buffer to a second context file. Preserve the original extension on staging filenames so OpenCode sees useful language metadata. Keep the buffer's `endofline` state unchanged when applying a whole-buffer result.

The agent reads and updates staging through the trusted helper rather than the real file. Direct disk editing was rejected because it cannot guarantee one-step undo or safe handling of unsaved input.

### Generate a restricted primary agent per run

Construct `OPENCODE_CONFIG_CONTENT` with an unpredictable per-run agent name. Set `mode` to `primary`, `disable` to `false`, omit `model` to inherit the resolved global OpenCode model, and provide a focused prompt that names the authoritative staging target, original file path, project root, and strict scope.

Use the published helper payload as both `OPENCODE_CONFIG_DIR` and the isolated XDG global config directory, and set `OPENCODE_TEST_HOME` to a private empty home. This removes real global and legacy `~/.opencode` custom-tool directories from OpenCode's registry search while retaining the explicit trusted tool. Keep injected `plugin` configuration empty, set `OPENCODE_PURE=1`, and set `OPENCODE_DISABLE_PROJECT_CONFIG=1`. Leave `OPENCODE_DISABLE_DEFAULT_PLUGINS` unset so OpenCode 1.18.21 can load its complete bundled provider/auth plugin set, including OpenAI Codex OAuth. Treat that inseparable set as trusted host code pinned by exact executable version. Use a tool allowlist with `read`, `glob`, `grep`, and `stage_text`. Disable stock `apply_patch`, `edit`, and `write` tools. Reject every resolved MCP entry, including entries marked disabled, because this host does not independently prove their registry behavior inert. Apply top-level deny rules so an unexpected agent fallback also lacks mutation, shell, and external tool access.

`stage_text` receives no model-controlled path. The Lua host passes staging root, staging target, and size limit through the child environment. It supports two actions:

- `read` accepts only a `target` or `context` source enum, never a path. It returns a single-line serialized envelope containing a UTF-8 page, content revision hash, byte range, next cursor, and EOF state. Configure and preflight `tool_output.max_bytes` at 32 KiB and `max_lines` at 10. Measure the complete serialized envelope and cap it below 16 KiB before recording coverage, leaving room for OpenCode wrappers. Normal mode binds only the target; visual mode also binds the separate full-buffer snapshot as read-only context. This is the authoritative path for complete unsaved content because OpenCode 1.18.21 truncates normal file attachments after 50 KiB or 2,000 lines.
- `submit` always targets the mutable target and requires its current revision plus either exact old-text/new-text operations or a complete replacement. Exact operations default to one expected match, resolve against the same original revision, reject missing or unexpected counts and overlaps, and apply from highest byte position downward. Complete replacement is allowed immediately for a single-page target. For a multi-page target, the tool records sequential target-page coverage in process memory and requires the same revision to reach EOF first. Exact operations preserve unread content and do not require full coverage.

Before either action, the tool resolves configured sources under the private root and rejects symlinks, non-regular files, invalid UTF-8, stale cursors, and oversized content. Cursor chains are source- and revision-bound. A submit builds its complete result in memory, writes a random same-directory temporary regular file, syncs it, rechecks target identity, and atomically renames it over the target. Empty replacement content is valid. The host accepts only a completed `stage_text` submit event, never assistant prose.

This custom tool is required because OpenCode 1.18.21 exposes `apply_patch` to GPT models and checks move permissions only on the source path. A permitted staging file could otherwise be moved onto a project file. Built-in model-selected mutation tools were therefore rejected.

Run from the nearest Git root found from the file path, with the file directory as fallback. `OPENCODE_DISABLE_PROJECT_CONFIG=1` prevents project config, `.opencode` plugins, custom tools, agents, commands, skills, modes, and automatic project instruction discovery from executing. The agent prompt directs `read`, `glob`, and `grep` to inspect relevant project instruction files as plain text when present. Before any registry-loading command, run only `debug config` against real global config with project config and external plugins disabled. OpenCode 1.18.21 does not initialize its tool registry or MCP service for this command. Validate resolved safety fields and require empty MCP configuration, copy only model, small-model, provider, and provider enable/disable settings into runtime config, then isolate all subsequent bootstrap, config, agent, and run commands from real global and project custom-tool directories. Keep XDG data unchanged so bundled provider/auth plugins retain OAuth credentials.

Request `share: disabled`, `snapshot: false`, `formatter: false`, `lsp: false`, an empty configured plugin list, empty MCP configuration, and fixed 32 KiB/10-line tool-output limits; unset automatic sharing; disable project and external plugin sources through environment flags. Managed or organization config loads after runtime config and can override fields, so run installed-CLI preflights with the exact isolated child environment before session creation. First require executable version `1.18.21`, which defines the trusted bundled provider/auth code set. Then parse isolated resolved config and agent JSON and require all safety fields, empty configured plugins and MCP configuration, exact tool-output limits, and an enabled-tool set of exactly `read`, `glob`, `grep`, and `stage_text`. An enabled local MCP process can start when OpenCode initializes its registry, outside the ordinary tool allowlist, so unsafe MCP configuration aborts after `debug config` and before helper bootstrap, agent inspection, or a model session. This preflight has a small process-to-process race if an administrator changes managed config between commands; managed host configuration is part of the trusted environment.

OpenCode 1.18.21 exposes `OPENCODE_DISABLE_DEFAULT_PLUGINS` only as an all-or-none switch. Disabling defaults breaks required OpenAI Codex OAuth; enabling them also loads other bundled provider integrations. Selective built-in control is impossible, so the policy trusts the complete bundled set as inseparable provider/auth host code and pins that trust to executable version `1.18.21`. This allowance does not extend to configured plugins: injected plugin configuration stays empty, `OPENCODE_PURE=1` disables external user-installed plugins, and project configuration remains disabled.

Disabling formatter and LSP prevents model edits from spawning project commands outside agent permissions. Project source reads remain limited by OpenCode's lexical path checks, not an OS sandbox. An in-project symlink can resolve outside the worktree, so v1 supports only trusted worktrees.

A static global agent file was rejected because it cannot bind edit permission to a different staging path each run.

### Use `vim.system` and track jobs by buffer

After successful bootstrap and config preflight, launch `opencode run --agent <unique-name> --format json` through argv, not shell interpolation. Pass the instruction through stdin so text beginning with `-` cannot become a CLI option. Do not rely on `--file` for authoritative content; the prompt directs the agent to use `stage_text` pages and identifies the original path only for project context. Pass injected config, trusted cache directory, target paths, and safety flags in the child environment. Stream stdout to capture JSON events, tool states, and the session ID; capture stderr for errors. Track process handle, timer/state, staging paths, session ID, and captured snapshot in a table keyed by buffer number.

One active job per buffer avoids overlapping stale snapshots while allowing independent files to run concurrently. `:AIEditCancel` terminates the current buffer's process. The five-minute default timeout uses the same terminal cleanup path. Process callbacks schedule Neovim API work onto the main loop and guard against duplicate completion after cancellation or timeout.

After any terminal outcome with an observed session ID, launch `opencode session delete <session-id>` asynchronously with project config disabled and a bounded cleanup timeout. Buffer result handling, staging removal, notifications, and editor event-loop progress never wait for deletion. Terminate timed-out cleanup and warn on timeout, launch failure, or nonzero exit. Session deletion remains best-effort because a process can die before emitting its ID and OpenCode can swallow storage deletion failures. Provider-side retention, OpenCode logs, and caches remain outside plugin control.

### Validate completion before one buffer mutation

Require zero exit, no top-level error event, no `tool_use` event whose nested state is `error`, and exactly one successful `stage_text` submit action. Read actions may occur any number of times. Also require the target path to remain a regular non-symlink file under its private root. Any failure rejects the entire staged result. A byte-identical staging target is a successful no-op. Empty output remains a valid edit because `stage_text` preserves the target as an empty regular file.

Before application, verify that the buffer still exists, remains loaded and writable, still refers to the captured file, and has the captured changed tick. Reject rather than merge stale results.

Use Neovim's authoritative region APIs to capture characterwise selections with the active inclusive or exclusive semantics in either direction. Derive byte-exact replacement coordinates from returned UTF-8 text and region positions so no outside byte is included and no codepoint is split. Use one `nvim_buf_set_lines` call for a whole buffer or one `nvim_buf_set_text` call for a characterwise/linewise range. Neovim then records one undo entry. Do not call `:write`, formatting, or additional text mutations.

### Use a scratch-buffer prompt and error float

Create a centered rounded float sized from configurable editor-relative fractions, clamped to usable dimensions. Its title contains the project-relative file path and visual range when present. The prompt buffer maps Enter to submit, `<C-j>` to newline, and Escape to cancel. Empty instructions stay open with a warning.

Close the prompt after valid submission. Use notifications for running, cancellation, timeout, no-op, stale result, and successful apply. Show captured OpenCode error details in a separate readonly scratch float.

## Risks / Trade-offs

- [Project OpenCode extensions execute outside agent permissions] -> Disable project config loading and read relevant instruction files only as text.
- [Bundled provider/auth code executes outside agent permissions] -> Trust only the complete inseparable set shipped inside exact OpenCode 1.18.21; reject another executable version and keep configured, project, and external user-installed plugins disabled.
- [Project symlinks escape lexical read checks] -> Limit v1 to trusted worktrees and state that project reads are not an OS sandbox.
- [Stock `apply_patch` can move an allowed source onto another destination] -> Disable all stock mutation tools and expose only `stage_text`, which accepts text operations but no path.
- [Normal OpenCode attachments truncate large files] -> Read authoritative staging text through bounded revision-bound `stage_text` pages and prefer exact replacements that preserve unread content.
- [OpenCode truncates custom-tool pages after execution] -> Preflight fixed output limits and advance coverage only for serialized envelopes measured well below them.
- [Custom tool path is replaced or redirected] -> Use a private directory, realpath containment, regular-file and symlink checks, target identity verification, and same-directory atomic replacement.
- [Formatter or LSP starts project executables] -> Force both subsystems off for the headless run.
- [Managed configuration overrides runtime safety] -> Preflight final resolved config and agent tools before session creation; trust host administration against the remaining process race.
- [MCP tools and local processes bypass the ordinary tool allowlist] -> Reject every resolved MCP entry during the non-registry config preflight, before helper bootstrap or agent/session commands.
- [OpenCode mutates custom config directories] -> Bootstrap in a unique directory, verify and seal it, atomically publish one immutable winner, and never expose checked-in or shared mutable helper files.
- [OpenCode CLI contract changes] -> Validate executable availability, invoke only documented flags, parse JSON error events defensively, and report incompatible output.
- [Large prompts cost time and model context] -> Reject input above a configurable 1 MiB default before process launch.
- [Agent changes staging and later reports failure] -> Apply only after zero exit, exactly one successful `stage_text` submit, and no failed tool state.
- [Whole replacement omits unread tail content] -> Require sequential same-revision target coverage through EOF before multi-page complete replacement; exact edits preserve unread bytes.
- [Visual selection loses unsaved surrounding context] -> Bind the full-buffer snapshot as a separate paginated read-only source while submit remains hardwired to the selection target.
- [User edits while process runs] -> Compare `changedtick` and discard stale results without merge.
- [Termination callback races normal completion] -> Use one idempotent finalizer per job and clear the buffer job slot once.
- [Session deletion stalls Neovim or terminal cleanup] -> Run deletion asynchronously under its own bounded timer; warn and terminate on timeout without changing buffer or staging outcomes.
- [Temporary content contains private code] -> Use a private per-run directory, pass paths as argv/config data, and remove it on every terminal path.
- [OpenCode persists or shares headless sessions] -> Force sharing and snapshots off, capture session IDs, and attempt session deletion after every outcome.
- [A selected fragment lacks enough syntax context] -> Give the agent a full read-only in-memory snapshot and project search access while keeping mutation scoped to the fragment.

## Migration Plan

1. Add the local module and setup call with the default mapping.
2. Add focused automated tests for paginated reads, exact staging edits, inclusive/exclusive forward/reverse UTF-8 visual ranges, delayed and stuck cleanup, plus a fake OpenCode executable for preflight, completion, stale-result, cancellation, and undo behavior.
3. Run Stylua, headless Neovim tests, installed-OpenCode 1.18.21 hostile preflight/tool checks, and a real OpenAI OAuth smoke through the trusted bundled plugin set when credentials and network access are available.

Rollback removes the setup call and local module. No application data migration exists. OpenCode logs, caches, provider retention, or a session created before its ID was emitted may outlive local staging cleanup.

## Open Questions

None.
