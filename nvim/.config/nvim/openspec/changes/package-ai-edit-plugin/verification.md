## Release gates

- Release: `v0.1.0` at `07155e0d81cd44b139aa898981acce9b93e2d910`
- CI: https://github.com/vichr-vita/ai-edit.nvim/actions/runs/32770044193
- Matrix: Neovim 0.11.4 and stable on Linux; Neovim 0.12.5 on macOS 15
- Fresh Lazy install: health, fake whole-buffer edit, and UTF-8 selection edit passed from public remote content
- Optional credentialed OAuth smoke: not run

## Rollback drills

- Remote-unavailable fallback: retained standalone checkout at `v0.1.0` loaded through Lazy `dir`; health and both edit smokes passed.
- Private-layout fallback: detached worktree at extraction baseline `ebfc42e` matched all 37 committed files by SHA-256.
- Private-layout checks: 28 helper/follow-up/running-view/hostile tests, TUI test, headless assertions, prompt assertions, and clean startup passed.
- Retained checkout: `/var/folders/6m/81b1hqjj7nv1mql3fwlkn21c0000gn/T/opencode/ai-edit.nvim`
- Detached baseline drill: `/var/folders/6m/81b1hqjj7nv1mql3fwlkn21c0000gn/T/opencode/ai-edit-private-rollback`
