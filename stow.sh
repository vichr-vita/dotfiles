#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
target_dir=$HOME
dry_run=false
install_all=false
default_packages=(nvim tmux)
available_packages=(alacritty nvim skhd tmux yabai zsh)
packages=()

usage() {
  cat <<'EOF'
Usage: ./stow.sh [options] [package...]

Defaults to installing the minimal setup:
  nvim tmux

Options:
  --all               Stow every curated package in this repo.
  --dry-run           Show the Stow actions without changing the target.
  --list              Print the curated package list and exit.
  -t, --target DIR    Stow into DIR instead of $HOME.
  -h, --help          Show this help message.
EOF
}

while (($# > 0)); do
  case "$1" in
    --all)
      install_all=true
      shift
      ;;
    --dry-run)
      dry_run=true
      shift
      ;;
    --list)
      printf '%s\n' "${available_packages[@]}"
      exit 0
      ;;
    -t|--target)
      if (($# < 2)); then
        echo "error: --target requires a directory argument" >&2
        exit 1
      fi
      target_dir=$2
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      while (($# > 0)); do
        packages+=("$1")
        shift
      done
      ;;
    -*)
      echo "error: unknown option '$1'" >&2
      usage >&2
      exit 1
      ;;
    *)
      packages+=("$1")
      shift
      ;;
  esac
done

if ! command -v stow >/dev/null 2>&1; then
  echo "error: GNU Stow is required but was not found in PATH" >&2
  exit 1
fi

if [[ $install_all == true ]]; then
  packages=("${available_packages[@]}" "${packages[@]}")
fi

if ((${#packages[@]} == 0)); then
  packages=("${default_packages[@]}")
fi

declare -A valid_packages=()
declare -A seen_packages=()
selected_packages=()

for package in "${available_packages[@]}"; do
  valid_packages["$package"]=1
done

for package in "${packages[@]}"; do
  if [[ -z "${valid_packages[$package]:-}" ]]; then
    echo "error: unknown package '$package'" >&2
    echo "available packages: ${available_packages[*]}" >&2
    exit 1
  fi

  if [[ -n "${seen_packages[$package]:-}" ]]; then
    continue
  fi

  if [[ ! -d "$repo_root/$package" ]]; then
    echo "error: package directory '$repo_root/$package' does not exist" >&2
    exit 1
  fi

  selected_packages+=("$package")
  seen_packages["$package"]=1
done

mkdir -p "$target_dir"

stow_args=(
  --dir="$repo_root"
  --target="$target_dir"
  --restow
  --no-folding
)

if [[ $dry_run == true ]]; then
  stow_args+=(--simulate --verbose=2)
fi

echo "Stowing packages into $target_dir: ${selected_packages[*]}"
stow "${stow_args[@]}" "${selected_packages[@]}"
