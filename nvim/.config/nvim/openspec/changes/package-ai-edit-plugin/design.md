## Context

AI edit currently consists of a 2,340-line Lua module at `lua/vichr/ai_edit.lua`, a trusted OpenCode tool at `lua/vichr/ai_edit/stage_text.ts`, and a substantial fake, hostile-project, TUI, and real-OpenCode test suite under `tests/ai_edit/`. The module is loaded directly from this Neovim configuration and exposes the private `vichr.ai_edit` name. The repository README still documents Kickstart rather than AI edit.

The feature has stronger distribution constraints than a typical Lua plugin. It accepts stable OpenCode versions `>=1.18.21 <2.0.0` as a security boundary, installs the exact matching `@opencode-ai/plugin` helper dependency on first use, relies on Unix file permissions and process behavior, and allows project reads that are not an operating-system sandbox. Packaging must make these constraints visible and test them without weakening existing isolation.

The completed `improve-ai-edit-prompt` change also needs to be archived before extraction so the canonical specs and implementation agree on the current cursor-relative prompt and 50-by-20-percent defaults.

## Goals / Non-Goals

**Goals:**

- Make AI edit installable from public GitHub repository `vichr-vita/ai-edit.nvim` through Lazy and any package manager that adds a repository to Neovim's runtime path.
- Make the standalone repository the only implementation and test source after migration.
- Preserve current edit, staging, isolation, prompt, running-view, and statusline behavior.
- Give users complete install, configuration, prerequisite, security, troubleshooting, and removal documentation.
- Detect common local prerequisite failures through `:checkhealth ai_edit` before a model request.
- Gate publication with formatting, regression, installed-OpenCode, clean-install, and supported-platform checks.
- Keep this dotfiles repository as an ordinary plugin consumer with the current personal model and lualine settings.

**Non-Goals:**

- Supporting Windows in the initial release.
- Supporting OpenCode versions below 1.18.21, version 2.0.0 or newer, or prereleases, or relaxing the existing tool and plugin trust boundary.
- Adding chat, multi-file edits, blockwise edits, diff approval, persistence, or new model capabilities.
- Adding a Lua plugin dependency or requiring Bun from plugin users independently of OpenCode.
- Automating releases on every main-branch commit.

## Decisions

### Use a dedicated public repository as canonical source

Create `vichr-vita/ai-edit.nvim` as a public repository rather than publishing the whole dotfiles repository or maintaining a generated subtree branch. A conventional plugin root lets package managers place the repository directly on `runtimepath`, keeps user documentation focused, and makes release checks independent from personal configuration.

The repository layout will be:

```text
ai-edit.nvim/
├── lua/ai_edit/init.lua
├── lua/ai_edit/stage_text.ts
├── lua/ai_edit/health.lua
├── doc/ai-edit.txt
├── tests/ai_edit/
├── .github/workflows/ci.yml
├── .gitignore
├── .stylua.toml
├── CONTRIBUTING.md
├── LICENSE
└── README.md
```

Do not keep a second implementation copy in dotfiles. After the public repository passes a clean remote install, remove local module and tests and configure the remote plugin through Lazy. A generated mirror was rejected because publishing failures could leave GitHub code different from reviewed source. Keeping source in both repositories was rejected because the trusted helper and pinned dependency could drift.

The current implementation and tests include tracked modifications and untracked files beyond dotfiles `HEAD`. Before changing namespaces or deleting anything, copy their exact bytes into the standalone Git worktree, compare a SHA-256 manifest covering the Lua module, trusted helper, and complete test tree, and commit that extraction baseline. Do not use dotfiles `HEAD` as rollback source. Keep the standalone checkout and baseline commit until dotfiles migration and rollback verification finish.

### Publish `ai_edit` as the stable Lua module

