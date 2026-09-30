# shellcheck shell=bash
# Sourced by check-repository.sh and check-pr-body.sh. This is the single list
# of `## ` headings that the PR/MR templates and every PR/MR description must
# contain; update the templates in the same change.
required_review_sections=(
  "Summary"
  "Motivation"
  "Implementation Notes"
  "Validation"
  "Evidence"
  "Safety Checklist"
  "Follow-up Risks"
)
