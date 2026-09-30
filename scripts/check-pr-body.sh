#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/check-pr-body.sh [FILE]
  printf '%s\n' "$PR_BODY" | scripts/check-pr-body.sh

Checks a PR or MR description read from FILE, or from stdin when FILE is
omitted or "-". The description must contain every review template section,
Summary and Validation must contain more than template placeholders, and
agent attribution lines are rejected.
USAGE
}

if [[ $# -gt 1 ]]; then
  usage >&2
  exit 1
fi

case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;
esac

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
# shellcheck source=scripts/lib/review-sections.sh
source "$script_dir/lib/review-sections.sh"

input="${1:--}"
if [[ "$input" == "-" ]]; then
  body="$(cat)"
elif [[ -f "$input" ]]; then
  body="$(cat "$input")"
else
  printf 'check-pr-body: file not found: %s\n' "$input" >&2
  exit 1
fi
# Descriptions edited in the GitHub web UI arrive with CRLF line endings.
body="${body//$'\r'/}"

if [[ -z "${body//[[:space:]]/}" ]]; then
  printf 'check-pr-body: missing PR body\n' >&2
  exit 1
fi

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

# Lines copied unchanged from a review template count as placeholders.
template_lines=""
for template in "$repo_root/.github/pull_request_template.md" "$repo_root/.gitlab/merge_request_templates/default.md"; do
  if [[ -f "$template" ]]; then
    while IFS= read -r line; do
      template_lines+="$(trim "$line")"$'\n'
    done <"$template"
  fi
done

section_lines() {
  awk -v heading="## $1" '
    /^## / { sub(/[[:space:]]+$/, ""); inside = ($0 == heading); next }
    inside { print }
  ' <<<"$body"
}

has_content() {
  local line trimmed
  while IFS= read -r line; do
    trimmed="$(trim "$line")"
    if [[ -z "$trimmed" || "$trimmed" =~ ^[-*]([[:space:]]+\[[[:space:]xX]\])?$ || "$trimmed" =~ ^\<!--.*--\>$ ]]; then
      continue
    fi
    if grep -Fx -- "$trimmed" <<<"$template_lines" >/dev/null; then
      continue
    fi
    return 0
  done < <(section_lines "$1")
  return 1
}

errors=()

for section in "${required_review_sections[@]}"; do
  if ! grep -E "^## ${section}[[:space:]]*$" <<<"$body" >/dev/null; then
    errors+=("missing required section: ## $section")
  fi
done

for section in "Summary" "Validation"; do
  if ! has_content "$section"; then
    errors+=("section has no content beyond template placeholders: ## $section")
  fi
done

attribution_pattern='generated (with|by) .*(claude|codex|copilot|cursor|gpt|(^|[^[:alnum:]])ai([^[:alnum:]]|$))|🤖[[:space:]]*generated'
if attribution_lines="$(grep -inE "$attribution_pattern" <<<"$body")"; then
  errors+=("remove agent attribution lines:")
  while IFS= read -r line; do
    errors+=("  $line")
  done <<<"$attribution_lines"
fi

if (( ${#errors[@]} > 0 )); then
  printf 'check-pr-body: %s\n' "${errors[@]}" >&2
  exit 1
fi

printf 'check-pr-body: ok\n'
