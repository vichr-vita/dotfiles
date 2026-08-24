## MODIFIED Requirements

### Requirement: Local setup defaults
The system SHALL expose `setup`, `cancel`, `statusline`, and `statusline_color` through public module `require('ai_edit')`, SHALL provide setup options for the keymap, OpenCode command, model and variant override, run and cleanup timeouts, input-size limit, prompt dimensions, and status display, and SHALL support deterministic repeated setup without leaving prior package-owned mappings, commands, or autocommands behind.

#### Scenario: Use defaults
- **WHEN** `require('ai_edit').setup({})` receives no overrides
- **THEN** the action uses `<leader>ai`, `opencode`, inherited resolved model/provider settings, no variant override, a five-minute run timeout, a two-second cleanup timeout, a 1 MiB input limit, a cursor-relative prompt sized to 50 percent width by 20 percent height, and the documented default animated status

#### Scenario: Override a setting
- **WHEN** setup receives a supported override through the public module
- **THEN** subsequent prompts, runs, cleanup, mappings, and status output use that value without requiring another Neovim plugin dependency

#### Scenario: Configure model variant
- **WHEN** setup receives a valid `provider/model` string and non-empty variant
- **THEN** only the runtime-generated edit agent uses that model and variant while inherited provider configuration remains available

#### Scenario: Reject invalid setup
- **WHEN** setup receives an unknown option, invalid type, invalid range, variant without model, or malformed status configuration
- **THEN** setup raises an error prefixed with the public `ai_edit` module name before starting an edit

#### Scenario: Change keymap through repeated setup
- **WHEN** setup runs again with a different keymap while no edit is active
- **THEN** the package removes its prior normal and visual mappings, installs the new mappings, and keeps exactly one package-owned cancellation command and autocommand group

#### Scenario: Repeat setup while an edit is active
- **WHEN** setup runs while one or more target buffers have active edits
- **THEN** existing jobs retain their captured options, process handles, timers, locks, activity views, and cleanup behavior while subsequent jobs use the new setup values
