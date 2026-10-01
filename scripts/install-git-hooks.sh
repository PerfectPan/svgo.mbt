#!/usr/bin/env bash
set -euo pipefail

force=false

usage() {
  cat <<'USAGE'
Usage:
  scripts/install-git-hooks.sh [--force]

Installs this template's local Git hooks by setting core.hooksPath to .githooks.
If another hooks path is already configured, the script fails unless --force is used.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --force)
      force=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'install-git-hooks: unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$repo_root"

if [[ ! -x ".githooks/pre-commit" ]]; then
  printf 'install-git-hooks: .githooks/pre-commit is missing or not executable\n' >&2
  exit 1
fi

current_hooks_path="$(git config --get core.hooksPath || true)"
if [[ -n "$current_hooks_path" && "$current_hooks_path" != ".githooks" && "$force" != true ]]; then
  printf 'install-git-hooks: core.hooksPath is already set to %s\n' "$current_hooks_path" >&2
  printf 'install-git-hooks: re-run with --force to replace it with .githooks\n' >&2
  exit 1
fi

git config core.hooksPath .githooks
printf 'install-git-hooks: core.hooksPath set to .githooks\n'
