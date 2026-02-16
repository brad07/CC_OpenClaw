#!/bin/bash
#
# install.sh — Install Claude Code hooks for OpenClaw notifications
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
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}=== Claude Code → OpenClaw Notification Bridge ===${NC}\n"

# Prerequisites
echo "Checking prerequisites..."

if ! command -v jq &>/dev/null; then
    echo -e "${RED}✗ jq not found. Install: brew install jq${NC}"
    exit 1
fi
echo -e "${GREEN}✓ jq${NC}"

if ! command -v curl &>/dev/null; then
    echo -e "${RED}✗ curl not found${NC}"
    exit 1
fi
echo -e "${GREEN}✓ curl${NC}"

# Create dirs
mkdir -p "${HOOKS_DIR}"
mkdir -p "${HOME}/.claude-hooks"

# Copy files
echo -e "\nInstalling files..."
cp "${SCRIPT_DIR}/notify-openclaw.sh" "${HOOKS_DIR}/notify-openclaw.sh"
chmod +x "${HOOKS_DIR}/notify-openclaw.sh"
echo -e "${GREEN}✓ notify-openclaw.sh → ${HOOKS_DIR}/${NC}"

if [[ -f "${HOOKS_DIR}/config.env" ]]; then
    echo -e "${YELLOW}⚠ config.env exists — keeping existing (backup at config.env.bak)${NC}"
    cp "${HOOKS_DIR}/config.env" "${HOOKS_DIR}/config.env.bak"
else
    cp "${SCRIPT_DIR}/config.env" "${HOOKS_DIR}/config.env"
    echo -e "${GREEN}✓ config.env → ${HOOKS_DIR}/${NC}"
fi

# Merge hooks into settings.json
echo -e "\nConfiguring Claude Code hooks..."

if [[ ! -f "${SETTINGS_FILE}" ]]; then
    echo '{}' > "${SETTINGS_FILE}"
    echo -e "${YELLOW}⚠ Created new settings.json${NC}"
fi

# Backup
cp "${SETTINGS_FILE}" "${SETTINGS_FILE}.pre-openclaw-hooks"
echo -e "${GREEN}✓ Backed up settings.json${NC}"

HOOK_PATH="${HOOKS_DIR}/notify-openclaw.sh"

# Merge hooks non-destructively using jq
# Uses async:true so hooks run in background without blocking Claude Code
jq --arg cmd "$HOOK_PATH" '
  # Ensure .hooks exists
  .hooks //= {} |

  # Add Stop hook (no matcher support)
  .hooks.Stop = (.hooks.Stop // []) + [{
    "hooks": [{
      "type": "command",
      "command": $cmd,
      "async": true
    }]
  }] |

  # Add Notification hook for permission_prompt and idle_prompt
  .hooks.Notification = (.hooks.Notification // []) + [{
    "matcher": "permission_prompt|idle_prompt",
    "hooks": [{
      "type": "command",
      "command": $cmd,
      "async": true
    }]
  }] |

  # Add PermissionRequest hook
  .hooks.PermissionRequest = (.hooks.PermissionRequest // []) + [{
    "hooks": [{
      "type": "command",
      "command": $cmd,
      "async": true
    }]
  }]
' "${SETTINGS_FILE}.pre-openclaw-hooks" > "${SETTINGS_FILE}"

# Validate
if jq empty "${SETTINGS_FILE}" 2>/dev/null; then
    echo -e "${GREEN}✓ settings.json is valid${NC}"
else
    echo -e "${RED}✗ settings.json is invalid! Restoring backup...${NC}"
    mv "${SETTINGS_FILE}.pre-openclaw-hooks" "${SETTINGS_FILE}"
    exit 1
fi

# Summary
echo -e "\n${GREEN}=== Installed! ===${NC}\n"
echo "Hook events configured:"
echo "  🛑 Stop — Claude finished, needs input"
echo "  🔔 Notification — permission prompts, idle prompts"
echo "  🔒 PermissionRequest — tool approval needed"
echo ""
echo "Files:"
echo "  Script: ${HOOKS_DIR}/notify-openclaw.sh"
echo "  Config: ${HOOKS_DIR}/config.env"
echo "  Logs:   ~/.claude-hooks/notify.log"
echo ""
echo -e "${YELLOW}Next:${NC}"
echo "  1. Edit ${HOOKS_DIR}/config.env if you need to change the API URL/token"
echo "  2. Restart Claude Code for hooks to take effect"
echo "  3. Test: echo '{\"hook_event_name\":\"Stop\",\"cwd\":\"/tmp/test\",\"stop_reason\":\"end_turn\"}' | ${HOOKS_DIR}/notify-openclaw.sh"