Move the main module to `lua/ai_edit/init.lua` and resolve the helper through `lua/ai_edit/stage_text.ts`. Public calls become `require('ai_edit').setup`, `cancel`, `statusline`, and `statusline_color`. Rename private error prefixes and augroups to package-owned names. Existing cache directory names and `AIEditCancel` remain stable because changing them gives users no benefit.

`setup` remains explicit. The plugin will not add a `plugin/*.lua` autoload file or mutate mappings before setup. Lazy installation uses `main = 'ai_edit'` and `opts = {}` so its standard config handler invokes setup. Other managers call setup after adding the repository to `runtimepath`.

Make repeated setup deterministic: clear package-owned autocommands, replace package-owned commands, remove the prior package-owned normal and visual mappings when the configured key changes, and retain active-job safety. This matters in public configurations that reload modules and in the existing test suite, which reconfigures options repeatedly.

### Declare a narrow supported environment

Initial runtime support is Neovim 0.11 or newer on macOS and Linux. These targets cover the APIs already used and the Unix permission model that protects staging and helper caches. CI will test Neovim 0.11 and current stable on Linux, plus current stable on macOS. The plugin makes no minimum OS-release, kernel, distribution, libc, or architecture claim until those boundaries have dedicated tests. Windows remains explicitly unsupported until its permission and process semantics receive equivalent tests.

OpenCode support is limited to stable semantic versions `>=1.18.21 <2.0.0`. Users need an executable discoverable through `command`, a configured provider and model, and valid provider credentials. First use per resolved OpenCode version needs network access so OpenCode can install the exact matching `@opencode-ai/plugin` into the private content-addressed helper cache; later runs can reuse a verified cache offline. Project reads are allowed only for trusted worktrees because an in-project symlink can escape OpenCode's lexical path checks.

Bun 1.3 or newer and StyLua 2.0 or newer are contributor dependencies, not runtime user prerequisites. OpenCode owns the TypeScript tool runtime and dependency bootstrap during normal use.

### Add bounded health diagnostics

Implement `lua/ai_edit/health.lua` using Neovim's health API. It reports Neovim and operating-system support, resolves the configured or default OpenCode command, executes only `--version`, and requires a stable version in `>=1.18.21 <2.0.0`. It also reports first-run network/cache expectations, provider authentication guidance, and the trusted-worktree warning.

Health checks do not resolve OpenCode config, initialize tools, contact a model, create a session, inspect credentials, or modify caches. Full config and agent safety preflight stays in the edit path because duplicating it in diagnostics could execute managed extensions or make a health check stateful.

### Split user docs from contributor docs

README is the package landing page. It includes purpose, behavior summary, prerequisites, Lazy installation, generic runtime-path installation, setup with every option and default, normal and visual usage, prompt/history keys, cancellation, statusline and lualine integration, security model, data/cache/session lifecycle, health checks, troubleshooting, development commands, supported platforms, license, and the bounded OpenCode compatibility policy.

`doc/ai-edit.txt` provides the same operational reference through `:help ai-edit`, with help tags for setup, options, mappings, commands, statusline API, health, security, and troubleshooting. `CONTRIBUTING.md` owns local tooling, test categories, optional OAuth smoke instructions, and release procedure so README stays usable.

README must not claim an OS sandbox or guaranteed remote session deletion. It must explain that edits remain unsaved and undoable, the target locks while work runs, project source can be read, temporary staging is private and removed on terminal outcomes, OpenCode can retain logs or sessions when cleanup cannot observe or delete them, and model/provider services retain data under their own policies.

### Treat CI and a clean remote install as release prerequisites

CI runs StyLua checks, TypeScript helper tests, headless prompt and job regressions, running-view tests, TUI caret tests where pseudoterminal support exists, clean Neovim startup, and installed OpenCode hostile-boundary tests. The matrix covers the minimum Neovim version and current stable on Linux and current stable on macOS. It pins baseline OpenCode 1.18.21, exercises higher compatible versions through fake regressions, and pins contributor tool versions or major lines.

