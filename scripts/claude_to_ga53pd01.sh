#!/bin/bash
# SSH-based script execution on ga53pd01 with direct result retrieval
# This script transfers and executes scripts via SSH synchronously

set -e

# Configuration
REMOTE_HOST="${REMOTE_HOST:-ga53pd01}"
REMOTE_USER="${REMOTE_USER:-henmi}"
PROJECT_NAME="${PROJECT_NAME:-tierivemu}"
ARCHIVE_DIR="workspace/etx_results/.archive"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_debug() {
    if [ "${DEBUG:-0}" = "1" ]; then
        echo -e "${BLUE}[DEBUG]${NC} $1"
    fi
}

# Usage
usage() {
    cat << EOF
Usage: $0 <task_script>

Arguments:
  task_script    Path to the bash script to execute on ga53pd01

Environment Variables:
  REMOTE_HOST    Target host (default: ga53pd01)
  REMOTE_USER    SSH user (default: henmi)
  DEBUG          Enable debug output (default: 0)

Example:
  $0 /tmp/my_task.sh
  DEBUG=1 $0 /tmp/my_task.sh

Features:
  - SSH synchronous execution (fast, real-time output)
  - Local archive in .archive/YYYYMM/
  - No remote files left behind

EOF
}

# Main execution
main() {
    local task_script="$1"

    if [ -z "$task_script" ]; then
        log_error "No task script specified"
        usage
        exit 1
    fi

    if [ ! -f "$task_script" ]; then
        log_error "Task script not found: $task_script"
        exit 1
    fi

    # Generate task ID
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local task_id="${USER}_${timestamp}"
    local task_name=$(basename "$task_script" .sh)

    log_info "=== Running Task on ga53pd01: $task_name ==="
    log_info "Task ID: $task_id"
    log_info "Timestamp: $timestamp"
    log_info "Execution mode: SSH Synchronous (real-time output)"

    # Prepare local archive path
    local archive_month=$(date +%Y%m)
    local archive_path="${ARCHIVE_DIR}/${archive_month}"
    local result_file="${archive_path}/${task_id}_${task_name}_result.txt"

    # Create archive directory
    mkdir -p "$archive_path"

    log_info "Executing script on ${REMOTE_HOST}..."
    log_info "Output will be saved to: $result_file"
    echo ""

    # Execute via SSH and save to archive
    if ssh "${REMOTE_HOST}" "bash -s" < "$task_script" 2>&1 | tee "$result_file"; then
        echo ""
        log_info "=== Task Completed Successfully ==="
        log_info "Result archived: $result_file"

        # Show summary
        local line_count=$(wc -l < "$result_file")
        local file_size=$(du -h "$result_file" | cut -f1)
        log_info "Output: $line_count lines, $file_size"

        return 0
    else
        local exit_code=$?
        echo ""
        log_error "=== Task Failed ==="
        log_error "Exit code: $exit_code"
        log_warn "Partial result saved to: $result_file"
        return $exit_code
    fi
}

# Entry point
if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
    usage
    exit 0
fi

main "$@"
