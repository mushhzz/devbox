#!/usr/bin/env bash
# Test that the playbook works correctly for macOS.
#
# Three phases:
#   1. Syntax check     — validates all YAML and Jinja2 syntax
#   2. Template render  — forces Darwin facts, renders .zshrc/.gitconfig, catches Jinja2 errors
#   3. Conditional test  — runs --check with Darwin overrides, verifies task routing
#
# Homebrew tasks fail on Linux (brew not installed) — that's expected
# and filtered from the results.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ERRORS=0

cd "$REPO_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

DARWIN_OVERRIDES=(
    -e "ansible_os_family=Darwin"
    -e "ansible_system=Darwin"
    -e "ansible_architecture=arm64"
    -e "ansible_distribution=MacOSX"
    -e "ansible_distribution_major_version=15"
    -e "ansible_distribution_release=15.4"
    -e "ansible_distribution_version=15.4"
)

echo ""
echo "============================================="
echo "  macOS Playbook Compatibility Test"
echo "============================================="
echo ""

# ===========================================
# Phase 1: Syntax check
# ===========================================
echo "--- Phase 1: Syntax check ---"
echo ""

if ansible-playbook playbook.yml --syntax-check 2>&1; then
    echo ""
    echo -e "${GREEN}PASS${NC}: Syntax check"
else
    echo ""
    echo -e "${RED}FAIL${NC}: Syntax check"
    ERRORS=$((ERRORS + 1))
fi

echo ""

# ===========================================
# Phase 2: Template rendering (roles that
# only template files, no package managers)
# ===========================================
echo "--- Phase 2: Template rendering with Darwin overrides ---"
echo ""
echo "Testing: shell, git, terminal roles"
echo ""

TEMPLATE_OUTPUT=$(ansible-playbook playbook.yml --check --diff \
    "${DARWIN_OVERRIDES[@]}" \
    --tags "shell,git,terminal" 2>&1 || true)

echo "$TEMPLATE_OUTPUT"
echo ""

# Check template rendering for Darwin-specific content
if echo "$TEMPLATE_OUTPUT" | grep -q "/opt/homebrew"; then
    echo -e "${GREEN}PASS${NC}: .zshrc rendered with macOS Homebrew PATH"
else
    echo -e "${YELLOW}WARN${NC}: .zshrc may not have macOS Homebrew PATH"
fi

if echo "$TEMPLATE_OUTPUT" | grep -q "/bin/zsh"; then
    echo -e "${GREEN}PASS${NC}: Ghostty config rendered with /bin/zsh"
else
    echo -e "${YELLOW}WARN${NC}: Ghostty config may not have /bin/zsh"
fi

if echo "$TEMPLATE_OUTPUT" | grep -q "gh auth git-credential"; then
    echo -e "${GREEN}PASS${NC}: .gitconfig rendered with gh credential helper"
else
    echo -e "${YELLOW}WARN${NC}: .gitconfig may not have gh credential helper"
fi

# Check for Jinja2 errors (UndefinedError, etc)
if echo "$TEMPLATE_OUTPUT" | grep -qiE "UndefinedError|templating error|fatal.*template"; then
    echo -e "${RED}FAIL${NC}: Jinja2 template errors detected"
    ERRORS=$((ERRORS + 1))
else
    echo -e "${GREEN}PASS${NC}: No Jinja2 template errors"
fi

echo ""

# ===========================================
# Phase 3: Full conditional test
# ===========================================
echo "--- Phase 3: Full conditional test with Darwin overrides ---"
echo ""
echo "Running all roles. Homebrew/cask tasks will fail (brew not"
echo "installed on Linux). Only unexpected failures are flagged."
echo ""

FULL_OUTPUT=$(ansible-playbook playbook.yml --check --diff \
    "${DARWIN_OVERRIDES[@]}" "$@" 2>&1 || true)

echo "$FULL_OUTPUT"
echo ""

# Count results
FATAL_COUNT=$(echo "$FULL_OUTPUT" | grep -c "^fatal:" || true)
CHANGED_COUNT=$(echo "$FULL_OUTPUT" | grep -c "changed:" || true)
SKIPPED_COUNT=$(echo "$FULL_OUTPUT" | grep -c "skipping:" || true)

echo "--- Phase 3 Results ---"
echo "  fatal:    $FATAL_COUNT"
echo "  changed:  $CHANGED_COUNT"  
echo "  skipping: $SKIPPED_COUNT"
echo ""

# Filter out expected Homebrew-related failures
UNEXPECTED_FATALS=$(echo "$FULL_OUTPUT" | grep "^fatal:" | grep -viE "brew|homebrew|cask|xcode" || true)

if [ -z "$UNEXPECTED_FATALS" ]; then
    echo -e "${GREEN}PASS${NC}: No unexpected fatal errors"
else
    echo -e "${RED}FAIL${NC}: Unexpected fatal errors:"
    echo "$UNEXPECTED_FATALS" | sed 's/^/  /'
    ERRORS=$((ERRORS + 1))
fi

echo ""

# ===========================================
# Phase 4: Conditional routing
# ===========================================
echo "--- Phase 4: Conditional routing verification ---"
echo ""

echo "Darwin-specific tasks reached:"
DARWIN_REACHED=$(echo "$FULL_OUTPUT" | grep -E "\[(ok|changed|fatal)\]" | grep -iE "macOS|Darwin|brew|cask|Homebrew|Karabiner|colima|Apple" || true)
if [ -n "$DARWIN_REACHED" ]; then
    echo "$DARWIN_REACHED" | sed 's/^/  /'
    echo ""
    echo -e "${GREEN}PASS${NC}: Darwin tasks are being reached"
else
    echo "  (none found in output)"
    echo ""
    echo -e "${YELLOW}WARN${NC}: Could not confirm Darwin tasks are reached"
    echo "  This is normal if Homebrew tasks failed before reaching other roles."
fi

echo ""

echo "Linux-only tasks correctly skipped:"
LINUX_SKIPPED=$(echo "$FULL_OUTPUT" | grep "skipping:" | grep -iE "dnf|apt|RPM Fusion|Flatpak|keyd|systemd|podman" || true)
if [ -n "$LINUX_SKIPPED" ]; then
    echo "$LINUX_SKIPPED" | sed 's/^/  /'
    echo ""
    echo -e "${GREEN}PASS${NC}: Linux-only tasks are being skipped for Darwin"
else
    echo "  (none found in output)"
    echo ""
    echo -e "${YELLOW}WARN${NC}: Could not confirm Linux tasks are skipped"
    echo "  This is normal if the playbook stopped early due to Homebrew errors."
fi

echo ""
echo "============================================="
if [ $ERRORS -eq 0 ]; then
    echo -e "  ${GREEN}All tests passed!${NC}"
else
    echo -e "  ${RED}$ERRORS error(s) detected${NC}"
fi
echo "============================================="
echo ""
echo "Note: The ONLY reliable way to fully validate macOS"
echo "support is to run on real macOS hardware or a GitHub"
echo "Actions macos runner. This test verifies syntax,"
echo "template rendering, and conditional routing."
echo ""

exit $ERRORS