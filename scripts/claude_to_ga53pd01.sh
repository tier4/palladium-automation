#!/bin/bash
# SSH-based script execution on ga53pd01 with GitHub result collection
# This script transfers task scripts via SCP and executes them via SSH

set -e

# Configuration
REMOTE_HOST="${REMOTE_HOST:-ga53pd01}"
REMOTE_USER="${REMOTE_USER:-henmi}"
PROJECT_NAME="${PROJECT_NAME:-tierivemu}"
SHARED_DIR="${SHARED_DIR:-/proj/${PROJECT_NAME}/work/${REMOTE_USER}/etx_tmp}"  # NFS shared directory
REMOTE_WORKDIR="$HOME/palladium-automation"
GITHUB_REPO="tier4/palladium-automation"
GITHUB_POLL_TIMEOUT="${GITHUB_POLL_TIMEOUT:-1800}"  # 30 minutes default
GITHUB_POLL_INTERVAL="${GITHUB_POLL_INTERVAL:-10}"
SAVE_RESULTS_LOCALLY="${SAVE_RESULTS_LOCALLY:-1}"

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
  REMOTE_HOST              Target host (default: ga53pd01)
  REMOTE_USER              SSH user (default: henmi)
  GITHUB_POLL_TIMEOUT      Result polling timeout in seconds (default: 1800)
  GITHUB_POLL_INTERVAL     Polling interval in seconds (default: 10)
  SAVE_RESULTS_LOCALLY     Save results locally (default: 1)
  DEBUG                    Enable debug output (default: 0)

Example:
  $0 /tmp/my_task.sh
  GITHUB_POLL_TIMEOUT=3600 $0 /tmp/long_task.sh

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

    log_info "=== Running Claude Code Task: $task_name ==="
    log_info "Task ID: $task_id"
    log_info "Timestamp: $timestamp"

    # Prepare shared paths (NFS mounted on both ut01 and pd01)
    local shared_task_script="${SHARED_DIR}/task_${timestamp}.sh"
    local shared_wrapper_script="${SHARED_DIR}/wrapper_${timestamp}.sh"
    local result_file="${task_name}_result.txt"

    # Prepare remote execution paths (same path on pd01)
    local remote_task_script="${shared_task_script}"
    local remote_wrapper_script="${shared_wrapper_script}"

    # Create wrapper script locally
    local local_wrapper="/tmp/wrapper_${timestamp}.sh"
    log_info "Creating wrapper script with GitHub integration..."

    cat > "$local_wrapper" << 'EOF_WRAPPER'
#!/bin/bash
# Auto-generated wrapper script for GitHub result collection

TASK_SCRIPT="__REMOTE_TASK_SCRIPT__"
RESULT_FILE="__RESULT_FILE__"
GITHUB_REPO="__GITHUB_REPO__"
TASK_ID="__TASK_ID__"
RESULT_PATH="$HOME/.etx_tmp/${RESULT_FILE}"
REPO_DIR="$HOME/.etx_tmp/etx_results"

echo "=== Wrapper Script Started ===" | tee "${RESULT_PATH}"
echo "Date: $(date)" | tee -a "${RESULT_PATH}"
echo "Hostname: $(hostname)" | tee -a "${RESULT_PATH}"
echo "User: $(whoami)" | tee -a "${RESULT_PATH}"
echo "Task ID: ${TASK_ID}" | tee -a "${RESULT_PATH}"
echo "Task Script: ${TASK_SCRIPT}" | tee -a "${RESULT_PATH}"
echo "" | tee -a "${RESULT_PATH}"

# Execute task
echo "=== Task Start: $(date) ===" | tee -a "${RESULT_PATH}"
if bash "${TASK_SCRIPT}" >> "${RESULT_PATH}" 2>&1; then
    echo "=== Task End: $(date) ===" | tee -a "${RESULT_PATH}"
    echo "Status: SUCCESS" | tee -a "${RESULT_PATH}"
    EXIT_CODE=0
else
    EXIT_CODE=$?
    echo "=== Task End: $(date) ===" | tee -a "${RESULT_PATH}"
    echo "Status: FAILED (exit code: ${EXIT_CODE})" | tee -a "${RESULT_PATH}"
fi
echo "" | tee -a "${RESULT_PATH}"

