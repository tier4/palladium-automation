#!/bin/bash
# Serena MCP Launcher for Hornet Project
# Changes to hornet directory before starting Serena MCP

set -e

# Load environment variables from .env if it exists
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${PROJECT_ROOT}/.env"

if [ -f "${ENV_FILE}" ]; then
    set -a
    source <(grep -v '^#' "${ENV_FILE}" | grep -v '^$')
    set +a
fi

# Auto-detect HORNET_PATH if not set
if [ -z "${HORNET_PATH}" ]; then
    HORNET_PATH="${PROJECT_ROOT}/hornet"
fi

# Verify hornet directory exists
if [ ! -d "${HORNET_PATH}" ]; then
    echo "ERROR: Hornet directory not found at ${HORNET_PATH}" >&2
    echo "Please clone hornet: git clone https://github.com/tier4/hornet.git" >&2
    exit 1
fi

cd "${HORNET_PATH}" || exit 1

exec /opt/eda/uv/current/bin/uv run \
  --directory /opt/eda/serena-verilog/current/ \
  serena start-mcp-server \
  --context ide-assistant \
  --project "${HORNET_PATH}" \
  --enable-web-dashboard false
