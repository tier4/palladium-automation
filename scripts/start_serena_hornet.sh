#!/bin/bash
# Serena MCP Launcher for Hornet Project
# Changes to hornet directory before starting Serena MCP

cd /home/khenmi/hornet || exit 1

exec /opt/eda/uv/current/bin/uv run \
  --directory /opt/eda/serena-verilog/current/ \
  serena start-mcp-server \
  --context ide-assistant \
  --project /home/khenmi/hornet \
  --enable-web-dashboard false