# Git configuration check
echo "=== Checking Git Configuration ===" | tee -a "${RESULT_PATH}"
if ! git config --global user.name >/dev/null 2>&1; then
    echo "Setting default git user.name..." | tee -a "${RESULT_PATH}"
    git config --global user.name "ETX Automation"
fi

if ! git config --global user.email >/dev/null 2>&1; then
    echo "Setting default git user.email..." | tee -a "${RESULT_PATH}"
    git config --global user.email "etx@automation.local"
fi

# Upload results to GitHub
echo "=== Uploading results to GitHub ===" | tee -a "${RESULT_PATH}"
cd "$HOME/.etx_tmp" || {
    echo "ERROR: Cannot change to .etx_tmp directory" | tee -a "${RESULT_PATH}"
    exit 1
}

# Prepare repository
if [ -d "${REPO_DIR}/.git" ]; then
    echo "Repository exists, updating..." | tee -a "${RESULT_PATH}"
    cd "${REPO_DIR}"

    if ! git remote get-url origin >/dev/null 2>&1; then
        echo "WARNING: Git remote not configured, re-cloning..." | tee -a "${RESULT_PATH}"
        cd ..
        rm -rf etx_results
        git clone "https://github.com/${GITHUB_REPO}.git" etx_results >> "${RESULT_PATH}" 2>&1
        cd etx_results
    else
        if ! git pull --rebase origin main >> "${RESULT_PATH}" 2>&1; then
            echo "WARNING: git pull failed, re-cloning..." | tee -a "${RESULT_PATH}"
            cd ..
            rm -rf etx_results
            git clone "https://github.com/${GITHUB_REPO}.git" etx_results >> "${RESULT_PATH}" 2>&1
            cd etx_results
        fi
    fi
else
    echo "Cloning repository for the first time..." | tee -a "${RESULT_PATH}"
    if ! git clone "https://github.com/${GITHUB_REPO}.git" etx_results >> "${RESULT_PATH}" 2>&1; then
        echo "ERROR: Failed to clone repository" | tee -a "${RESULT_PATH}"
        echo "Please check GitHub authentication and network" | tee -a "${RESULT_PATH}"
        exit 1
    fi
    cd etx_results
fi

# Create task ID directory
mkdir -p "workspace/etx_results/results/${TASK_ID}"

# Copy result file
if ! cp "${RESULT_PATH}" "workspace/etx_results/results/${TASK_ID}/"; then
    echo "ERROR: Failed to copy result file" | tee -a "${RESULT_PATH}"
    exit 1
fi

git add "workspace/etx_results/results/${TASK_ID}/${RESULT_FILE}"
git commit -m "Task Result: ${TASK_ID}" >> "${RESULT_PATH}" 2>&1 || {
    echo "WARNING: git commit failed (possibly nothing to commit)" | tee -a "${RESULT_PATH}"
}

# Push with retry
echo "Pushing to GitHub..." | tee -a "${RESULT_PATH}"
RETRY_COUNT=0
MAX_RETRIES=3
PUSH_SUCCESS=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if git push origin main >> "${RESULT_PATH}" 2>&1; then
        PUSH_SUCCESS=1
        echo "Push successful" | tee -a "${RESULT_PATH}"
        break
    else
        RETRY_COUNT=$((RETRY_COUNT + 1))
        echo "Push failed (attempt $RETRY_COUNT/$MAX_RETRIES)" | tee -a "${RESULT_PATH}"

        if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
            echo "Retrying after pull --rebase..." | tee -a "${RESULT_PATH}"
            git pull --rebase origin main >> "${RESULT_PATH}" 2>&1 || true
            sleep 2
        fi
    fi
done

if [ $PUSH_SUCCESS -eq 0 ]; then
    echo "ERROR: Failed to push after $MAX_RETRIES attempts" | tee -a "${RESULT_PATH}"
    exit 1
fi

