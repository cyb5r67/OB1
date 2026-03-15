#!/bin/bash
# Connect Claude Code to the local OB1 MCP server
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DOCKER_DIR="$(dirname "$SCRIPT_DIR")"

cd "$DOCKER_DIR"

ACCESS_KEY=$(grep MCP_ACCESS_KEY .env | cut -d= -f2)

echo "Connecting Claude Code to OB1..."
claude mcp add --transport http open-brain \
  http://localhost:3000 \
  --header "x-brain-key: ${ACCESS_KEY}"

echo ""
echo "Done. Restart Claude Code to pick up the connection."
echo ""
echo "For Claude Desktop (Windows), add a custom connector:"
echo "  URL: http://localhost:3000?key=${ACCESS_KEY}"
