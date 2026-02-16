# Claude Code Hooks → OpenClaw Notification Bridge

## What We're Building
A lightweight integration that lets Claude Code running on another Mac on the same LAN send notifications to OpenClaw when it has a question, needs permission, or finishes a task. Brad gets notified via Telegram.

## Architecture

### Flow
```
Remote Mac (Claude Code) 
  → Hook fires (Stop, Notification, PermissionRequest)
  → HTTP POST to OpenClaw Mac via Tailscale Funnel (already exposed)
  → OpenClaw sends Telegram notification to Brad
```

### Components to Build
1. **Hook scripts** for the remote Mac's `~/.claude/settings.json`
2. **A small notification relay script** that POSTs to OpenClaw's chat completions API
3. **Setup/install script** for easy deployment on the remote Mac
4. **README** with clear instructions

## Claude Code Hook Events to Capture

### `Stop` (agent finished, needs input)
- Fires when Claude finishes responding and waits for user input
- No matcher support — always fires
- Input includes: `stop_hook_active`, `stop_reason`, `transcript_summary`
- This is the PRIMARY hook — it means "Claude Code needs you"

### `Notification` 
- Fires when Claude Code sends a notification
- Matchers: `permission_prompt`, `idle_prompt`, `auth_success`, `elicitation_dialog`
- We want `permission_prompt` and `idle_prompt`

### `PermissionRequest`
- Fires when a permission dialog appears
- Good to capture so Brad knows Claude Code is waiting for approval

### Hook Config Format
```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "/path/to/notify-openclaw.sh"
          }
        ]
      }
    ],
    "Notification": [
      {
        "matcher": "permission_prompt|idle_prompt",
        "hooks": [
          {
            "type": "command", 
            "command": "/path/to/notify-openclaw.sh"
          }
        ]
      }
    ]
  }
}
```

## OpenClaw API Access
- Tailscale Funnel already exposed at: `https://roons-mac-mini.tail0d0ae1.ts.net`
- Auth token available
- Use `/v1/chat/completions` endpoint with a system message that tells OpenClaw to notify Brad
- Or simpler: just use `curl` to hit the OpenClaw API with a message that gets forwarded to Telegram

## Deliverables
1. `notify-openclaw.sh` — the hook script that reads stdin JSON and POSTs to OpenClaw
2. `install.sh` — setup script for the remote Mac
3. `README.md` — docs
4. Example `.claude/settings.json` hooks config
5. Config file for the remote Mac (OpenClaw URL, token, etc.)

## Constraints
- Shell scripts + curl only (no extra deps beyond jq)
- Must work on macOS
- Should be easy to install on a fresh Mac with Claude Code
- Notifications should include: what project, what happened, any question/context
- Keep it simple and robust
