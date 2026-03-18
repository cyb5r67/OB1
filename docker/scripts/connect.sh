#!/bin/bash
# Connect Claude Code and Claude Desktop to the local OB1 MCP server
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DOCKER_DIR="$(dirname "$SCRIPT_DIR")"

cd "$DOCKER_DIR"

ACCESS_KEY=$(grep MCP_ACCESS_KEY .env | cut -d= -f2)

# Detect LAN IP for cross-machine access
LAN_IP=$(hostname -I | awk '{print $1}')
MCP_URL="http://${LAN_IP}:3000"

# ── Claude Code ────────────────────────────────────────────────────────────
echo "Connecting Claude Code to OB1..."
claude mcp add --transport http open-brain \
  "${MCP_URL}" \
  --header "x-brain-key: ${ACCESS_KEY}" 2>/dev/null || true

echo "  Done. Restart Claude Code to pick up the connection."

# ── Claude Desktop (via mcp-remote bridge) ─────────────────────────────────
echo ""
echo "Configuring Claude Desktop (via mcp-remote)..."

# Ensure npx / mcp-remote is available
if ! command -v npx &>/dev/null; then
  echo "  [WARN] npx not found — skipping Claude Desktop config."
  echo "  Install Node.js first, then re-run this script."
else
  # Determine claude_desktop_config.json location
  if [ "$(uname -s)" = "Darwin" ]; then
    CONFIG_DIR="$HOME/Library/Application Support/Claude"
  elif grep -qi microsoft /proc/version 2>/dev/null; then
    # WSL — write to Windows-side AppData
    WIN_USER=$(cmd.exe /C "echo %USERNAME%" 2>/dev/null | tr -d '\r')
    CONFIG_DIR="/mnt/c/Users/${WIN_USER}/AppData/Roaming/Claude"
  else
    CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/Claude"
  fi

  CONFIG_FILE="${CONFIG_DIR}/claude_desktop_config.json"
  mkdir -p "$CONFIG_DIR"

  # Build the mcp-remote entry
  MCP_REMOTE_URL="${MCP_URL}?key=${ACCESS_KEY}"

  if [ -f "$CONFIG_FILE" ]; then
    # Merge into existing config using python
    python3 -c "
import json, sys
with open('$CONFIG_FILE') as f:
    cfg = json.load(f)
cfg.setdefault('mcpServers', {})
cfg['mcpServers']['open-brain'] = {
    'command': 'npx',
    'args': ['mcp-remote', '$MCP_REMOTE_URL']
}
with open('$CONFIG_FILE', 'w') as f:
    json.dump(cfg, f, indent=2)
"
  else
    # Create new config
    python3 -c "
import json
cfg = {
    'mcpServers': {
        'open-brain': {
            'command': 'npx',
            'args': ['mcp-remote', '$MCP_REMOTE_URL']
        }
    }
}
with open('$CONFIG_FILE', 'w') as f:
    json.dump(cfg, f, indent=2)
"
  fi

  echo "  Done. Written to: $CONFIG_FILE"
  echo "  Restart Claude Desktop to pick up the connection."
fi

# ── Summary ────────────────────────────────────────────────────────────────
echo ""
echo "Connection details:"
echo "  MCP Server:      ${MCP_URL}"
echo "  Connection URL:  ${MCP_URL}?key=${ACCESS_KEY}"
echo ""
echo "  Claude Code:     connected (restart to activate)"
echo "  Claude Desktop:  configured via mcp-remote (restart to activate)"
