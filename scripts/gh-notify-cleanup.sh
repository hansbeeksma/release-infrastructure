#!/usr/bin/env bash
# gh-notify-cleanup.sh - Clean up GitHub notification noise
# Usage: gh-notify-cleanup.sh [--dry-run] [--max-age 7d] [--reason ci_activity]
set -euo pipefail

# Defaults
DRY_RUN=false
MAX_AGE="7d"
REASON_FILTER="ci_activity"
PRESERVE_REASONS="subscribed,mention,review_requested,assign"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --max-age)
      MAX_AGE="$2"
      shift 2
      ;;
    --reason)
      REASON_FILTER="$2"
      shift 2
      ;;
    --help|-h)
      echo "Usage: gh-notify-cleanup.sh [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --dry-run          Preview which notifications would be marked as read"
      echo "  --max-age DURATION Only process notifications older than DURATION (e.g., 7d, 24h)"
      echo "  --reason REASON    Filter on notification reason (default: ci_activity)"
      echo "  --help             Show this help"
      echo ""
      echo "Preserved reasons (never marked read): ${PRESERVE_REASONS}"
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

# Check gh CLI
if ! command -v gh &>/dev/null; then
  echo "Error: gh CLI not found. Install: https://cli.github.com/" >&2
  exit 1
fi

# Check authentication
if ! gh auth status &>/dev/null 2>&1; then
  echo "Error: Not authenticated. Run: gh auth login" >&2
  exit 1
fi

# Convert max-age to cutoff date
parse_duration() {
  local duration="$1"
  local value="${duration%[dhm]}"
  local unit="${duration: -1}"

  case "$unit" in
    d) echo "$((value * 86400))" ;;
    h) echo "$((value * 3600))" ;;
    m) echo "$((value * 60))" ;;
    *) echo "$((value * 86400))" ;; # default days
  esac
}

SECONDS_AGO=$(parse_duration "$MAX_AGE")
CUTOFF_DATE=$(date -u -v-"${SECONDS_AGO}"S +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || \
  date -u -d "@$(($(date +%s) - SECONDS_AGO))" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null)

echo "=== GitHub Notification Cleanup ==="
echo "Filter reason: ${REASON_FILTER}"
echo "Max age:       ${MAX_AGE} (before ${CUTOFF_DATE})"
echo "Dry run:       ${DRY_RUN}"
echo ""

# Fetch notifications
NOTIFICATIONS=$(gh api notifications --paginate -q '.[] | {id: .id, reason: .reason, updated_at: .updated_at, repo: .repository.full_name, title: .subject.title}' 2>/dev/null || echo "")

if [[ -z "$NOTIFICATIONS" ]]; then
  echo "No unread notifications found."
  exit 0
fi

TOTAL=0
TO_CLEAN=0
PRESERVED=0

while IFS= read -r notification; do
  TOTAL=$((TOTAL + 1))

  reason=$(echo "$notification" | jq -r '.reason')
  updated_at=$(echo "$notification" | jq -r '.updated_at')
  thread_id=$(echo "$notification" | jq -r '.id')
  repo=$(echo "$notification" | jq -r '.repo')
  title=$(echo "$notification" | jq -r '.title')

  # Check if reason should be preserved
  if echo "$PRESERVE_REASONS" | tr ',' '\n' | grep -qx "$reason"; then
    PRESERVED=$((PRESERVED + 1))
    continue
  fi

  # Check reason filter
  if [[ "$reason" != "$REASON_FILTER" ]]; then
    continue
  fi

  # Check age (compare dates)
  if [[ "$updated_at" > "$CUTOFF_DATE" ]]; then
    continue
  fi

  TO_CLEAN=$((TO_CLEAN + 1))

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[DRY-RUN] Would mark as read: ${repo} - ${title} (${reason}, ${updated_at})"
  else
    gh api -X PATCH "notifications/threads/${thread_id}" 2>/dev/null && \
      echo "Marked read: ${repo} - ${title}" || \
      echo "Failed: ${repo} - ${title}" >&2
  fi
done <<< "$(echo "$NOTIFICATIONS" | jq -c '.')"

echo ""
echo "=== Summary ==="
echo "Total notifications: ${TOTAL}"
echo "Preserved (${PRESERVE_REASONS}): ${PRESERVED}"
if [[ "$DRY_RUN" == "true" ]]; then
  echo "Would mark as read: ${TO_CLEAN}"
else
  echo "Marked as read: ${TO_CLEAN}"
fi
