#!/usr/bin/env bash
# DORA Metrics Calculator v1.0.0
# Berekent de 4 DORA metrics uit git history
#
# Gebruik: dora-metrics.sh [--project-dir /path/to/project] [--period 90]
#
# Metrics:
#   1. Deployment Frequency (tags per periode)
#   2. Lead Time for Changes (commit → tag time delta)
#   3. Change Failure Rate (hotfix/revert ratio)
#   4. MTTR (Mean Time To Recovery)

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

PROJECT_DIR="."
PERIOD_DAYS=90

# Parse args
while [[ $# -gt 0 ]]; do
  case $1 in
    --project-dir)
      PROJECT_DIR="$2"
      shift 2
      ;;
    --period)
      PERIOD_DAYS="$2"
      shift 2
      ;;
    *)
      PROJECT_DIR="$1"
      shift
      ;;
  esac
done

cd "$PROJECT_DIR"

PROJECT_NAME=$(basename "$(pwd)")
SINCE_DATE=$(date -v-"${PERIOD_DAYS}"d +%Y-%m-%d 2>/dev/null || date -d "${PERIOD_DAYS} days ago" +%Y-%m-%d 2>/dev/null || echo "unknown")

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  DORA Metrics Report${NC}"
echo -e "${BLUE}  Project: ${PROJECT_NAME}${NC}"
echo -e "${BLUE}  Period: ${PERIOD_DAYS} days (since ${SINCE_DATE})${NC}"
echo -e "${BLUE}  Date: $(date +%Y-%m-%d)${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# --- Metric 1: Deployment Frequency ---
echo -e "\n${CYAN}[1/4] Deployment Frequency${NC}"

TOTAL_TAGS=$(git tag --sort=-creatordate | head -100 | wc -l | tr -d ' ')
RECENT_TAGS=$(git tag --sort=-creatordate --format='%(creatordate:short)' 2>/dev/null | while read -r date; do
  if [[ "$date" > "$SINCE_DATE" ]] || [[ "$date" == "$SINCE_DATE" ]]; then
    echo "$date"
  fi
done | wc -l | tr -d ' ')

WEEKS=$((PERIOD_DAYS / 7))
if [ "$WEEKS" -eq 0 ]; then WEEKS=1; fi

if [ "$RECENT_TAGS" -gt 0 ]; then
  FREQ_PER_WEEK=$(echo "scale=1; $RECENT_TAGS / $WEEKS" | bc 2>/dev/null || echo "N/A")

  if [ "$RECENT_TAGS" -ge "$((WEEKS * 5))" ]; then
    FREQ_RATING="ELITE"
    FREQ_COLOR="$GREEN"
  elif [ "$RECENT_TAGS" -ge "$WEEKS" ]; then
    FREQ_RATING="HIGH"
    FREQ_COLOR="$GREEN"
  elif [ "$RECENT_TAGS" -ge 1 ]; then
    FREQ_RATING="MEDIUM"
    FREQ_COLOR="$YELLOW"
  else
    FREQ_RATING="LOW"
    FREQ_COLOR="$RED"
  fi

  echo -e "  Releases in period: ${RECENT_TAGS}"
  echo -e "  Frequency: ${FREQ_PER_WEEK}/week"
  echo -e "  Rating: ${FREQ_COLOR}${FREQ_RATING}${NC}"
else
  FREQ_RATING="LOW"
  FREQ_COLOR="$RED"
  echo -e "  No releases in period"
  echo -e "  Rating: ${FREQ_COLOR}${FREQ_RATING}${NC}"
fi

# --- Metric 2: Lead Time for Changes ---
echo -e "\n${CYAN}[2/4] Lead Time for Changes${NC}"

LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
if [ -n "$LAST_TAG" ]; then
  TAG_DATE=$(git log -1 --format=%ct "$LAST_TAG" 2>/dev/null || echo "0")

  # Get average time between commits and their eventual tag
  TOTAL_LEAD=0
  COMMIT_COUNT=0

  PREV_TAG=""
  for tag in $(git tag --sort=creatordate | tail -5); do
    if [ -n "$PREV_TAG" ]; then
      TAG_TIMESTAMP=$(git log -1 --format=%ct "$tag" 2>/dev/null || echo "0")

      while IFS= read -r commit_ts; do
        if [ -n "$commit_ts" ] && [ "$commit_ts" -gt 0 ] && [ "$TAG_TIMESTAMP" -gt 0 ]; then
          DELTA=$((TAG_TIMESTAMP - commit_ts))
          if [ "$DELTA" -ge 0 ]; then
            TOTAL_LEAD=$((TOTAL_LEAD + DELTA))
            ((COMMIT_COUNT++))
          fi
        fi
      done < <(git log "$PREV_TAG".."$tag" --format=%ct 2>/dev/null)
    fi
    PREV_TAG="$tag"
  done

  if [ "$COMMIT_COUNT" -gt 0 ]; then
    AVG_LEAD=$((TOTAL_LEAD / COMMIT_COUNT))
    AVG_HOURS=$((AVG_LEAD / 3600))
    AVG_DAYS=$((AVG_HOURS / 24))

    if [ "$AVG_HOURS" -lt 24 ]; then
      LEAD_DISPLAY="${AVG_HOURS} hours"
      LEAD_RATING="ELITE"
      LEAD_COLOR="$GREEN"
    elif [ "$AVG_DAYS" -lt 7 ]; then
      LEAD_DISPLAY="${AVG_DAYS} days"
      LEAD_RATING="HIGH"
      LEAD_COLOR="$GREEN"
    elif [ "$AVG_DAYS" -lt 30 ]; then
      LEAD_DISPLAY="${AVG_DAYS} days"
      LEAD_RATING="MEDIUM"
      LEAD_COLOR="$YELLOW"
    else
      LEAD_DISPLAY="${AVG_DAYS} days"
      LEAD_RATING="LOW"
      LEAD_COLOR="$RED"
    fi

    echo -e "  Average lead time: ${LEAD_DISPLAY}"
    echo -e "  Commits analyzed: ${COMMIT_COUNT}"
    echo -e "  Rating: ${LEAD_COLOR}${LEAD_RATING}${NC}"
  else
    LEAD_RATING="N/A"
    echo -e "  Insufficient data (need ≥2 tags)"
  fi
