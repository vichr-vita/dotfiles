# opencode-buffer-editing Specification

## Purpose
TBD - created by syncing change add-opencode-ai-edit.

## Requirements

### Requirement: Eligible file buffer invocation
The system SHALL expose the AI edit action in normal and visual modes, SHALL accept only named, writable, non-binary file buffers whose in-memory content does not exceed the configured size limit, and SHALL open the prompt only when usable editor geometry can contain the minimum prompt shell on at least one side of the resolved source cursor.

#### Scenario: Invoke from a normal file buffer
- **WHEN** the user invokes `<leader>ai` from an eligible normal-mode buffer with usable prompt geometry
- **THEN** the system opens an edit prompt targeting the whole in-memory buffer

#### Scenario: Invoke from an unsupported buffer
- **WHEN** the user invokes the action from an unnamed, non-file, readonly, binary, or oversized buffer
- **THEN** the system reports the validation error and does not open a prompt or start OpenCode

#### Scenario: Invoke without usable prompt geometry
- **WHEN** the target buffer is eligible but neither side of the resolved source cursor can contain the minimum prompt shell and source gap
- **THEN** the system reports that the prompt cannot fit and does not open a prompt or start OpenCode

#### Scenario: Invoke without resolved source coordinates
- **WHEN** the target buffer is eligible but Neovim cannot resolve the invocation cursor to usable editor screen coordinates
- **THEN** the system reports that cursor-relative placement is unavailable and does not open a prompt or start OpenCode

### Requirement: Strict visual selection scope
The system SHALL support characterwise and linewise visual selections, match Neovim's active inclusive or exclusive selection semantics exactly in either direction without splitting UTF-8 codepoints, provide the full in-memory buffer as read-only context, and permit the result to replace only the selected text.

#### Scenario: Characterwise selection
- **WHEN** the user invokes the action with a characterwise selection
- **THEN** the submitted edit targets exactly the selected byte range, including partial first and last lines

#### Scenario: Characterwise selection semantics
- **WHEN** an ASCII or multibyte characterwise selection is forward or reverse, single-line or multiline, under inclusive or exclusive `selection`
- **THEN** capture and replacement match Neovim's authoritative region exactly, include no outside bytes, and start and end only at UTF-8 codepoint boundaries

#### Scenario: Linewise selection
- **WHEN** the user invokes the action with a linewise selection
- **THEN** the submitted edit targets the complete selected lines

#### Scenario: Blockwise selection
- **WHEN** the user invokes the action with a blockwise selection
- **THEN** the system reports that blockwise edits are unsupported and does not open a prompt or start OpenCode

### Requirement: Floating instruction prompt
The system SHALL open an inset scratch-buffer prompt near the captured invocation cursor with the target file and optional selection range in its title. It SHALL center the frame horizontally on the cursor when space permits, place it below a cursor in the upper half of the editor and above a cursor in the lower half, separate the frame from the source cursor by one screen row when space permits, and clamp or shrink it within usable editor bounds.

#### Scenario: Open prompt from upper editor half
- **WHEN** the user invokes AI edit with the source cursor in the upper half of an editor that has sufficient space
- **THEN** the prompt opens below the cursor with one clear screen row between the cursor and frame

#### Scenario: Open prompt from lower editor half
- **WHEN** the user invokes AI edit with the source cursor in the lower half of an editor that has sufficient space
- **THEN** the prompt opens above the cursor with one clear screen row between the cursor and frame

#### Scenario: Center prompt on cursor column
- **WHEN** horizontal space permits the configured prompt width
- **THEN** the prompt frame is horizontally centered on the captured source cursor column

#### Scenario: Constrained editor geometry
- **WHEN** the preferred side or configured dimensions do not fit within usable editor bounds
- **THEN** the system uses fitting opposite-side or clamped geometry without opening outside the editor, reducing the normal frame minimum as far as a 3-by-3 frame-content area while keeping at least a 1-by-1 input area

#### Scenario: Cursor has no side for minimum prompt shell
- **WHEN** neither side of the resolved source cursor can contain the rounded border, one-cell inset, 1-by-1 input area, and source gap
- **THEN** the system reports that the prompt cannot fit without covering the cursor and does not request invalid floating-window geometry

