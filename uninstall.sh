#!/bin/bash
#
# uninstall.sh — Remove OpenClaw notification hooks from Claude Code
#

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

CLAUDE_DIR="${HOME}/.claude"
HOOKS_DIR="${CLAUDE_DIR}/hooks"
SETTINGS_FILE="${CLAUDE_DIR}/settings.json"

echo -e "${BLUE}=== Uninstall OpenClaw Notification Hooks ===${NC}\n"

if [[ ! -f "${SETTINGS_FILE}" ]]; then
    echo -e "${YELLOW}No settings.json found — nothing to do${NC}"
    exit 0
fi

# Backup
BACKUP="${SETTINGS_FILE}.pre-uninstall-$(date +%s)"
cp "${SETTINGS_FILE}" "$BACKUP"
echo -e "${GREEN}✓ Backed up settings.json → $(basename $BACKUP)${NC}"

# Remove hooks that reference notify-openclaw.sh
jq '
  def remove_openclaw_hooks:
    if . == null then null
    else [.[] | select(.hooks | all(.command | test("notify-openclaw") | not))]
    end |
    if . == [] then empty else . end;

  .hooks.Stop |= remove_openclaw_hooks |
  .hooks.Notification |= remove_openclaw_hooks |
  .hooks.PermissionRequest |= remove_openclaw_hooks |

  # Clean up empty arrays
  if .hooks.Stop == null then del(.hooks.Stop) else . end |
  if .hooks.Notification == null then del(.hooks.Notification) else . end |
  if .hooks.PermissionRequest == null then del(.hooks.PermissionRequest) else . end |

  # Clean up empty hooks object
  if (.hooks | length) == 0 then del(.hooks) else . end
' "${SETTINGS_FILE}" > "${SETTINGS_FILE}.tmp" && mv "${SETTINGS_FILE}.tmp" "${SETTINGS_FILE}"

echo -e "${GREEN}✓ Removed OpenClaw hooks from settings.json${NC}"

# Ask about files
echo ""
read -p "Remove hook script and config from ${HOOKS_DIR}? [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -f "${HOOKS_DIR}/notify-openclaw.sh"
    rm -f "${HOOKS_DIR}/config.env"
    rm -f "${HOOKS_DIR}/config.env.bak"
    echo -e "${GREEN}✓ Removed hook files${NC}"
fi

read -p "Remove logs at ~/.claude-hooks/? [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -rf "${HOME}/.claude-hooks"
    echo -e "${GREEN}✓ Removed logs${NC}"
fi

echo -e "\n${GREEN}Done!${NC} Restart Claude Code for changes to take effect."
