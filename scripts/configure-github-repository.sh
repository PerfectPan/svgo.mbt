#!/usr/bin/env bash
set -euo pipefail

apply=false
repo=""
branch=""
approvals=1
extra_checks=()

usage() {
  cat <<'USAGE'
Usage:
  scripts/configure-github-repository.sh [--repo OWNER/REPO] [--branch BRANCH]
    [--approvals N] [--check NAME]... [--apply]

Configures GitHub repository defaults that cannot be inherited from template files.

Defaults:
  --repo    inferred from gh repo view
  --branch     inferred from the GitHub default branch when gh is available
  --approvals  1; use 0 for a repository with a single maintainer, who cannot
               approve their own pull requests
  --check      additional required status check (repeatable), such as the
               project's CI job names

Without --apply, this script prints the branch protection payload and does not call GitHub.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply)
      apply=true
      shift
      ;;
    --repo)
      repo="${2:-}"
      shift 2
      ;;
    --branch)
      branch="${2:-}"
      shift 2
      ;;
    --approvals)
      approvals="${2:-}"
      shift 2
      ;;
    --check)
      extra_checks+=("${2:-}")
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'configure-github-repository: unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "$repo" ]]; then
  if ! command -v gh >/dev/null 2>&1; then
    printf 'configure-github-repository: gh is required when --repo is omitted\n' >&2
    exit 1
  fi
  repo="$(gh repo view --json nameWithOwner --jq '.nameWithOwner')"
fi

if [[ ! "$repo" =~ ^[^/]+/[^/]+$ ]]; then
  printf 'configure-github-repository: --repo must use OWNER/REPO format\n' >&2
  exit 1
fi

if [[ -z "$branch" ]]; then
  if command -v gh >/dev/null 2>&1; then
    branch="$(gh repo view "$repo" --json defaultBranchRef --jq '.defaultBranchRef.name')"
  else
    printf 'configure-github-repository: cannot infer default branch without gh; pass --branch explicitly\n' >&2
    exit 1
  fi
fi

if [[ ! "$approvals" =~ ^[0-9]+$ ]]; then
  printf 'configure-github-repository: --approvals must be a non-negative integer\n' >&2
  exit 1
fi
if (( approvals > 0 )); then
  last_push_approval=true
else
  last_push_approval=false
fi

contexts=("repository checks" "conventional PR title" "PR description")
if (( ${#extra_checks[@]} > 0 )); then
  contexts+=("${extra_checks[@]}")
fi
contexts_json=""
for context in "${contexts[@]}"; do
  if [[ -z "$context" || "$context" == *'"'* || "$context" == *\\* ]]; then
    printf 'configure-github-repository: invalid check name: %s\n' "$context" >&2
    exit 1
  fi
  contexts_json+="${contexts_json:+, }\"${context}\""
done

payload="$(cat <<JSON
{
  "required_status_checks": {
    "strict": true,
    "contexts": [${contexts_json}]
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": false,
    "require_last_push_approval": ${last_push_approval},
    "required_approving_review_count": ${approvals}
  },
  "restrictions": null,
  "required_linear_history": true,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "required_conversation_resolution": true
}
JSON
)"

printf 'Repository: %s\n' "$repo"
printf 'Branch: %s\n' "$branch"
printf 'Protection payload:\n%s\n' "$payload"

if [[ "$apply" != true ]]; then
  printf 'Dry run only. Re-run with --apply to update GitHub branch protection.\n'
  exit 0
fi

if ! command -v gh >/dev/null 2>&1; then
  printf 'configure-github-repository: gh is required for --apply\n' >&2
  exit 1
fi

gh api \
  --method PUT \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "repos/${repo}/branches/${branch}/protection" \
  --input - <<<"$payload" >/dev/null

printf 'Branch protection updated for %s:%s\n' "$repo" "$branch"