#### Scenario: Prompt text inset
- **WHEN** the prompt opens
- **THEN** editable text starts at least one row and one column inside the rounded frame rather than against its border

#### Scenario: Submit instruction
- **WHEN** the prompt is open and the user presses Enter with a non-empty instruction
- **THEN** the system closes the prompt and starts the edit asynchronously

#### Scenario: Insert prompt newline
- **WHEN** the prompt is open and the user presses `<C-j>`
- **THEN** the system inserts a newline without submitting

#### Scenario: Cancel prompt
- **WHEN** the prompt is open and the user presses Escape
- **THEN** the system closes the prompt without starting OpenCode

#### Scenario: Reject empty instruction
- **WHEN** the user submits an instruction containing only whitespace
- **THEN** the system keeps the prompt open and reports that an instruction is required

### Requirement: Session-local instruction history
The system SHALL retain at most 100 AI edit instructions accepted during the current Neovim process, preserve each instruction's exact multiline text, expose unconditional older and newer navigation through `<C-p>` and `<C-n>`, expose boundary-aware navigation through `<Up>` and `<Down>`, and SHALL NOT persist the history to disk.

#### Scenario: Accepted instruction enters history
- **WHEN** a non-empty instruction passes target snapshot validation and is accepted as an asynchronous AI edit job
- **THEN** the system appends its exact text as the newest session history entry

#### Scenario: Recall older instruction
- **WHEN** the prompt is open with available history and the user presses `<C-p>`
- **THEN** the system replaces the prompt with the next older exact instruction and places the input cursor at its end

#### Scenario: Recall newer instruction
- **WHEN** the user has recalled an older instruction and presses `<C-n>` while a newer entry exists in the active navigation snapshot
- **THEN** the system replaces the prompt with the next newer exact instruction and places the input cursor at its end

#### Scenario: Recall older instruction with Up
- **WHEN** history is available and the user presses `<Up>` from the first input line
- **THEN** the system replaces the prompt with the next older exact instruction and places the input cursor at its end

#### Scenario: Recall newer instruction with Down
- **WHEN** the user is navigating history and presses `<Down>` from the last input line
- **THEN** the system recalls the next newer snapshot entry or restores the captured draft after the newest entry

#### Scenario: Move within multiline input with arrows
- **WHEN** the prompt contains multiple lines and the user presses `<Up>` below the first line or `<Down>` above the last line
- **THEN** the system performs native vertical cursor movement without starting or advancing history navigation

#### Scenario: Restore current draft
- **WHEN** history navigation began from a current draft and the user moves newer past the active snapshot's newest history entry with `<C-n>` or boundary-aware `<Down>`
- **THEN** the system restores that exact draft and exits history navigation

#### Scenario: Preserve multiline history
- **WHEN** an accepted instruction contains multiple lines and the user recalls it
- **THEN** every line and newline is restored without flattening or truncation

#### Scenario: Exclude unaccepted input
- **WHEN** the user cancels a prompt, submits only whitespace, or submission fails target snapshot validation
- **THEN** the system does not add that input to history

#### Scenario: History reaches its limit
- **WHEN** accepting an instruction would add a 101st history entry
- **THEN** the system discards the oldest entry and retains the newest 100 entries in order

#### Scenario: Start another Neovim process
- **WHEN** AI edit is initialized in a new Neovim process
- **THEN** instruction history starts empty regardless of prompts submitted by prior processes

#### Scenario: Another prompt changes history during navigation
- **WHEN** one prompt is navigating history while another prompt accepts an instruction or evicts the oldest entry
- **THEN** the first prompt continues through its immutable navigation snapshot without skipping or repeating entries and can start a fresh snapshot after returning to its draft

### Requirement: Isolated custom OpenCode agent
The system SHALL run `opencode run` with a unique runtime-generated primary agent against isolated staging content. The run SHALL inherit global OpenCode model/provider settings and the complete inseparable provider/auth plugin bundle shipped as trusted host code inside stable OpenCode versions `>=1.18.21 <2.0.0`, including real OpenAI OAuth, and SHALL install the exact matching `@opencode-ai/plugin` version in its isolated helper cache. It SHALL disable executable project OpenCode configuration and extensions, configured and external user-installed plugins, all MCP servers, host-side formatter and LSP servers, and expose only project reads and searches plus an audited staging submission tool.

