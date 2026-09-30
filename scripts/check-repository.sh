#!/usr/bin/env bash
set -euo pipefail

staged=false

usage() {
  cat <<'USAGE'
Usage:
  scripts/check-repository.sh [--staged]

Checks repository template files, tracked local artifacts, obvious secrets,
private paths, and review template sections.

Options:
  --staged  Check the Git index. Use this from pre-commit hooks.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --staged)
      staged=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'check-repository: unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$repo_root"

fail() {
  printf 'check-repository: %s\n' "$*" >&2
  exit 1
}

required_files=(
  "AGENTS.md"
  "CLAUDE.md"
  "CONTRIBUTING.md"
  "README.md"
  "SECURITY.md"
  "CHANGELOG.md"
  "docs/README.md"
  ".editorconfig"
  ".gitignore"
  ".github/pull_request_template.md"
  ".github/ISSUE_TEMPLATE/bug_report.md"
  ".github/ISSUE_TEMPLATE/feature_request.md"
  ".github/workflows/review.yml"
  # Alternatives separated by "|": a project replaces the example with its real CI.
  ".github/workflows/ci.yml|.github/workflows/ci.yml.example"
  ".gitlab/merge_request_templates/default.md"
  ".githooks/pre-commit"
  "scripts/check-pr-body.sh"
  "scripts/check-pr-title.sh"
  "scripts/check-repository.sh"
  "scripts/install-git-hooks.sh"
  "scripts/configure-github-repository.sh"
  "scripts/lib/review-sections.sh"
  "specs/0000-template.md"
  "docs/plans/0000-template.md"
)

file_present() {
  if [[ "$staged" == true ]]; then
    git cat-file -e ":$1" 2>/dev/null
  else
    [[ -f "$1" ]]
  fi
}

missing=()
for entry in "${required_files[@]}"; do
  found=false
  IFS='|' read -r -a alternatives <<<"$entry"
  for file in "${alternatives[@]}"; do
    if file_present "$file"; then
      found=true
      break
    fi
  done
  if [[ "$found" == false ]]; then
    missing+=("${entry//|/ or }")
  fi
done

if (( ${#missing[@]} > 0 )); then
  printf 'Missing required template files:\n' >&2
  printf '  - %s\n' "${missing[@]}" >&2
  exit 1
fi

tracked_artifact_pattern='(^|/)(node_modules|dist|build|coverage|tmp|temp|\.cache|\.turbo|\.next|\.vite|\.pytest_cache|__pycache__|\.DS_Store)(/|$)|(^|/)\.env($|\.)|\.log$|(^|/)\.omx(/|$)|(^|/)\.codex(/|$)|(^|/)\.claude/settings\.local\.json$'
if [[ "$staged" == true ]]; then
  tracked_artifacts="$(git diff --cached --name-only --diff-filter=ACMR | grep -E "$tracked_artifact_pattern" || true)"
else
  tracked_artifacts="$(git ls-files | grep -E "$tracked_artifact_pattern" || true)"
fi
if [[ -n "$tracked_artifacts" ]]; then
  printf 'Tracked local, generated, or machine-specific artifacts found:\n%s\n' "$tracked_artifacts" >&2
  exit 1
fi

secret_pattern='AKIA[0-9A-Z]{16}|gh[pousr]_[A-Za-z0-9_]{36,}|xox[baprs]-[A-Za-z0-9-]{10,}|-----BEGIN ([A-Z]+ )?PRIVATE KEY-----'
private_path_pattern='(^|[[:space:]`"'"'"'(<>=])(/Users/[^[:space:]`"'"'"'<>]+|/home/[^[:space:]`"'"'"'<>]+|C:\\Users\\)'
placeholder_pattern='private-token|internal-domain\.example|HOME_PATH_PLACEHOLDER'
findings_file="$(mktemp "${TMPDIR:-/tmp}/check-repository-findings.XXXXXX")"
trap 'rm -f "$findings_file"' EXIT

grep_args=(-n -I -E "$secret_pattern|$private_path_pattern|$placeholder_pattern")
if [[ "$staged" == true ]]; then
  grep_args=(--cached "${grep_args[@]}")
fi

if git grep "${grep_args[@]}" -- . \
  ':!AGENTS.md' \
  ':!CONTRIBUTING.md' \
  ':!SECURITY.md' \
  ':!scripts/check-repository.sh' >"$findings_file"; then
  printf 'Potential secret, private path, or private placeholder found:\n' >&2
  cat "$findings_file" >&2
  exit 1
fi

if [[ "$staged" == true ]]; then
  # Bash 3.2 cannot source process substitution, so eval the staged list.
  eval "$(git show ":scripts/lib/review-sections.sh")"
else
  # shellcheck source=scripts/lib/review-sections.sh
  source "scripts/lib/review-sections.sh"
fi

for template in ".github/pull_request_template.md" ".gitlab/merge_request_templates/default.md"; do
  for section in "${required_review_sections[@]}"; do
    if [[ "$staged" == true ]]; then
      if ! git show ":$template" | grep -E "^## ${section}$" >/dev/null; then
        fail "$template is missing required section: $section"
      fi
    elif ! grep -qE "^## ${section}$" "$template"; then
      fail "$template is missing required section: $section"
    fi
  done
done

if [[ "$staged" == true ]]; then
  printf 'check-repository: ok (staged)\n'
else
  printf 'check-repository: ok\n'
fi
