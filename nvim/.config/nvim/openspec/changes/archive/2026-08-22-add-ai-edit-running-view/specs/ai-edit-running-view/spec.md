## ADDED Requirements

### Requirement: Active target buffer lock
The system SHALL set the target buffer non-modifiable after accepting an instruction and before staging or OpenCode preflight begins. It SHALL keep unrelated buffers usable, retain final buffer identity and revision validation, and release its lock on every terminal outcome.

#### Scenario: Accepted request locks target
- **WHEN** a non-empty instruction passes target snapshot validation
- **THEN** the target buffer becomes non-modifiable through an owned transition that does not run option-change autocommands before asynchronous setup starts, and its text and changed tick still match the captured snapshot

#### Scenario: Ordinary edit attempt while running
- **WHEN** the user attempts to insert, delete, paste, or run a modifying command in the locked target buffer
- **THEN** Neovim rejects the mutation and the captured target text and changed tick remain unchanged

#### Scenario: Work continues in another buffer
- **WHEN** a target buffer is locked by an active AI edit and the user enters another writable buffer
- **THEN** the other buffer remains modifiable and can start an independent AI edit

#### Scenario: Successful result application
- **WHEN** a valid staged result is ready and target identity and revision still match
- **THEN** the system unlocks without running option-change autocommands, repeats identity, text, and revision validation, applies the result in one main-loop operation, leaves the target modifiable and unsaved, and preserves one-step undo

#### Scenario: Modifiable option callback is installed
- **WHEN** a plugin has an `OptionSet` handler that would re-enable or mutate the target during an owned lock, unlock, or restore transition
- **THEN** the owned transition suppresses that callback and no plugin mutation can enter between final validation and result application

#### Scenario: Terminal outcome without application
- **WHEN** the job ends through no-op, error, cancellation, timeout, stale-result rejection, or application failure
- **THEN** the system releases its lock without changing target text

#### Scenario: Forced mutation bypasses lock
- **WHEN** a user or plugin force-enables modification and changes the target during the run
- **THEN** the final revision check discards the staged result, preserves the newer target text, and leaves the target unlocked

#### Scenario: Target disappears while locked
- **WHEN** the target buffer is unloaded or deleted during the run
- **THEN** terminal cleanup tolerates the invalid buffer, closes owned UI, and reports the unavailable target without applying staged content

### Requirement: Locked-target caret suppression
The system SHALL hide the active editing caret while the current window displays an actively locked target. It SHALL preserve command-line cursor behavior and restore the latest user cursor configuration whenever the current buffer is not locked.

#### Scenario: Target window is locked
- **WHEN** the current window displays the target of an active AI edit under default or custom `guicursor` settings
- **THEN** the effective editing-mode cursor uses a blend-100 hidden highlight and the TUI caret is invisible

#### Scenario: User leaves target window
- **WHEN** a window stops displaying the locked target or the user enters an unrelated window
- **THEN** the system restores the saved `guicursor` value and the unrelated window uses its ordinary visible caret

#### Scenario: Target becomes visible again
- **WHEN** the locked target is shown in a new or existing window before the job finishes
- **THEN** the system reapplies editing-mode caret suppression while that target is current

#### Scenario: Command line opens over locked target
- **WHEN** the user enters a command-line mode while the locked target is current
- **THEN** the command-line caret keeps the user's configured shape and visibility

#### Scenario: Cursor configuration changes while hidden
- **WHEN** a user or plugin changes `guicursor` while locked-target suppression is active
- **THEN** the system removes every exact owned override from the new value, records the normalized value, reapplies exactly one hidden editing-mode override, and later restores the normalized value

#### Scenario: Current buffer changes between active jobs
- **WHEN** the user switches directly between two locked targets or one active job finishes while another locked target remains current
- **THEN** caret suppression remains active until the current buffer is no longer an active target

#### Scenario: Job releases caret state
- **WHEN** the job reaches any terminal outcome
- **THEN** the system restores the latest saved `guicursor` value unless another locked target is current

### Requirement: Live AI edit activity view
The system SHALL maintain a bounded readonly activity transcript for each active edit and display it in a non-focusable float aligned to the right side of a visible target window.

#### Scenario: Activity starts immediately
- **WHEN** an instruction is accepted
- **THEN** the system opens the activity float without changing focus and shows the request plus the current host setup phase before waiting for OpenCode events

#### Scenario: Host setup advances
- **WHEN** the job enters version, configuration, helper, agent, or model-run setup phases
- **THEN** the activity transcript identifies the current phase

#### Scenario: Assistant text completes
- **WHEN** OpenCode emits a completed `text` event for the active session
- **THEN** the system appends its sanitized assistant text and scrolls the view to the newest content

#### Scenario: Tool use completes
- **WHEN** OpenCode emits a completed or failed `tool_use` event
- **THEN** the system appends a concise tool label derived only from allowlisted display fields while preserving existing validation of errors and staging submissions

#### Scenario: Sensitive event fields are excluded
- **WHEN** an event contains model reasoning, raw tool output, replacement content, a private staging path, a session identifier, or an unknown payload
- **THEN** the activity transcript does not render that content

#### Scenario: Transcript reaches its limit
- **WHEN** rendered activity exceeds the fixed internal byte or line bound
- **THEN** the system truncates oversized entries at UTF-8 boundaries, removes oldest aggregate content, marks truncation, and keeps the newest activity visible within both bounds

#### Scenario: Target visibility changes
- **WHEN** no window displays the active target
- **THEN** the float closes without ending the job, the bounded transcript keeps updating, and the float reopens with current content when the target becomes visible

#### Scenario: Concurrent activity views
- **WHEN** independent jobs target buffers visible in separate windows
- **THEN** each job keeps separate activity content and displays it beside its own target

#### Scenario: Target window resizes
- **WHEN** the target window dimensions change during a run
- **THEN** the activity float remains right-aligned and clamps its dimensions within usable target-window space

#### Scenario: Activity reaches terminal outcome
- **WHEN** a job succeeds, produces no change, fails, is cancelled, times out, or becomes stale
- **THEN** the system closes and deletes that job's activity view without changing current focus, then preserves existing outcome notification and detailed error behavior