#### Scenario: Trusted bundled provider and auth plugins
- **WHEN** a supported OpenCode version starts an edit and selective built-in plugin control is unavailable
- **THEN** the system leaves the bundled provider/auth set enabled as inseparable trusted host code, preserves provider OAuth, and does not extend that trust to configured, project, or external user-installed plugins

#### Scenario: Installed executable has a higher patch or minor version
- **WHEN** the configured executable reports a stable semantic version at least 1.18.21 and below 2.0.0
- **THEN** the system accepts the executable and uses that exact version for the isolated helper dependency

#### Scenario: Installed executable falls outside the supported range
- **WHEN** the configured executable reports a lower version, version 2.0.0 or newer, a prerelease, or malformed output
- **THEN** the system reports the supported range and does not create an OpenCode editing session

#### Scenario: Whole-buffer run
- **WHEN** a normal-mode instruction is submitted
- **THEN** the staging target contains the complete current in-memory buffer and OpenCode runs from the nearest containing Git root, or the file directory when no Git root exists

#### Scenario: Selection run
- **WHEN** a visual-mode instruction is submitted
- **THEN** the staging target contains only the selected text and a separate read-only staging file contains the full current buffer for context

#### Scenario: Agent attempts another write
- **WHEN** the agent attempts to modify the real file, another project file, or the read-only context snapshot
- **THEN** no exposed tool can perform that mutation

#### Scenario: Context discovery
- **WHEN** the agent needs surrounding project context
- **THEN** it can use read, glob, and grep in the trusted target project, including instruction files as text, but cannot load project plugins or custom tools or use bash, web access, tasks, questions, skills, or unrestricted mutation tools

#### Scenario: Project defines executable OpenCode extensions
- **WHEN** the target project contains OpenCode config, plugins, tools, agents, commands, skills, or modes
- **THEN** the headless run does not load or execute them

#### Scenario: Read authoritative staging content
- **WHEN** the agent needs in-memory target text beyond one bounded response
- **THEN** the audited staging tool returns revision-bound UTF-8 pages whose complete serialized envelope stays below preflighted OpenCode output limits until the agent reaches end of file, without exposing a filesystem path argument

#### Scenario: Read visual buffer context
- **WHEN** a visual edit needs surrounding unsaved buffer context
- **THEN** the audited staging tool can page through a separate host-selected read-only context source and cannot submit changes to it

#### Scenario: Submit staged replacement
- **WHEN** the agent finishes an edit with any inherited model
- **THEN** it calls the audited staging tool with the current revision and either exact old-text/new-text operations or a complete replacement, without choosing a destination path

#### Scenario: Replace complete multi-page target
- **WHEN** the agent submits a complete replacement for a target larger than one tool page
- **THEN** the audited staging tool accepts it only after that run has read the same target revision sequentially through end of file

#### Scenario: Submit exact edits
- **WHEN** submitted exact text has a missing, ambiguous, unexpected-count, or overlapping match against the submitted revision
- **THEN** the audited staging tool rejects the entire submission without changing staging content

#### Scenario: Submit against stale revision
- **WHEN** staging content changed after the revision supplied by the agent
- **THEN** the audited staging tool rejects the entire submission without changing staging content

#### Scenario: Stock mutation requested
- **WHEN** the agent attempts to use `apply_patch`, `edit`, `write`, bash, a formatter, or an LSP server
- **THEN** the run denies or omits that capability

#### Scenario: Staging path is unsafe
- **WHEN** the host-selected target is missing, a symlink, not a regular file, changes identity while opening, or resolves outside its private staging directory
- **THEN** the audited staging tool fails without writing content

#### Scenario: Project or global config enables sharing
- **WHEN** inherited configuration requests automatic session sharing
- **THEN** the resolved-config preflight verifies sharing remains disabled and new filesystem snapshots, formatters, and LSP servers remain off before session creation

