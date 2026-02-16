# Claude Code → OpenClaw Notification Bridge

Get notified via Telegram when Claude Code on another Mac needs your attention.

```
Remote Mac (Claude Code)
  → Hook fires (Stop / Notification / PermissionRequest)
  → HTTP POST to OpenClaw API (Tailscale / LAN)
  → OpenClaw sends Telegram notification
  → You respond from your phone 📱
```

## What You Get

| Event | Emoji | When |
|-------|-------|------|
| **Stop** | 🛑 | Claude finished and is waiting for input |
| **Notification** | 🔐⏰ | Permission prompt or idle timeout |
| **PermissionRequest** | 🔒 | Claude needs approval for a tool/command |

## Requirements

- macOS with Claude Code installed
- `jq` (`brew install jq`)
- `curl` (built-in on macOS)
- Network access to the OpenClaw instance (Tailscale, LAN, etc.)

## Install

```bash
# 1. Copy files to the remote Mac
scp -r . remote-mac:~/claude-code-hooks/

# 2. SSH in and run the installer
ssh remote-mac
cd ~/claude-code-hooks
chmod +x install.sh uninstall.sh
./install.sh

# 3. (Optional) Edit the config if needed
vim ~/.claude/hooks/config.env

# 4. Restart Claude Code
```

The installer:
- Copies `notify-openclaw.sh` and `config.env` to `~/.claude/hooks/`
- Non-destructively merges hook config into `~/.claude/settings.json`
- Backs up existing settings before any changes

## Configuration

Edit `~/.claude/hooks/config.env`:

```bash
# OpenClaw API URL (Tailscale Funnel, LAN IP, etc.)
OPENCLAW_API_URL="https://your-machine.tail1234.ts.net"

# OpenClaw API token
OPENCLAW_AUTH_TOKEN="your-token-here"
```

## Test

```bash
# Simulate a Stop event
echo '{"hook_event_name":"Stop","cwd":"/Users/you/project","stop_reason":"end_turn","transcript_summary":"Built a REST API with CRUD endpoints"}' | ~/.claude/hooks/notify-openclaw.sh

# Check logs
tail -f ~/.claude-hooks/notify.log
```

## Uninstall

```bash
cd ~/claude-code-hooks
./uninstall.sh
```

Surgically removes only the OpenClaw hooks from settings.json, preserving any other hooks you've configured.

## How It Works

1. Claude Code hooks are configured in `~/.claude/settings.json`
2. When a hook event fires, Claude Code pipes JSON context to the script via stdin
3. The script extracts event type, project name, and relevant details
4. It POSTs a notification to OpenClaw's `/v1/chat/completions` API
5. OpenClaw forwards it to your Telegram
6. Hooks run with `async: true` so they never block Claude Code

## Logs

All activity is logged to `~/.claude-hooks/notify.log` (auto-rotates at 1MB).

## Troubleshooting

**No notifications arriving:**
1. Check logs: `cat ~/.claude-hooks/notify.log`
2. Test the API: `curl -s https://your-openclaw-url/v1/chat/completions -H "Authorization: Bearer your-token" -H "Content-Type: application/json" -d '{"model":"passthrough","messages":[{"role":"user","content":"test"}]}'`
3. Verify config: `cat ~/.claude/hooks/config.env`

**Hooks not firing:**
1. Restart Claude Code (hooks snapshot at startup)
2. Check settings: `jq '.hooks' ~/.claude/settings.json`
3. Run `/hooks` inside Claude Code to verify they're registered

**Permission errors:**
1. Ensure script is executable: `chmod +x ~/.claude/hooks/notify-openclaw.sh`
