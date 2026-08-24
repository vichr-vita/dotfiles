## ADDED Requirements

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

## MODIFIED Requirements

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

### Requirement: Local setup defaults
The system SHALL provide a small setup table for the keymap, OpenCode command, timeout, input-size limit, and prompt dimensions.

#### Scenario: Use defaults
- **WHEN** setup receives no overrides
- **THEN** the action uses `<leader>ai`, `opencode`, a five-minute timeout, a 1 MiB input limit, and a cursor-relative prompt sized to 50 percent width by 20 percent height

#### Scenario: Override a setting
- **WHEN** setup receives a supported override
- **THEN** subsequent prompts and runs use that value without requiring a separate plugin dependency
