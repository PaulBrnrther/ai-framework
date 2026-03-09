#!/usr/bin/env bash
# Lists non-Copilot comments on the current branch's PR.
# Usage: ./pr-comments.sh [pr-number]
#   If no PR number given, uses the current branch's PR.

set -euo pipefail

PR="${1:-$(gh pr view --json number --jq .number)}"
REPO="$(gh repo view --json nameWithOwner --jq .nameWithOwner)"
BRANCH="$(gh pr view "$PR" --json headRefName --jq .headRefName)"
FILTER='select(.user.login | test("copilot"; "i") | not)'

echo "## Comments"
echo ""

# --- Reviews (top-level verdicts) ---
REVIEWS=$(gh api "repos/${REPO}/pulls/${PR}/reviews" --paginate \
  --jq "[.[] | ${FILTER} | select(.body | length > 0)]")

if [ "$(echo "$REVIEWS" | jq -s 'add | length')" -gt 0 ]; then
  echo "$REVIEWS" | jq -s 'add | .[] | "- @\(.user.login) (\(.state)):\n  > \(.body | gsub("\n"; "\n  > "))\n"'
fi

# --- Inline code review comments ---
INLINE=$(gh api "repos/${REPO}/pulls/${PR}/comments" --paginate \
  --jq "[.[] | ${FILTER}]")

if [ "$(echo "$INLINE" | jq -s 'add | length')" -gt 0 ]; then
  echo "$INLINE" | jq -s 'add | .[] |
    "- @\(.user.login) `\(.path)`#\(.line // .original_line):\n  > \(.body | gsub("\n"; "\n  > "))\n"'
fi

# --- General PR conversation comments ---
GENERAL=$(gh api "repos/${REPO}/issues/${PR}/comments" --paginate \
  --jq "[.[] | ${FILTER}]")

if [ "$(echo "$GENERAL" | jq -s 'add | length')" -gt 0 ]; then
  echo "$GENERAL" | jq -s 'add | .[] | "- @\(.user.login) (\(.created_at)):\n  > \(.body | gsub("\n"; "\n  > "))\n"'
fi

# --- Check if anything was printed ---
TOTAL=$(( $(echo "$REVIEWS" | jq -s 'add | length') + $(echo "$INLINE" | jq -s 'add | length') + $(echo "$GENERAL" | jq -s 'add | length') ))
if [ "$TOTAL" -eq 0 ]; then
  echo "No comments found."
fi
