## ADDED Requirements

### Requirement: Standalone package installation
The system SHALL publish AI edit from public repository `vichr-vita/ai-edit.nvim` with a conventional Neovim runtime layout, SHALL expose its Lua API as `require('ai_edit')`, and SHALL include the trusted `stage_text` helper in the same installed runtime without depending on private dotfiles paths.

#### Scenario: Install with Lazy
- **WHEN** a user configures `vichr-vita/ai-edit.nvim` with `main = 'ai_edit'` and `opts = {}` in Lazy
- **THEN** Lazy installs the repository, resolves `require('ai_edit')`, and invokes setup without copied local files or another Neovim plugin dependency

#### Scenario: Install through another runtime-path package manager
- **WHEN** another package manager adds the repository root to Neovim's runtime path and the user calls `require('ai_edit').setup({})`
- **THEN** setup resolves the Lua module and trusted TypeScript helper from that repository

#### Scenario: Load outside personal dotfiles
- **WHEN** a clean Neovim configuration loads the installed plugin
- **THEN** no module, path, option, or test fixture under the private `vichr` namespace is required

### Requirement: Supported runtime prerequisites
The plugin SHALL support Neovim 0.11 or newer on macOS and Linux, SHALL require a stable OpenCode executable in version range `>=1.18.21 <2.0.0` with a configured model/provider and valid credentials, SHALL use the exact matching `@opencode-ai/plugin` helper version, and SHALL document first-use network access plus the trusted-worktree restriction as runtime prerequisites. Windows SHALL remain unsupported until equivalent file-permission and process-isolation tests exist.

#### Scenario: Supported environment
- **WHEN** Neovim 0.11 or newer runs on macOS or Linux and resolves an authenticated supported OpenCode version
- **THEN** the plugin accepts setup and can perform its normal per-edit safety preflight

#### Scenario: OpenCode version falls outside supported range
- **WHEN** the configured executable reports a version below 1.18.21, version 2.0.0 or newer, a prerelease, or malformed output
- **THEN** health diagnostics and edit preflight report the supported range and do not describe the installation as compatible

#### Scenario: First edit has no helper cache
- **WHEN** a compatible installation starts its first edit without a verified helper cache
- **THEN** documentation states that network access is required to install the exact `@opencode-ai/plugin` version matching the resolved CLI and that bootstrap failure leaves the target unchanged

#### Scenario: Worktree contains untrusted content
- **WHEN** a user evaluates whether to run AI edit in an untrusted worktree
- **THEN** documentation warns that project reads are not an operating-system sandbox and in-project symlinks can expose files outside the worktree

#### Scenario: Contributor installs development tools
- **WHEN** a contributor prepares to run the repository checks
- **THEN** contributor documentation distinguishes Bun 1.3 or newer and StyLua 2.0 or newer from end-user runtime prerequisites

### Requirement: Local health diagnostics
The plugin SHALL provide `:checkhealth ai_edit` diagnostics for supported Neovim versions and operating-system families, configured OpenCode executable resolution, and supported OpenCode version range, and SHALL report guidance for provider authentication, first-use bootstrap, and trusted-worktree use without starting a model, loading a tool registry, creating a session, inspecting credentials, or modifying a cache.

#### Scenario: Health check passes local prerequisites
- **WHEN** a supported Neovim host resolves a stable OpenCode version in `>=1.18.21 <2.0.0`
- **THEN** `:checkhealth ai_edit` reports those local prerequisites as healthy and explains which provider, network, and trust conditions still require user confirmation

#### Scenario: OpenCode executable is missing
- **WHEN** the configured OpenCode command cannot be resolved
- **THEN** health diagnostics report the missing executable and an installation action without starting an edit

#### Scenario: Host platform is unsupported
- **WHEN** health diagnostics run on an unsupported Neovim version or operating system
- **THEN** they report the unsupported value and the documented support boundary

#### Scenario: Health check remains read-only
- **WHEN** a user runs `:checkhealth ai_edit`
- **THEN** the check executes at most local version inspection and does not resolve executable OpenCode extensions, contact a model, create or delete a session, or write helper content

### Requirement: Complete user documentation
The repository SHALL provide a README and `:help ai-edit` documentation that accurately cover installation, every setup option and default, normal and visual usage, prompt and history keys, cancellation, statusline integration, health checks, troubleshooting, supported platforms, bounded OpenCode compatibility, security boundaries, temporary data and session cleanup, contribution checks, and licensing.

#### Scenario: Configure every supported option
- **WHEN** a user consults the README or Vim help before calling setup
- **THEN** each accepted option, nested status option, type, default, and validation constraint is documented with a working public-module example

#### Scenario: Integrate lualine status
- **WHEN** a user wants active AI edit status in lualine
- **THEN** documentation provides a working example using `require('ai_edit').statusline` and `statusline_color`

#### Scenario: Understand edit lifecycle
- **WHEN** a user reviews usage and security documentation
- **THEN** it states that target changes remain unsaved and one-step undoable, target buffers lock during work, project reads remain available, staging content is private and removed on terminal outcomes, and OpenCode or providers can retain logs, sessions, or submitted data outside plugin control

#### Scenario: Diagnose a known failure
- **WHEN** setup, executable discovery, version preflight, provider authentication, helper bootstrap, unsafe managed configuration, timeout, or cleanup fails
- **THEN** troubleshooting documentation maps the visible failure to a concrete check or corrective action without recommending weaker permissions

### Requirement: Public repository quality gate
The standalone repository SHALL include a complete MIT license, formatting configuration, ignored generated artifacts, contributor instructions, and CI that verifies supported Neovim and operating-system targets before an initial release. Real provider OAuth tests SHALL remain opt-in and SHALL NOT run for untrusted pull requests.

#### Scenario: Validate a pull request
- **WHEN** a pull request changes plugin code, helper code, tests, or documentation
- **THEN** CI checks StyLua formatting, helper tests, fake-OpenCode compatible-version regressions, supported headless and TUI behavior, clean startup, documentation references, and installed baseline OpenCode 1.18.21 safety boundaries on the applicable matrix targets

#### Scenario: Test real OAuth
- **WHEN** a maintainer explicitly enables the credentialed OAuth smoke test in a trusted environment
- **THEN** the test exercises real whole-buffer and UTF-8 selection edits while preserving hostile-project isolation and cleaning observable sessions

#### Scenario: Publish initial release
- **WHEN** maintainers prepare `v0.1.0`
- **THEN** all required CI passes and a fresh temporary Neovim configuration installs the public remote through Lazy, passes health diagnostics, and completes documented smoke tests before the tag and release are published

### Requirement: Single canonical implementation
After successful publication and remote-install verification, the public plugin repository SHALL be the only maintained copy of AI edit implementation and tests, while this Neovim configuration SHALL consume it through Lazy and retain only personal setup and lualine integration.

#### Scenario: Complete dotfiles migration
- **WHEN** the public repository passes clean-install verification
- **THEN** dotfiles remove the local Lua module, trusted helper, and migrated tests, install `vichr-vita/ai-edit.nvim`, and preserve current model, variant, status color, keymap, cancellation, and lualine behavior

#### Scenario: Public installation fails before migration
- **WHEN** remote repository creation, CI, or clean-install verification fails
- **THEN** dotfiles retain the working local implementation and do not switch to an unavailable package
