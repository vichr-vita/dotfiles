# Dotfiles

This repository contains my personal dotfiles. They are managed using [GNU Stow](https://www.gnu.org/software/stow/), which keeps the installed files as symlinks instead of copying the whole repo into `$HOME`.

## Minimal setup

For a focused setup, this repo now includes `./stow.sh`, which defaults to installing only:

- `nvim`
- `tmux`

The tmux and Herdr packages also install their sessionizer scripts. The Stow helper uses `--no-folding` so only selected files are linked into your home directory.

## Prerequisites

- GNU Stow
- Neovim
- tmux
- Herdr and `jq` for the optional `herdr` package
- `fzf` for `tmux-sessionizer`
- `xclip` for the tmux yank binding on Linux

## Usage

```sh
# Default: stow only nvim + tmux
./stow.sh

# Pick packages explicitly
./stow.sh nvim tmux
./stow.sh herdr nvim
./stow.sh alacritty nvim tmux

# Show the curated package list or stow everything in it
./stow.sh --list
./stow.sh --all

# Preview changes or stow into another target
./stow.sh --dry-run
./stow.sh --target /tmp/dotfiles-home --dry-run
```

`nvim-example` is kept as reference material and is intentionally not included in the helper script's package list.

## Manual equivalent

If you do not want to use the helper script, the minimal install is:

```sh
stow --dir="$PWD" --target="$HOME" --restow --no-folding nvim tmux
```

Package-level Stow ignore files keep non-runtime files such as Neovim docs/review notes and shell backup files out of the installed target.