#### Scenario: Managed configuration overrides safety
- **WHEN** final merged OpenCode configuration re-enables sharing, snapshots, formatters, LSP servers, any MCP server, any configured, external, or project plugin, stock mutation tools, another agent tool, or incompatible tool-output limits
- **THEN** the system reports an unsafe configuration before registry loading and does not start an MCP process or create an OpenCode editing session

### Requirement: Asynchronous per-buffer execution
The system SHALL keep Neovim usable while OpenCode runs and SHALL allow at most one active edit per target buffer.

#### Scenario: Edit another buffer concurrently
- **WHEN** one buffer has an active edit and the user starts an edit in another eligible buffer
- **THEN** both jobs may run concurrently

#### Scenario: Start a second edit for the same buffer
- **WHEN** the target buffer already has an active edit
- **THEN** the system rejects the new request and leaves the active job running

#### Scenario: Cancel active edit
- **WHEN** the user runs `:AIEditCancel` in a buffer with an active edit
- **THEN** the system terminates that buffer's OpenCode process, removes staging data, and leaves the buffer unchanged

#### Scenario: Edit reaches timeout
- **WHEN** a run exceeds the configured timeout
- **THEN** the system terminates it, removes staging data, reports the timeout, and leaves the buffer unchanged

### Requirement: Safe result application
The system SHALL apply a staged result only after OpenCode exits successfully, exactly one staging-tool submit action succeeds, no tool call fails, the staging target remains a regular file, and the target buffer remains valid with the changed tick captured at submission.

#### Scenario: Apply whole-buffer result
- **WHEN** OpenCode exits successfully, changes the staging target, and the original buffer is unchanged
- **THEN** the system replaces the buffer content in one undoable operation and leaves the buffer modified but unsaved

#### Scenario: Apply selection result
- **WHEN** OpenCode exits successfully, changes a selection staging target, and the original buffer is unchanged
- **THEN** the system replaces only the captured selection in one undoable operation and leaves all other buffer text untouched

#### Scenario: Undo applied result
- **WHEN** the user presses `u` immediately after a successful result is applied
- **THEN** Neovim restores the exact pre-edit buffer content in one undo step

#### Scenario: Buffer changes during execution
- **WHEN** the target buffer changed tick differs before result application
- **THEN** the system discards the result, reports a stale-result error, and preserves the user's newer content

#### Scenario: Buffer disappears during execution
- **WHEN** the target buffer is deleted, unloaded, or becomes ineligible before result application
- **THEN** the system discards the result and reports that the target is no longer available

### Requirement: Failure-safe completion feedback
The system SHALL never apply staging content from a cancelled, timed-out, permission-denied, malformed, or nonzero-exit run and SHALL clean up staging data after every terminal outcome.

#### Scenario: OpenCode executable missing
- **WHEN** the configured OpenCode executable cannot be found
- **THEN** the system reports the missing dependency without starting a job or changing the buffer

#### Scenario: OpenCode run fails
- **WHEN** OpenCode exits nonzero, emits an error event, reports a failed tool-use state, or does not complete exactly one staging-tool submit action
- **THEN** the system leaves the buffer unchanged and opens captured error details in a scratch float

#### Scenario: Successful no-op
- **WHEN** OpenCode exits successfully but the staging target is unchanged
- **THEN** the system reports that no changes were produced and leaves the buffer untouched

#### Scenario: Successful edit
- **WHEN** a result is applied
- **THEN** the system notifies the user that the target buffer changed and can be reverted with `u`

#### Scenario: Headless session cleanup
- **WHEN** the run emits an OpenCode session ID and then reaches any terminal outcome
- **THEN** the system attempts to delete that session asynchronously under a bounded timeout and reports cleanup timeout or failure without delaying or changing buffer application, staging cleanup, or editor responsiveness

### Requirement: Local setup defaults
The system SHALL provide a small setup table for the keymap, OpenCode command, timeout, input-size limit, and prompt dimensions.

#### Scenario: Use defaults
- **WHEN** setup receives no overrides
- **THEN** the action uses `<leader>ai`, `opencode`, a five-minute timeout, a 1 MiB input limit, and a cursor-relative prompt sized to 50 percent width by 20 percent height

#### Scenario: Override a setting
- **WHEN** setup receives a supported override
- **THEN** subsequent prompts and runs use that value without requiring a separate plugin dependency
