#!/bin/bash
# Claude Code → ETX 自動実行フロー
# Claude Codeが生成したスクリプトをETXで実行し、GitHub経由で結果回収

set -e

# 設定
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

CLAUDE_OUTPUT_DIR="$PROJECT_ROOT/.claude/etx_tasks"
ETX_AUTOMATION_SCRIPT="$SCRIPT_DIR/etx_automation.sh"
ETX_SCRIPTS_DIR="/home/khenmi/etx_automation"
ETX_USER="khenmi"
ETX_HOST="ip-172-17-34-126"
GITHUB_REPO="tier4/palladium-automation"
RESULTS_DIR="$PROJECT_ROOT/workspace/etx_results"

# カラー出力
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

# ディレクトリの作成
mkdir -p "$CLAUDE_OUTPUT_DIR"
mkdir -p "$RESULTS_DIR"

# Claude Codeが生成したスクリプトを実行
run_claude_task() {
    local task_file="$1"

    if [ ! -f "$task_file" ]; then
        log_error "Task file not found: $task_file"
        return 1
    fi

    local task_name=$(basename "$task_file" .sh)
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local task_id="${USER}_${timestamp}"
    local result_file="${task_name}_result.txt"

    log_info "=== Running Claude Code Task: $task_name ==="
    log_info "Task ID: $task_id"
    log_info "Timestamp: $timestamp"

    # 1. 結果収集用のラッパースクリプトを作成
    local wrapper_script="/tmp/wrapper_${timestamp}.sh"
    log_info "Creating wrapper script with GitHub integration..."

    cat > "$wrapper_script" << 'EOF_WRAPPER'
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

# タスク実行
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

# Git認証確認
echo "=== Checking Git Configuration ===" | tee -a "${RESULT_PATH}"
if ! git config --global user.name >/dev/null 2>&1; then
    echo "Setting default git user.name..." | tee -a "${RESULT_PATH}"
    git config --global user.name "ETX Automation"
fi

if ! git config --global user.email >/dev/null 2>&1; then
    echo "Setting default git user.email..." | tee -a "${RESULT_PATH}"
    git config --global user.email "etx@automation.local"
fi

# 結果をGitHubにpush
echo "=== Uploading results to GitHub ===" | tee -a "${RESULT_PATH}"
cd "$HOME/.etx_tmp" || {
    echo "ERROR: Cannot change to .etx_tmp directory" | tee -a "${RESULT_PATH}"
    exit 1
}

# リポジトリの準備（クローンまたは更新）
if [ -d "${REPO_DIR}/.git" ]; then
    echo "Repository exists, updating..." | tee -a "${RESULT_PATH}"
    cd "${REPO_DIR}"

    # リモート設定の確認
    if ! git remote get-url origin >/dev/null 2>&1; then
        echo "WARNING: Git remote not configured, re-cloning..." | tee -a "${RESULT_PATH}"
        cd ..
        rm -rf etx_results
        git clone "https://github.com/${GITHUB_REPO}.git" etx_results >> "${RESULT_PATH}" 2>&1
        cd etx_results
    else
        # pull --rebase で最新を取得
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

# タスクIDディレクトリを作成
mkdir -p "results/${TASK_ID}"

# 結果ファイルをコピー
if ! cp "${RESULT_PATH}" "results/${TASK_ID}/"; then
    echo "ERROR: Failed to copy result file" | tee -a "${RESULT_PATH}"
    exit 1
fi

git add "results/${TASK_ID}/${RESULT_FILE}"
git commit -m "Task Result: ${TASK_ID}" >> "${RESULT_PATH}" 2>&1 || {
    echo "WARNING: git commit failed (possibly nothing to commit)" | tee -a "${RESULT_PATH}"
}

# Pushリトライ（最大3回）
echo "Pushing to GitHub..." | tee -a "${RESULT_PATH}"
RETRY_COUNT=0
MAX_RETRIES=3
PUSH_SUCCESS=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if git push origin main >> "${RESULT_PATH}" 2>&1; then
        echo "SUCCESS: Result uploaded to GitHub: results/${TASK_ID}/${RESULT_FILE}" | tee -a "${RESULT_PATH}"
        PUSH_SUCCESS=1
        break
    else
        RETRY_COUNT=$((RETRY_COUNT + 1))
        if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
            echo "Push failed, retrying ($RETRY_COUNT/$MAX_RETRIES)..." | tee -a "${RESULT_PATH}"
            git pull --rebase origin main >> "${RESULT_PATH}" 2>&1
            sleep 2
        else
            echo "ERROR: Failed to push after $MAX_RETRIES attempts" | tee -a "${RESULT_PATH}"
            echo "Please check GitHub authentication" | tee -a "${RESULT_PATH}"
        fi
    fi
done

if [ $PUSH_SUCCESS -eq 0 ]; then
    echo "WARNING: Result not uploaded to GitHub" | tee -a "${RESULT_PATH}"
fi

echo "=== Wrapper Script Completed (Exit Code: ${EXIT_CODE}) ===" | tee -a "${RESULT_PATH}"
exit ${EXIT_CODE}
EOF_WRAPPER

    # プレースホルダーを置換
    local remote_task_script="\$HOME/.etx_tmp/task_${timestamp}.sh"
    local remote_wrapper_script="\$HOME/.etx_tmp/wrapper_${timestamp}.sh"

    sed -i "s|__REMOTE_TASK_SCRIPT__|${remote_task_script}|g" "$wrapper_script"
    sed -i "s|__RESULT_FILE__|${result_file}|g" "$wrapper_script"
    sed -i "s|__GITHUB_REPO__|${GITHUB_REPO}|g" "$wrapper_script"
    sed -i "s|__TASK_ID__|${task_id}|g" "$wrapper_script"

    # 2. タスクスクリプトとラッパーを転送・実行（xdotool方式）
    log_info "Transferring and executing scripts on ETX via GUI automation..."

    if ! "$ETX_AUTOMATION_SCRIPT" script-with-github \
        "$task_file" \
        "$wrapper_script" \
        "$remote_task_script" \
        "$remote_wrapper_script"; then
        log_error "Failed to transfer and execute scripts"
        rm -f "$wrapper_script"
        return 1
    fi

    log_info "Scripts transferred and execution started on ETX"
    rm -f "$wrapper_script"

    # 3. 結果をGitHubから取得（ポーリング）
    log_info "Waiting for results from GitHub (polling every ${poll_interval:-10}s)..."
    log_info "Note: For long-running tasks, this may take a while..."

    local max_wait=${GITHUB_POLL_TIMEOUT:-1800}  # デフォルト30分（長期実行対応）
    local poll_interval=${GITHUB_POLL_INTERVAL:-10}
    local waited=0
    local result_subdir="results/${task_id}"

    # GitHubリポジトリのセットアップ
    cd "$RESULTS_DIR"
    if [ ! -d ".git" ]; then
        log_info "Cloning GitHub repository for the first time..."
        if ! git clone "https://github.com/${GITHUB_REPO}.git" . >/dev/null 2>&1; then
            log_error "Failed to clone GitHub repository"
            log_info "Troubleshooting:"
            log_info "  1. Check repository exists: https://github.com/${GITHUB_REPO}"
            log_info "  2. Check GitHub authentication (git clone test)"
            log_info "  3. Check network connectivity"
            return 1
        fi
    fi

    # ポーリングループ
    while [ $waited -lt $max_wait ]; do
        log_debug "Polling GitHub (${waited}s / ${max_wait}s)..."

        # GitHubから最新を取得
        if git pull origin main >/dev/null 2>&1; then
            log_debug "Successfully pulled from GitHub"
        else
            log_warn "Failed to pull from GitHub (will retry)"
        fi

        # 結果ファイルの確認
        if [ -f "${result_subdir}/${result_file}" ]; then
            log_info "=== Task Result Found ==="
            echo ""
            cat "${result_subdir}/${result_file}"
            echo ""

            # ローカルに永続保存（オプション）
            if [ "${SAVE_RESULTS_LOCALLY:-1}" = "1" ]; then
                local archive_dir="$RESULTS_DIR/.archive/$(date +%Y%m)"
                mkdir -p "$archive_dir"
                cp "${result_subdir}/${result_file}" "$archive_dir/${task_id}_${result_file}"
                log_info "Result archived locally: $archive_dir/${task_id}_${result_file}"
            fi

            # GitHubから削除（取得後クリーンアップ）
            log_info "Cleaning up task directory from GitHub..."
            git rm -rf "${result_subdir}" >/dev/null 2>&1 || {
                log_warn "Failed to remove task directory (may already be deleted)"
            }

            if [ -n "$(git status --porcelain)" ]; then
                git commit -m "cleanup: Task ${task_id} retrieved by ${USER}@$(hostname)" >/dev/null 2>&1

                if git push origin main >/dev/null 2>&1; then
                    log_debug "Task directory cleaned up from GitHub"
                else
                    log_warn "Failed to push cleanup (will be handled by scheduled cleanup)"
                fi
            fi

            # 成功/失敗判定
            if grep -q "Status: SUCCESS" "${result_subdir}/${result_file}" 2>/dev/null || \
               grep -q "Status: SUCCESS" "$archive_dir/${task_id}_${result_file}" 2>/dev/null; then
                log_info "Task completed successfully on ETX"
                return 0
            else
                log_error "Task failed on ETX (see result above)"
                return 1
            fi
        fi

        sleep $poll_interval
        waited=$((waited + poll_interval))

        # 30秒ごとに進捗表示
        if [ $((waited % 30)) -eq 0 ]; then
            log_info "Still waiting... (${waited}s / ${max_wait}s)"
        fi
    done

    log_error "Timeout waiting for results after ${max_wait}s"
    log_info "The task may still be running on ETX, or GitHub push failed"
    log_info "Troubleshooting:"
    log_info "  1. Check ETX Xterm window (script may still be running)"
    log_info "  2. Check GitHub: https://github.com/${GITHUB_REPO}/tree/main/results/${task_id}"
    log_info "  3. Check local result file on ETX: \$HOME/.etx_tmp/${result_file}"
    log_info "  4. Check ETX GitHub authentication: ssh to ETX and run 'git config --list'"
    return 1
}