else
  LEAD_RATING="N/A"
  echo -e "  No tags found — cannot calculate lead time"
fi

# --- Metric 3: Change Failure Rate ---
echo -e "\n${CYAN}[3/4] Change Failure Rate${NC}"

TOTAL_COMMITS=$(git rev-list --count HEAD --since="$SINCE_DATE" 2>/dev/null || echo "0")
HOTFIX_COMMITS=$(git log --oneline --since="$SINCE_DATE" | { grep -ciE "hotfix|revert|rollback|fix!:" || true; })

if [ "$TOTAL_COMMITS" -gt 0 ]; then
  CFR=$(echo "scale=1; $HOTFIX_COMMITS * 100 / $TOTAL_COMMITS" | bc 2>/dev/null || echo "0")

  CFR_INT=${CFR%.*}
  if [ "${CFR_INT:-0}" -le 15 ]; then
    CFR_RATING="ELITE"
    CFR_COLOR="$GREEN"
  elif [ "${CFR_INT:-0}" -le 30 ]; then
    CFR_RATING="HIGH"
    CFR_COLOR="$GREEN"
  elif [ "${CFR_INT:-0}" -le 45 ]; then
    CFR_RATING="MEDIUM"
    CFR_COLOR="$YELLOW"
  else
    CFR_RATING="LOW"
    CFR_COLOR="$RED"
  fi

  echo -e "  Total commits: ${TOTAL_COMMITS}"
  echo -e "  Hotfix/revert commits: ${HOTFIX_COMMITS}"
  echo -e "  Failure rate: ${CFR}%"
  echo -e "  Rating: ${CFR_COLOR}${CFR_RATING}${NC}"
else
  CFR_RATING="N/A"
  echo -e "  No commits in period"
fi

# --- Metric 4: MTTR ---
echo -e "\n${CYAN}[4/4] Mean Time To Recovery (MTTR)${NC}"

# MTTR wordt berekend uit hotfix branches: aanmaak → merge time
HOTFIX_BRANCHES=$(git branch -r --merged 2>/dev/null | { grep -c "hotfix/" || true; })
if [ "$HOTFIX_BRANCHES" -gt 0 ]; then
  echo -e "  Hotfix branches merged: ${HOTFIX_BRANCHES}"
  echo -e "  (Detailed MTTR requires CI/deployment timestamps)"
  MTTR_RATING="N/A"
else
  echo -e "  No hotfix branches detected"
  echo -e "  MTTR: N/A (no incidents in period)"
  MTTR_RATING="N/A"
fi

# --- Summary ---
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Summary${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
printf "  %-30s %s\n" "Deployment Frequency:" "${FREQ_RATING}"
printf "  %-30s %s\n" "Lead Time for Changes:" "${LEAD_RATING:-N/A}"
printf "  %-30s %s\n" "Change Failure Rate:" "${CFR_RATING:-N/A}"
printf "  %-30s %s\n" "MTTR:" "${MTTR_RATING}"
echo ""

# Overall rating
SCORES=0
SCORE_COUNT=0
for rating in "$FREQ_RATING" "${LEAD_RATING:-N/A}" "${CFR_RATING:-N/A}" "$MTTR_RATING"; do
  case "$rating" in
    ELITE) SCORES=$((SCORES + 4)); ((SCORE_COUNT++)) ;;
    HIGH) SCORES=$((SCORES + 3)); ((SCORE_COUNT++)) ;;
    MEDIUM) SCORES=$((SCORES + 2)); ((SCORE_COUNT++)) ;;
    LOW) SCORES=$((SCORES + 1)); ((SCORE_COUNT++)) ;;
  esac
done

if [ "$SCORE_COUNT" -gt 0 ]; then
  AVG_SCORE=$((SCORES / SCORE_COUNT))
  case "$AVG_SCORE" in
    4) OVERALL="ELITE"; OVERALL_COLOR="$GREEN" ;;
    3) OVERALL="HIGH"; OVERALL_COLOR="$GREEN" ;;
    2) OVERALL="MEDIUM"; OVERALL_COLOR="$YELLOW" ;;
    *) OVERALL="LOW"; OVERALL_COLOR="$RED" ;;
  esac
  echo -e "  Overall: ${OVERALL_COLOR}${OVERALL}${NC}"
else
  echo -e "  Overall: Insufficient data"
fi

echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
