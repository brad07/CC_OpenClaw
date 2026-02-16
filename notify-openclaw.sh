#!/bin/bash
#
# notify-openclaw.sh
# Claude Code hook → OpenClaw notification bridge
#
# Receives hook JSON on stdin, extracts context, POSTs to OpenClaw API.
# Marked as async:true in hooks config so it doesn't block Claude Code.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.env"
LOG_DIR="${HOME}/.claude-hooks"
LOG_FILE="${LOG_DIR}/notify.log"
MAX_LOG_SIZE=1048576  # 1MB

mkdir -p "${LOG_DIR}"

# Rotate log if too large
if [[ -f "${LOG_FILE}" ]] && [[ $(stat -f%z "${LOG_FILE}" 2>/dev/null || stat -c%s "${LOG_FILE}" 2>/dev/null || echo 0) -gt ${MAX_LOG_SIZE} ]]; then
    mv "${LOG_FILE}" "${LOG_FILE}.old"
fi

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "${LOG_FILE}"
}

# Load config
if [[ ! -f "${CONFIG_FILE}" ]]; then
    log "ERROR: Config file not found: ${CONFIG_FILE}"
    exit 0  # Don't block Claude Code
fi
source "${CONFIG_FILE}"

if [[ -z "${OPENCLAW_API_URL:-}" ]] || [[ -z "${OPENCLAW_AUTH_TOKEN:-}" ]]; then
    log "ERROR: Missing OPENCLAW_API_URL or OPENCLAW_AUTH_TOKEN in config"
    exit 0
fi

# Check deps
if ! command -v jq &>/dev/null; then
    log "ERROR: jq not found"
    exit 0
fi

# Read JSON from stdin
json_input=$(cat)
if [[ -z "$json_input" ]]; then
    log "ERROR: Empty stdin"
    exit 0
fi

# Extract common fields (flat JSON structure from Claude Code)
hook_event=$(echo "$json_input" | jq -r '.hook_event_name // "unknown"')
cwd=$(echo "$json_input" | jq -r '.cwd // ""')
project_name=""
if [[ -n "$cwd" ]]; then
    project_name=$(basename "$cwd")
fi

log "Hook event: ${hook_event} | Project: ${project_name}"

# Build notification message based on event type
message=""

case "$hook_event" in
    Stop)
        # Claude finished responding, waiting for input
        stop_reason=$(echo "$json_input" | jq -r '.stop_reason // "unknown"')
        transcript_summary=$(echo "$json_input" | jq -r '.transcript_summary // ""')
        # Truncate long summaries
        if [[ ${#transcript_summary} -gt 500 ]]; then
            transcript_summary="${transcript_summary:0:500}..."
        fi

        message="🛑 **Claude Code needs you**"
        [[ -n "$project_name" ]] && message+=" [$project_name]"
        message+=$'\n'"Reason: ${stop_reason}"
        [[ -n "$transcript_summary" ]] && message+=$'\n\n'"${transcript_summary}"
        ;;

    Notification)
        notification_type=$(echo "$json_input" | jq -r '.notification_type // "unknown"')
        notification_message=$(echo "$json_input" | jq -r '.message // .title // "No details"')

        case "$notification_type" in
            permission_prompt) icon="🔐" ;;
            idle_prompt)       icon="⏰" ;;
            *)                 icon="🔔" ;;
        esac

        message="${icon} **Claude Code**"
        [[ -n "$project_name" ]] && message+=" [$project_name]"
        message+=$'\n'"${notification_type}: ${notification_message}"
        ;;

    PermissionRequest)
        tool_name=$(echo "$json_input" | jq -r '.tool_name // "unknown"')
        tool_command=$(echo "$json_input" | jq -r '.tool_input.command // .tool_input.file_path // ""')

        message="🔒 **Claude Code needs permission**"
        [[ -n "$project_name" ]] && message+=" [$project_name]"
        message+=$'\n'"Tool: ${tool_name}"
        [[ -n "$tool_command" ]] && message+=$'\n'"→ ${tool_command}"
        ;;

    *)
        # Skip unknown events silently
        log "Skipping unknown event: ${hook_event}"
        exit 0
        ;;
esac

if [[ -z "$message" ]]; then
    log "No message to send"
    exit 0
fi

log "Sending: ${message:0:100}..."

# POST to OpenClaw
escaped_message=$(echo -n "$message" | jq -Rs .)
payload=$(jq -n \
    --argjson msg "$escaped_message" \
    '{
        model: "passthrough",
        messages: [
            {role: "system", content: "You are forwarding a Claude Code notification to the user via Telegram. Relay the following notification concisely — do not add commentary, just pass it through cleanly."},
            {role: "user", content: $msg}
        ]
    }')

http_code=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST \
    "${OPENCLAW_API_URL}/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${OPENCLAW_AUTH_TOKEN}" \
    -d "$payload" \
    --connect-timeout 10 \
    --max-time 30 2>&1) || true

if [[ "$http_code" =~ ^2[0-9][0-9]$ ]]; then
    log "SUCCESS (HTTP $http_code)"
else
    log "FAILED (HTTP $http_code)"
fi

exit 0
