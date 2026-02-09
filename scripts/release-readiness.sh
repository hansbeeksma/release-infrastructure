#!/usr/bin/env bash
# Release Readiness Check Script v1.0.0
# Pre-flight checks voor release kandidaten
#
# Gebruik: release-readiness.sh [--project-dir /path/to/project]
#
# Exit codes:
#   0 = All checks passed (GO)
#   1 = Critical check failed (NO-GO)
#   2 = Warning (soft failures, review needed)

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_DIR="${1:-.}"
PASS=0
FAIL=0
WARN=0

print_header() {
  echo ""
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}  Release Readiness Check${NC}"
  echo -e "${BLUE}  Project: $(basename "$PROJECT_DIR")${NC}"
  echo -e "${BLUE}  Date: $(date +%Y-%m-%d)${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
}

check_pass() {
  echo -e "  ${GREEN}✅ PASS${NC} — $1"
  PASS=$((PASS + 1))
}

check_fail() {
  echo -e "  ${RED}❌ FAIL${NC} — $1"
  FAIL=$((FAIL + 1))
}

check_warn() {
  echo -e "  ${YELLOW}⚠️  WARN${NC} — $1"
  WARN=$((WARN + 1))
}

check_skip() {
  echo -e "  ⏭️  SKIP — $1"
}

# Gate 1: Clean working tree
check_clean_tree() {
  echo -e "\n${BLUE}[1/9] Working Tree${NC}"
  cd "$PROJECT_DIR"
  if [ -z "$(git status --porcelain)" ]; then
    check_pass "Clean working tree"
  else
    check_fail "Uncommitted changes detected"
    git status --short
  fi
}

# Gate 2: Branch check
check_branch() {
  echo -e "\n${BLUE}[2/9] Branch${NC}"
  cd "$PROJECT_DIR"
  local branch
  branch=$(git branch --show-current)
  if [ "$branch" = "main" ] || [ "$branch" = "master" ]; then
    check_pass "On $branch branch"
  else
    check_warn "On branch '$branch' (expected main/master)"
  fi
}

# Gate 3: Remote sync
check_remote_sync() {
  echo -e "\n${BLUE}[3/9] Remote Sync${NC}"
  cd "$PROJECT_DIR"
  git fetch origin 2>/dev/null || { check_warn "Cannot fetch remote"; return; }
  local branch
  branch=$(git branch --show-current)
  local behind
  behind=$(git rev-list HEAD..origin/"$branch" --count 2>/dev/null || echo "0")
  if [ "$behind" -eq 0 ]; then
    check_pass "Up-to-date with remote"
  else
    check_fail "Behind remote by $behind commits"
  fi
}

# Gate 4: Tests
check_tests() {
  echo -e "\n${BLUE}[4/9] Tests${NC}"
  cd "$PROJECT_DIR"
  if [ -f "package.json" ]; then
    local has_test
    has_test=$(node -e "const p=require('./package.json'); console.log(p.scripts?.test ? 'yes' : 'no')" 2>/dev/null || echo "no")
    if [ "$has_test" = "yes" ]; then
      if npm test --silent 2>/dev/null; then
        check_pass "All tests passed"
      else
        check_fail "Tests failed"
      fi
    else
      check_skip "No test script defined"
    fi
  else
    check_skip "No package.json found"
  fi
}

# Gate 5: Build
check_build() {
  echo -e "\n${BLUE}[5/9] Build${NC}"
  cd "$PROJECT_DIR"
  if [ -f "package.json" ]; then
    local has_build
    has_build=$(node -e "const p=require('./package.json'); console.log(p.scripts?.build ? 'yes' : 'no')" 2>/dev/null || echo "no")
    if [ "$has_build" = "yes" ]; then
      if npm run build --silent 2>/dev/null; then
        check_pass "Production build succeeded"
      else
        check_fail "Build failed"
      fi
    else
      check_skip "No build script defined"
    fi
  else
    check_skip "No package.json found"
  fi
}

# Gate 6: Security audit
check_security() {
  echo -e "\n${BLUE}[6/9] Security Audit${NC}"
  cd "$PROJECT_DIR"
  if [ -f "package.json" ]; then
    local audit_result
    audit_result=$(npm audit --audit-level=high 2>&1) || true
    if echo "$audit_result" | grep -q "found 0 vulnerabilities"; then
      check_pass "No high/critical vulnerabilities"
    elif echo "$audit_result" | grep -q "high\|critical"; then
      check_fail "High/critical vulnerabilities found"
    else
      check_warn "Moderate vulnerabilities present"
    fi
  else
    check_skip "No package.json found"
  fi
}

# Gate 7: Gitleaks
check_gitleaks() {
  echo -e "\n${BLUE}[7/9] Secrets Scan${NC}"
  cd "$PROJECT_DIR"
  if command -v gitleaks &>/dev/null; then
    if gitleaks detect --source . --no-git 2>/dev/null; then
      check_pass "No secrets detected"
    else
      check_fail "Potential secrets found"
    fi
  else
    check_skip "gitleaks not installed"
  fi
}

# Gate 8: Lint
check_lint() {
  echo -e "\n${BLUE}[8/9] Lint${NC}"
  cd "$PROJECT_DIR"
  if [ -f "package.json" ]; then
    local has_lint
    has_lint=$(node -e "const p=require('./package.json'); console.log(p.scripts?.lint ? 'yes' : 'no')" 2>/dev/null || echo "no")
    if [ "$has_lint" = "yes" ]; then
      if npm run lint --silent 2>/dev/null; then
        check_pass "No lint errors"
      else
        check_warn "Lint errors found"
      fi
    else
      check_skip "No lint script defined"
    fi
  else
    check_skip "No package.json found"
  fi
}

# Gate 9: Last release info
check_last_release() {
  echo -e "\n${BLUE}[9/9] Release Info${NC}"
  cd "$PROJECT_DIR"
  local last_tag
  last_tag=$(git describe --tags --abbrev=0 2>/dev/null || echo "none")
  if [ "$last_tag" = "none" ]; then
    echo -e "  ℹ️  No previous tags found (first release)"
  else
    local commits_since
    commits_since=$(git rev-list "$last_tag"..HEAD --count)
    echo -e "  ℹ️  Last release: ${last_tag}"
    echo -e "  ℹ️  Commits since: ${commits_since}"
  fi
}

# Summary
print_summary() {
  echo ""
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "  ${GREEN}Passed: $PASS${NC}  ${RED}Failed: $FAIL${NC}  ${YELLOW}Warnings: $WARN${NC}"
  echo ""

  if [ "$FAIL" -gt 0 ]; then
    echo -e "  ${RED}Decision: NO-GO${NC}"
    echo -e "  Fix $FAIL critical issue(s) before releasing."
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    exit 1
  elif [ "$WARN" -gt 0 ]; then
    echo -e "  ${YELLOW}Decision: REVIEW NEEDED${NC}"
    echo -e "  $WARN warning(s) — review before proceeding."
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    exit 2
  else
    echo -e "  ${GREEN}Decision: GO${NC}"
    echo -e "  All checks passed. Ready to release."
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    exit 0
  fi
}

# Parse args
while [[ $# -gt 0 ]]; do
  case $1 in
    --project-dir)
      PROJECT_DIR="$2"
      shift 2
      ;;
    *)
      PROJECT_DIR="$1"
      shift
      ;;
  esac
done

# Run
print_header
check_clean_tree
check_branch
check_remote_sync
check_tests
check_build
check_security
check_gitleaks
check_lint
check_last_release
print_summary
