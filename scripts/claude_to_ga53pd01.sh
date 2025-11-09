#!/bin/bash
# SSH-based script execution on ga53pd01 with direct result retrieval
# This script transfers and executes scripts via SSH synchronously

set -e

# Load environment variables from .env if it exists
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${PROJECT_ROOT}/.env"

if [ -f "${ENV_FILE}" ]; then
    # Source .env file, ignoring comments and empty lines
    set -a
    source <(grep -v '^#' "${ENV_FILE}" | grep -v '^$')
    set +a
fi

# Configuration with defaults
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

# Check local hornet Git status
check_local_hornet_git() {
    local hornet_path="${PROJECT_ROOT}/hornet"

    if [ ! -d "${hornet_path}/.git" ]; then
        log_warn "Local hornet is not a git repository: ${hornet_path}"
        return 1
    fi

    log_info "Checking local hornet Git status..."
    cd "${hornet_path}"

    # Check for uncommitted changes
    if [ -n "$(git status --porcelain)" ]; then
        log_error "Local hornet has uncommitted changes!"
        git status --short
        log_error "Please commit or stash your changes before running on ga53pd01"
        return 1
    fi

    # Check for unpushed commits
    git fetch origin --quiet 2>/dev/null || true
    local local_commit=$(git rev-parse HEAD)
    local remote_commit=$(git rev-parse @{u} 2>/dev/null)

    if [ -z "$remote_commit" ]; then
        log_warn "Local hornet branch has no upstream configured"
    elif [ "$local_commit" != "$remote_commit" ]; then
        log_error "Local hornet has unpushed commits!"
        log_error "Local:  $local_commit"
        log_error "Remote: $remote_commit"
        log_error "Please push your commits before running on ga53pd01"
        return 1
    fi

    # Store local Git info for later comparison
    LOCAL_BRANCH=$(git branch --show-current)
    LOCAL_COMMIT=$(git rev-parse HEAD)

    log_info "Local hornet: branch=${LOCAL_BRANCH}, commit=${LOCAL_COMMIT:0:8}"

    cd - > /dev/null
    return 0
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

    # Check local hornet Git status
    if ! check_local_hornet_git; then
        log_error "Local hornet Git check failed. Aborting."
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

    log_info "Syncing remote hornet on ${REMOTE_HOST}..."

    # Sync remote hornet and get Git info
    local remote_git_info=$(ssh "${REMOTE_HOST}" 'bash -s' <<'SYNC_SCRIPT'
HORNET_DIR="/proj/tierivemu/work/${USER}/hornet"

if [ -d "${HORNET_DIR}/.git" ]; then
    cd "${HORNET_DIR}"

    # Pull latest changes
    echo "INFO: Pulling latest changes..."
    if git pull --quiet 2>&1; then
        echo "INFO: Git pull successful"
    else
        echo "ERROR: Git pull failed"
        exit 1
    fi

    # Output Git info for local comparison
    echo "REMOTE_BRANCH=$(git branch --show-current)"
    echo "REMOTE_COMMIT=$(git rev-parse HEAD)"
else
    echo "ERROR: Remote hornet is not a git repository: ${HORNET_DIR}"
    exit 1
fi
SYNC_SCRIPT
)

    local sync_exit_code=$?
    if [ $sync_exit_code -ne 0 ]; then
        log_error "Failed to sync remote hornet"
        echo "$remote_git_info"
        exit 1
    fi

    # Parse remote Git info
    eval "$remote_git_info"
    log_info "Remote hornet: branch=${REMOTE_BRANCH}, commit=${REMOTE_COMMIT:0:8}"

    # Compare local and remote Git info
    if [ "$LOCAL_BRANCH" != "$REMOTE_BRANCH" ]; then
        log_error "Branch mismatch!"
        log_error "  Local:  $LOCAL_BRANCH"
        log_error "  Remote: $REMOTE_BRANCH"
        exit 1
    fi

    if [ "$LOCAL_COMMIT" != "$REMOTE_COMMIT" ]; then
        log_error "Commit mismatch!"
        log_error "  Local:  $LOCAL_COMMIT"
        log_error "  Remote: $REMOTE_COMMIT"
        exit 1
    fi

    log_info "✓ Local and remote hornet are in sync"
    echo ""

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
