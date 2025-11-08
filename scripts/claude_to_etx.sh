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
GITHUB_REPO="tier4/gion-automation"
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
    local remote_script="${ETX_SCRIPTS_DIR}/${task_name}_${timestamp}.sh"
    local result_file="${task_name}_${timestamp}_result.txt"

    log_info "=== Running Claude Code Task: $task_name ==="
    log_info "Timestamp: $timestamp"

    # 1. 結果収集用のラッパースクリプトを作成
    local wrapper_script="/tmp/wrapper_${timestamp}.sh"
    log_info "Creating wrapper script: $wrapper_script"

    cat > "$wrapper_script" << 'EOF_WRAPPER'
#!/bin/bash
# Auto-generated wrapper script

TASK_SCRIPT="__REMOTE_SCRIPT__"
RESULT_FILE="__RESULT_FILE__"
GITHUB_REPO="__GITHUB_REPO__"

echo "=== Wrapper Script Started ===" | tee /tmp/${RESULT_FILE}
echo "Date: $(date)" | tee -a /tmp/${RESULT_FILE}
echo "Hostname: $(hostname)" | tee -a /tmp/${RESULT_FILE}
echo "User: $(whoami)" | tee -a /tmp/${RESULT_FILE}
echo "" | tee -a /tmp/${RESULT_FILE}

# タスク実行
echo "=== Task Start: $(date) ===" | tee -a /tmp/${RESULT_FILE}
if bash ${TASK_SCRIPT} >> /tmp/${RESULT_FILE} 2>&1; then
    echo "=== Task End: $(date) ===" | tee -a /tmp/${RESULT_FILE}
    echo "Status: SUCCESS" | tee -a /tmp/${RESULT_FILE}
else
    echo "=== Task End: $(date) ===" | tee -a /tmp/${RESULT_FILE}
    echo "Status: FAILED (exit code: $?)" | tee -a /tmp/${RESULT_FILE}
fi
echo "" | tee -a /tmp/${RESULT_FILE}

# 結果をGitHubにpush
echo "=== Uploading results to GitHub ===" | tee -a /tmp/${RESULT_FILE}
cd /tmp

# GitHubリポジトリのクローンまたは更新
if [ -d "etx_results/.git" ]; then
    echo "Updating existing repository..." | tee -a /tmp/${RESULT_FILE}
    cd etx_results
    git pull origin main >> /tmp/${RESULT_FILE} 2>&1
else
    echo "Cloning repository..." | tee -a /tmp/${RESULT_FILE}
    git clone https://github.com/${GITHUB_REPO}.git etx_results >> /tmp/${RESULT_FILE} 2>&1
    cd etx_results
fi

# 結果ディレクトリの作成
mkdir -p results

# 結果ファイルのコピー
cp /tmp/${RESULT_FILE} results/
git add results/${RESULT_FILE}

# コミットとプッシュ
git config user.name "ETX Automation" 2>/dev/null || true
git config user.email "etx@automation.local" 2>/dev/null || true
git commit -m "ETX Task Result: ${RESULT_FILE}" >> /tmp/${RESULT_FILE} 2>&1

if git push origin main >> /tmp/${RESULT_FILE} 2>&1; then
    echo "Result uploaded to GitHub: results/${RESULT_FILE}" | tee -a /tmp/${RESULT_FILE}
else
    echo "WARNING: Failed to push to GitHub" | tee -a /tmp/${RESULT_FILE}
fi

echo "=== Wrapper Script Completed ===" | tee -a /tmp/${RESULT_FILE}
EOF_WRAPPER

    # プレースホルダーを置換
    sed -i "s|__REMOTE_SCRIPT__|${remote_script}|g" "$wrapper_script"
    sed -i "s|__RESULT_FILE__|${result_file}|g" "$wrapper_script"
    sed -i "s|__GITHUB_REPO__|${GITHUB_REPO}|g" "$wrapper_script"

    # 2. タスクスクリプトとラッパーを転送
    log_info "Transferring scripts to ETX..."

    if ! scp "$task_file" "${ETX_USER}@${ETX_HOST}:${remote_script}" 2>&1; then
        log_error "Failed to transfer task script"
        rm -f "$wrapper_script"
        return 1
    fi

    if ! scp "$wrapper_script" "${ETX_USER}@${ETX_HOST}:/tmp/wrapper_${timestamp}.sh" 2>&1; then
        log_error "Failed to transfer wrapper script"
        rm -f "$wrapper_script"
        return 1
    fi

    log_info "Transfer complete"
    rm -f "$wrapper_script"

    # 3. ETXで実行（GUI自動操作）
    log_info "Executing on ETX via GUI automation..."

    # 実行権限付与
    if ! "$ETX_AUTOMATION_SCRIPT" exec "chmod +x ${remote_script} /tmp/wrapper_${timestamp}.sh"; then
        log_error "Failed to set execute permissions"
        return 1
    fi
    sleep 1

    # バックグラウンドでラッパースクリプト実行
    if ! "$ETX_AUTOMATION_SCRIPT" exec "bash /tmp/wrapper_${timestamp}.sh &"; then
        log_error "Failed to execute wrapper script"
        return 1
    fi

    log_info "Script execution started on ETX"

    # 4. 結果をGitHubから取得（ポーリング）
    log_info "Waiting for results (polling GitHub)..."
    local max_wait=300  # 5分
    local waited=0
    local poll_interval=10

    while [ $waited -lt $max_wait ]; do
        # GitHubから最新を取得
        cd "$RESULTS_DIR"

        log_debug "Polling GitHub (${waited}s / ${max_wait}s)..."

        if [ -d ".git" ]; then
            git pull origin main >/dev/null 2>&1 || {
                log_warn "Failed to pull from GitHub (will retry)"
            }
        else
            git clone "https://github.com/${GITHUB_REPO}.git" . >/dev/null 2>&1 || {
                log_warn "Failed to clone from GitHub (will retry)"
            }
        fi

        # 結果ファイルの確認
        if [ -f "results/${result_file}" ]; then
            log_info "=== Task Result Found ==="
            echo ""
            cat "results/${result_file}"
            echo ""
            log_info "Result file saved to: $RESULTS_DIR/results/${result_file}"
            return 0
        fi

        sleep $poll_interval
        waited=$((waited + poll_interval))

        if [ $((waited % 30)) -eq 0 ]; then
            log_info "Still waiting... (${waited}s / ${max_wait}s)"
        fi
    done

    log_error "Timeout waiting for results after ${max_wait}s"
    log_info "The task may still be running on ETX"
    log_info "Check manually: https://github.com/${GITHUB_REPO}/tree/main/results"
    return 1
}

# 使用方法
usage() {
    cat << EOF
Usage: $0 <task_script.sh>

This script:
  1. Transfers Claude Code generated script to ETX
  2. Executes it via GUI automation
  3. Collects results via GitHub

Arguments:
  task_script.sh    Path to the task script to execute

Environment Variables:
  ETX_USER          SSH user (default: khenmi)
  ETX_HOST          SSH host (default: ip-172-17-34-126)
  GITHUB_REPO       GitHub repo for results (default: tier4/gion-automation)
  DEBUG             Set to 1 for debug output

Example:
  $0 .claude/etx_tasks/test_task.sh

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
