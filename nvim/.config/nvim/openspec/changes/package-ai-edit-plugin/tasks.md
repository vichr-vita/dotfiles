## 1. Establish migration baseline

- [x] 1.1 Validate and archive completed `improve-ai-edit-prompt`, then confirm main `opencode-buffer-editing` spec contains cursor-relative prompt, 50-by-20-percent defaults, and instruction history requirements.
- [x] 1.2 Run current StyLua, helper, headless, running-view, TUI, hostile-boundary, and clean-startup checks before moving files; record any credentialed OAuth smoke as optional.
- [x] 1.3 Confirm `vichr-vita/ai-edit.nvim` remains available, GitHub authentication can create a public repository, and no publication action occurs before standalone checks pass.

## 2. Build standalone plugin tree

- [x] 2.1 Copy exact current Lua module, trusted helper, and complete test tree into a standalone Git worktree, compare a SHA-256 manifest against dirty and untracked dotfiles bytes, and commit the verified extraction baseline before edits.
- [x] 2.2 Create repository-ready root with `lua/ai_edit/init.lua`, colocated `stage_text.ts`, `lua/ai_edit/health.lua`, `doc/`, `tests/`, `.github/`, and repository metadata paths.
- [x] 2.3 Rename copied implementation and tests from private `vichr.ai_edit` paths to public `ai_edit` paths; update helper discovery, test fixtures, error prefixes, augroups, remote expressions, formatting targets, and clean-startup checks without changing edit behavior.
- [x] 2.4 Make repeated setup remove prior package-owned mappings when the key changes, keep one command and autocommand group, preserve active job state, and add focused regression coverage.
- [x] 2.5 Verify a clean Neovim runtime path can call all public functions and resolve trusted helper source without any dotfiles files or private namespace.

## 3. Add diagnostics and documentation

- [x] 3.1 Implement and test read-only `:checkhealth ai_edit` checks for Neovim 0.11+, macOS/Linux support, executable discovery, stable OpenCode `>=1.18.21 <2.0.0`, and non-authoritative provider, bootstrap, and trusted-worktree guidance.
- [x] 3.2 Replace Kickstart content with plugin README covering purpose, behavior, prerequisites, Lazy and generic installation, every setup option/default, normal and visual use, prompt/history keys, cancellation, statusline/lualine integration, health, security, data lifecycle, troubleshooting, development, compatibility, and license.
- [x] 3.3 Add `doc/ai-edit.txt` help tags for setup, options, mappings, commands, statusline API, health, security, and troubleshooting; verify `:helptags` and documented Lua examples.
- [x] 3.4 Add `CONTRIBUTING.md`, complete MIT `LICENSE`, `.gitignore`, and standalone StyLua configuration with contributor Bun 1.3+ and StyLua 2.0+ requirements plus optional OAuth and release instructions.

## 4. Make verification portable

- [x] 4.1 Adapt test orchestration to standalone paths and separate required fake/headless/TUI compatible-version checks, installed baseline OpenCode 1.18.21 boundary checks, and credentialed OAuth smoke.
- [x] 4.2 Add CI for Neovim 0.11 and current stable on Linux plus current stable on macOS, with pinned baseline OpenCode 1.18.21 and reproducible Bun/StyLua setup.
- [x] 4.3 Ensure CI runs formatting, helper, prompt, asynchronous job, running-view, supported TUI, clean-startup, help/doc reference, and hostile-boundary checks while excluding credentials from untrusted pull requests.
- [x] 4.4 Run all required standalone checks locally on the development host and fix every regression before publication.

## 5. Publish and release

- [x] 5.1 Create public `vichr-vita/ai-edit.nvim`, push standalone canonical source and tests, and confirm required CI starts from repository content rather than dotfiles paths.
- [x] 5.2 Use a fresh temporary Neovim configuration to install the public remote through Lazy with `main = 'ai_edit'` and `opts = {}`, then verify health plus fake whole-buffer and UTF-8 selection smoke tests.
- [x] 5.3 Confirm required GitHub checks pass and record whether the optional real OAuth smoke was run in a trusted credentialed environment. Required CI passed; optional OAuth smoke was not run.
- [x] 5.4 Tag and publish `v0.1.0` with exact Neovim, operating-system, and OpenCode support boundaries only after remote-clone verification passes.

## 6. Convert dotfiles to plugin consumer

- [x] 6.1 Add a Lazy spec for `vichr-vita/ai-edit.nvim` using public `ai_edit` module and preserve current model, variant, status color, and default keymap configuration.
- [x] 6.2 Update lualine to load after the AI edit plugin and use public `statusline` and `statusline_color` functions without first-install ordering failures.
- [x] 6.3 While local source remains intact, execute documented remote-unavailable fallback through the standalone checkout and restore the private pre-extraction layout in a disposable tree; require matching baseline manifest and passing startup/tests from both recovery paths.
- [x] 6.4 Remove direct setup from `init.lua` and delete dotfiles-local module, trusted helper, and migrated tests only after publication, remote installation, and both rollback drills succeed; retain the standalone checkout through migration verification.
- [x] 6.5 Run clean startup, Lazy first-install, configured startup, keymap, cancellation, and lualine status smoke tests; verify no `vichr.ai_edit` reference or duplicate maintained implementation remains.

## 7. Final verification

- [x] 7.1 Validate `package-ai-edit-plugin` strictly and ensure proposal, design, delta specs, README claims, Vim help, CI matrix, and released files agree on module names, defaults, prerequisites, and trust boundaries.
- [x] 7.2 Run `git diff --check`, inspect both repository states and rollback-drill records, and verify the retained checkout and extraction baseline remain available without modifying unrelated dotfiles changes.
