# Herdr

Herdr 0.8.2 replaces tmux for normal interactive work. Tmux stays installed for rollback and existing sessions.

Install configuration from repository root:

```sh
stow -t "$HOME" herdr
herdr config check
herdr server reload-config
```

## Key map

Press `ctrl+a`, release it, then press action key.

| Keys | Action |
| --- | --- |
| `h`, `j`, `k`, `l` | Focus pane left, down, up, right |
| `v`, `%` | Split side by side |
| `-`, `'` | Split stacked |
| `x`, `z`, `[` | Close pane, zoom pane, enter copy mode |
| `c`, `,`, `&` | Create, rename, close tab |
| `n`, `p`, `1..9` | Cycle or select tabs |
| `s` | Open workspace picker; navigate with arrows, `j`/`k`, or `ctrl+n`/`ctrl+p` |
| `w`, `g` | Open session navigator |
| `d`, `q` | Detach while keeping processes alive |
| `$` | Rename workspace |
| `P`, `N` | Select previous or next workspace |
| `r`, `R` | Enter resize mode, reload configuration |
| `ctrl+shift+alt+arrows` | Resize focused pane directly |
| `S`, `?` | Open settings or key help |

Use `ctrl+a f` to fuzzy-find a project below `~/projects` or a checkout below `~/projects/<project>/.worktrees`. It focuses an existing workspace rooted there or creates a new workspace. Create an empty workspace with `ctrl+a C`. Create a worktree with `ctrl+a G`. Close a workspace with `ctrl+a D`. `ctrl+a ^` and direct Alt-number shortcuts are intentionally unbound.

## Persistence

Detach preserves live pane processes, layout, scrollback, and agent sessions because server keeps running. Reattach with `herdr`.

Full server restart stops pane processes. Herdr restores workspaces, tabs, panes, layout, focus, and working directories. Pi, Copilot, OpenCode, and Antigravity can resume conversations when their official integrations reported valid session IDs. Other panes restart as shells.

Pane screen history remains disabled because output may contain secrets. Full restart therefore does not restore recent screen contents. Each live pane retains up to 10 MB scrollback while server runs.

Herdr cannot reproduce tmux command prompt, arbitrary layouts, tmux plugins, or arbitrary process restoration.

## Worktrees

Use workspace context menu or `ctrl+a G` to create a Git worktree. Herdr stores managed checkouts below `~/.herdr/worktrees/<repo>/<branch>` and groups them under source workspace. Closing workspace does not delete checkout or branch. Use `Delete worktree checkout` to remove checkout after confirmation.

## Remote access

For tmux-style remote use:

```sh
ssh host
herdr
```

For local thin-client rendering against remote Herdr server:

```sh
herdr --remote host
```

First option works in any SSH client. Second option supports local desktop features such as image clipboard bridging. Both run panes and agents on remote host.

## Nesting

Do not start Herdr inside Herdr. `experimental.allow_nested = false` enforces this. No shell wrapper changes are required.

## Rollback

From repository root:

```sh
stow -D -t "$HOME" herdr
```

Reload or restart Herdr to use defaults. Restore removed tmux and zsh bindings from Git if returning to tmux workflow. Tmux and sessionizer scripts remain installed.