# 使用方法
usage() {
    cat << EOF
Usage: $0 <task_script.sh>

This script:
  1. Creates a wrapper script with GitHub integration
  2. Transfers both task and wrapper scripts to ETX via xdotool
  3. Executes the task on ETX
  4. Collects results via GitHub (polling)
  5. Archives results locally and cleans up GitHub

Arguments:
  task_script.sh    Path to the task script to execute

Environment Variables:
  ETX_USER                SSH user (default: khenmi)
  ETX_HOST                SSH host (default: ip-172-17-34-126)
  GITHUB_REPO             GitHub repo for results (default: tier4/palladium-automation)
  GITHUB_POLL_TIMEOUT     Max wait time in seconds (default: 1800 = 30min)
  GITHUB_POLL_INTERVAL    Polling interval in seconds (default: 10)
  SAVE_RESULTS_LOCALLY    Save results to .archive/ (default: 1)
  DEBUG                   Set to 1 for debug output

Example:
  $0 .claude/etx_tasks/test_task.sh

  # For very long tasks (e.g., overnight builds)
  GITHUB_POLL_TIMEOUT=28800 $0 .claude/etx_tasks/long_build.sh

Results:
  - GitHub: https://github.com/tier4/palladium-automation/tree/main/results/
  - Local archive: workspace/etx_results/.archive/YYYYMM/

EOF
}

# メイン
main() {
    if [ $# -eq 0 ]; then
        log_error "No task script specified"
        echo ""
        usage
        exit 1
    fi

    local task_file="$1"

    # ETX自動操作スクリプトの確認
    if [ ! -f "$ETX_AUTOMATION_SCRIPT" ]; then
        log_error "ETX automation script not found: $ETX_AUTOMATION_SCRIPT"
        exit 1
    fi

    # タスク実行
    if run_claude_task "$task_file"; then
        log_info "Task completed successfully"
        exit 0
    else
        log_error "Task failed"
        exit 1
    fi
}

main "$@"