The real OAuth/model smoke remains opt-in because it requires credentials, network access, incurs provider cost, and should not run for untrusted pull requests. A maintainer workflow or documented local command can run it before release.

Create `v0.1.0` only after CI passes and a fresh temporary Neovim configuration installs the public repository through Lazy, opens AI edit with defaults, reports healthy prerequisites, and completes fake-OpenCode whole-buffer and selection smoke tests. Do not mark the release stable before remote-clone verification because local paths can hide missing runtime files.

### Migrate dotfiles only after publication succeeds

Add a Lazy spec for `vichr-vita/ai-edit.nvim` with `main = 'ai_edit'` and the current model, variant, and status options. Remove the direct setup call from `init.lua`. Make lualine load `ai_edit` after the plugin dependency is available and keep existing status component behavior.

Keep the local source until the public repository and clean-install gate pass. Then remove local module, helper, and migrated tests in one migration checkpoint while retaining the standalone checkout. If the remote becomes unavailable, rollback first points Lazy at that checkout pinned to `v0.1.0`; restoring the private pre-extraction layout uses the byte-verified extraction baseline commit and direct require. Document and execute both commands before deleting the last local duplicate. Cache content needs no migration because package and helper cache identifiers stay stable.

## Risks / Trade-offs

- [Public repository creation and source removal can leave dotfiles temporarily broken] -> Publish and verify the remote clone before changing the consumer configuration or deleting local source.
- [Dirty and untracked AI edit work cannot be restored from dotfiles `HEAD`] -> Commit a byte-verified extraction baseline in the standalone repository before namespace changes and retain that checkout through a rollback drill.
- [Two repositories can drift during migration] -> Use one short migration window, compare extracted files, and remove the dotfiles copy immediately after remote verification.
- [Neovim 0.11 behavior differs from the current 0.12.4 development environment] -> Run the complete supported subset against 0.11 before declaring compatibility and fix package code without compatibility shims beyond the stated baseline.
- [macOS and Linux permission behavior differs] -> Run installed-OpenCode and private-cache tests on both supported platforms; omit unsupported tests only when the missing platform facility is documented.
- [Health diagnostics imply more safety than they prove] -> Limit checks to local prerequisites and state that every edit still performs authoritative version, config, tool, and agent preflight.
- [First use fails offline] -> Document network need, keep the existing actionable bootstrap error, and explain that a verified cache supports later offline runs.
- [Compatible OpenCode releases can change trusted bundled behavior] -> Bound support to the current major, pair each CLI with its exact helper SDK, and retain config, tool, hostile, and OAuth checks.
- [Public setup reloads while jobs run] -> Preserve active job state and test repeated setup; reject or defer changes that would orphan active timers, mappings, or cleanup callbacks.
- [README duplicates Vim help] -> Keep README task-oriented and help reference-oriented, then test all documented module names, commands, defaults, and links.

## Migration Plan

1. Validate and archive `improve-ai-edit-prompt`, then use its synchronized main spec as extraction baseline.
2. Copy exact current implementation and test bytes into a standalone Git worktree, verify and commit the extraction baseline, then build the public layout, rename module paths, and harden repeated setup without changing edit behavior.
3. Add health checks, README, Vim help, contribution guide, license, metadata, and CI.
4. Run local and CI suites on supported versions and platforms.
5. Create the public GitHub repository, push canonical source, and verify a fresh Lazy install from its remote URL.
6. Tag and publish `v0.1.0` after release gates pass.
7. Convert dotfiles to a Lazy consumer, update lualine ordering, remove local implementation/tests, and run startup plus real-config smoke tests.

Rollback either points Lazy at retained standalone `v0.1.0` checkout or restores the byte-verified private layout from its extraction baseline commit and reinstates the direct setup call. The published repository and tag remain historical artifacts; no user data schema or cache migration is involved.

## Open Questions

None.
