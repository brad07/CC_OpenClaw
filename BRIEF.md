# Claude Code Hooks → OpenClaw Notification Bridge

## What We're Building
A lightweight integration that lets Claude Code running on another Mac on the same LAN send notifications to OpenClaw when it has a question or needs user input. The user (Brad) gets notified via Telegram so he can respond without being at the other machine.

## Architecture

### Components
1. **Hook scripts** — Installed on the remote Mac where Claude Code runs. These are Claude Code hooks (see `.claude/settings.json` hooks config) that fire when Claude Code needs input/asks a question.
2. **Notification endpoint** — Uses OpenClaw's existing HTTP API on this Mac (the one running OpenClaw on port 18789) to send a message to Brad via Telegram.

### Flow
```
Remote Mac (Claude Code) 
  → Hook fires (question/input needed)
  → HTTP POST to OpenClaw Mac's API (same LAN)
  → OpenClaw sends Telegram notification to Brad
  → Brad can respond via Telegram
```

### Key Details
- Both Macs are on the same local network
- OpenClaw runs on this Mac (roon's Mac mini) at port 18789, currently bound to loopback
- OpenClaw has an HTTP API with chat completions endpoint enabled
- OpenClaw auth token is used for API auth
- Claude Code hooks config lives in `.claude/settings.json` on the remote Mac

## Requirements
1. Hook scripts that detect when Claude Code asks a question / needs input
2. A simple HTTP client script that sends the notification to OpenClaw
3. Clear setup instructions for installing on the remote Mac
4. The notification should arrive in Brad's Telegram with context (what project, what question)
5. Ideally Brad can reply via Telegram and the response gets back to Claude Code (stretch goal)

## Claude Code Hooks Reference
Claude Code supports hooks in `.claude/settings.json`:
- `PreToolUse` — before tool execution
- `PostToolUse` — after tool execution  
- `Notification` — when Claude Code wants to notify the user (THIS IS THE KEY ONE)
- `Stop` — when the agent stops and needs input

The `Notification` and `Stop` hooks are the most relevant — they fire when Claude Code has a question or finishes a task.

## OpenClaw API
- Endpoint: `POST http://<openclaw-ip>:18789/v1/chat/completions`
- Auth: `Authorization: Bearer <token>`
- Or use system events: `openclaw system event --text "..." --mode now`

## Constraints
- Keep it simple — shell scripts + minimal deps
- Must work on macOS
- Should be easy to install on a fresh Mac with Claude Code
- Include a setup/install script