echo "=== Wrapper Script Completed ===" | tee -a "${RESULT_PATH}"
exit $EXIT_CODE
EOF_WRAPPER

    # Replace placeholders
    sed -i "s|__REMOTE_TASK_SCRIPT__|${remote_task_script}|g" "$local_wrapper"
    sed -i "s|__RESULT_FILE__|${result_file}|g" "$local_wrapper"
    sed -i "s|__GITHUB_REPO__|${GITHUB_REPO}|g" "$local_wrapper"
    sed -i "s|__TASK_ID__|${task_id}|g" "$local_wrapper"

    # Transfer scripts to remote host via SSH
    log_info "Transferring scripts to ${REMOTE_HOST} via SSH..."

    # Create remote directory structure
    log_info "Creating remote directory on ${REMOTE_HOST}..."
    ssh "${REMOTE_HOST}" "mkdir -p ${SHARED_DIR}" || {
        log_error "Failed to create remote directory"
        exit 1
    }

    # Transfer task script via SSH heredoc
    log_info "Transferring task script to ${remote_task_script}..."
    ssh "${REMOTE_HOST}" "cat > ${remote_task_script}" < "$task_script" || {
        log_error "Failed to transfer task script"
        exit 1
    }

    # Transfer wrapper script via SSH heredoc
    log_info "Transferring wrapper script to ${remote_wrapper_script}..."
    ssh "${REMOTE_HOST}" "cat > ${remote_wrapper_script}" < "$local_wrapper" || {
        log_error "Failed to transfer wrapper script"
        exit 1
    }

    # Set execute permissions
    log_info "Setting execute permissions on ${REMOTE_HOST}..."
    ssh "${REMOTE_HOST}" "chmod +x ${remote_task_script} ${remote_wrapper_script}" || {
        log_error "Failed to set execute permissions"
        exit 1
    }

    log_info "Starting execution on ${REMOTE_HOST}..."
    # Execute wrapper and schedule cleanup after execution
    ssh "${REMOTE_HOST}" "nohup bash -c 'bash ${remote_wrapper_script}; rm -f ${remote_task_script} ${remote_wrapper_script}' > /dev/null 2>&1 &" || {
        log_error "Failed to execute wrapper script"
        exit 1
    }

    log_info "Script execution started on ${REMOTE_HOST}"
    log_info "Remote scripts will be auto-cleaned after execution"
    log_info "Results will be uploaded to GitHub"

    # Clean up local wrapper
    rm -f "$local_wrapper"

    # Wait for results from GitHub
    log_info "Waiting for results from GitHub (polling every ${GITHUB_POLL_INTERVAL}s)..."
    log_info "Note: For long-running tasks, this may take a while..."

    local elapsed=0
    local result_found=0
    local result_dir="workspace/etx_results/results/${task_id}"

    while [ $elapsed -lt $GITHUB_POLL_TIMEOUT ]; do
        sleep $GITHUB_POLL_INTERVAL
        elapsed=$((elapsed + GITHUB_POLL_INTERVAL))

        # Pull latest changes
        git pull origin main >/dev/null 2>&1 || true

        # Check if result exists
        if [ -f "${result_dir}/${result_file}" ]; then
            result_found=1
            break
        fi

        log_debug "Polling... (${elapsed}s / ${GITHUB_POLL_TIMEOUT}s)"
    done

    if [ $result_found -eq 1 ]; then
        log_info "=== Task Result Found ==="
        echo ""
        cat "${result_dir}/${result_file}"
        echo ""

        # Archive locally if enabled
        if [ "$SAVE_RESULTS_LOCALLY" = "1" ]; then
            local archive_dir="workspace/etx_results/.archive/$(date +%Y%m)"
            mkdir -p "$archive_dir"
            local archive_file="${archive_dir}/${task_id}_${task_name}_result.txt"
            cp "${result_dir}/${result_file}" "$archive_file"
            log_info "Result archived locally: $archive_file"
        fi

        # Clean up from GitHub
        log_info "Cleaning up task directory from GitHub..."
        rm -rf "${result_dir}"
        git add "${result_dir}"
        git commit -m "Cleanup: Remove task directory ${task_id}" >/dev/null 2>&1 || true
        git push origin main >/dev/null 2>&1 || log_warn "Failed to push cleanup commit"

        log_info "Task completed successfully on ga53pd01"
        return 0
    else
        log_error "Timeout: No result received after ${GITHUB_POLL_TIMEOUT} seconds"
        log_info "Check the remote system manually: ssh ${REMOTE_HOST}"
        return 1
    fi
}

# Entry point
if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
    usage
    exit 0
fi

main "$@"
