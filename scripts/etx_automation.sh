#!/bin/bash
# ETX GUI自動操作スクリプト
# xdotoolを使用してETXターミナルウィンドウを制御

set -e

# 設定
# ETXウィンドウ名: ETXから起動したXtermウィンドウを識別（例: henmi@ga53ut01）
# Start Xtermで起動したローカルに表示されるETX Xtermウィンドウを対象とする
ETX_WINDOW_NAME="${ETX_WINDOW_NAME:-ga53ut01}"
ETX_USER="khenmi"
ETX_HOST="ip-172-17-34-126"
REMOTE_WORKDIR="/home/khenmi/workspace"
LOCAL_WORKDIR="$HOME/workspace"

# カラー出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ログ関数
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

# ETXウィンドウをアクティブにする
activate_etx_window() {
    log_info "Activating ETX window..."

    # ウィンドウを検索
    WINDOW_ID=$(xdotool search --name "$ETX_WINDOW_NAME" 2>/dev/null | head -n 1)

    if [ -z "$WINDOW_ID" ]; then
        log_error "ETX window not found: $ETX_WINDOW_NAME"
        log_info "Available windows:"
        wmctrl -l | grep -i "etx\|terminal" || wmctrl -l | head -5
        return 1
    fi

    log_debug "Found window ID: $WINDOW_ID"

    # ウィンドウをアクティブ化
    xdotool windowactivate "$WINDOW_ID"
    sleep 0.5

    # ウィンドウが前面に来ているか確認
    ACTIVE_WINDOW=$(xdotool getactivewindow 2>/dev/null)
    if [ "$ACTIVE_WINDOW" = "$WINDOW_ID" ]; then
        log_info "ETX window activated (ID: $WINDOW_ID)"
        return 0
    else
        log_warn "Window activated but may not be in foreground"
        return 0
    fi
}

# ETXターミナルでコマンド実行
execute_on_etx() {
    local command="$1"

    if [ -z "$command" ]; then
        log_error "No command specified"
        return 1
    fi

    log_info "Executing on ETX: $command"

    # ウィンドウをアクティブ化
    activate_etx_window || return 1

    # コマンド入力（Ctrl+Cは送信しない - タイミング問題を回避）
    log_debug "Typing command"
    xdotool type --clearmodifiers "$command"
    sleep 0.2

    # Enter押下
    log_debug "Pressing Enter"
    xdotool key Return

    log_info "Command sent to ETX successfully"
    return 0
}

# スクリプトファイルをETXに転送して実行（xdotool type方式）
transfer_and_execute() {
    local local_script="$1"
    local remote_script="$2"

    if [ -z "$local_script" ]; then
        log_error "No local script specified"
        return 1
    fi

    if [ ! -f "$local_script" ]; then
        log_error "Script not found: $local_script"
        return 1
    fi

    # デフォルトのリモートスクリプトパス
    # ホームディレクトリ内の一時ディレクトリを使用（複数ユーザー対応）
    # 注: \$HOMEはリモート側で展開される
    if [ -z "$remote_script" ]; then
        remote_script="\$HOME/.etx_tmp/etx_script_$(date +%s)_$$.sh"
    fi

    log_info "Transferring $local_script to ETX:$remote_script..."

    # ETXウィンドウをアクティブ化
    activate_etx_window || return 1
    sleep 0.5

    # ディレクトリが存在しない場合は作成
    local remote_dir=$(dirname "$remote_script")
    if [ "$remote_dir" != "/tmp" ] && [ "$remote_dir" != "." ]; then
        log_debug "Creating directory: $remote_dir"
        xdotool type --delay 10 --clearmodifiers "mkdir -p $remote_dir"
        sleep 0.2
        xdotool key Return
        sleep 0.5
    fi

    # 一時的にファイルをbase64エンコード
    local base64_content=$(base64 -w 0 "$local_script")

    log_info "Creating script file on ETX (line by line)..."

    # スクリプトを行ごとに処理して転送
    # まずファイルを削除（存在する場合）
    xdotool type --delay 10 --clearmodifiers "rm -f ${remote_script}"
    sleep 0.2
    xdotool key Return
    sleep 0.5

    # 各行をechoで追記
    while IFS= read -r line; do
        # 特殊文字をエスケープ（シングルクォートで囲む）
        # ただしシングルクォート自体は '\'' でエスケープ
        escaped_line="${line//\'/\'\\\'\'}"
        xdotool type --delay 5 --clearmodifiers "echo '${escaped_line}' >> ${remote_script}"
        sleep 0.1
        xdotool key Return
        sleep 0.2
    done < "$local_script"

    sleep 1

    log_info "Transfer complete"

    # ファイルが作成されたか確認
    log_info "Verifying file creation..."
    xdotool type --delay 10 --clearmodifiers "ls -la ${remote_script}"
    sleep 0.2
    xdotool key Return
    sleep 1

    # ETXで実行権限付与（直接xdotoolを使用）
    log_info "Setting execute permission..."
    xdotool type --delay 10 --clearmodifiers "chmod +x ${remote_script}"
    sleep 0.2
    xdotool key Return
    sleep 1

    # ETXでスクリプト実行（結果をログファイルにも保存）
    log_info "Executing script on ETX..."
    local log_file="\$HOME/.etx_tmp/etx_output_$(date +%s)_$$.log"
    xdotool type --delay 10 --clearmodifiers "bash ${remote_script} 2>&1 | tee ${log_file}"
    sleep 0.2
    xdotool key Return

    log_info "Script execution started on ETX"
    log_info "Output will be saved to: ${log_file}"
    return 0
}

# ウィンドウ一覧表示
list_windows() {
    log_info "Listing available windows:"
    wmctrl -l | while read line; do
        echo "  $line"
    done
}

# ETX接続テスト
test_connection() {
    log_info "Testing connection to ETX..."

    # SSH鍵確認
    log_info "Checking SSH keys..."
    if ssh-add -l >/dev/null 2>&1; then
        log_info "SSH agent has keys loaded"
        ssh-add -l
    else
        log_warn "No SSH keys loaded in agent"
    fi

    # SCP接続テスト
    log_info "Testing SCP connection..."
    local test_file="/tmp/etx_test_$(date +%s).txt"
    echo "Connection test from $(hostname) at $(date)" > "$test_file"

    if scp "$test_file" "${ETX_USER}@${ETX_HOST}:/tmp/" 2>&1; then
        log_info "SCP connection successful"
        rm -f "$test_file"
        return 0
    else
        log_error "SCP connection failed"
        rm -f "$test_file"
        return 1
    fi
}

# heredoc方式でスクリプトを転送する共通関数
transfer_script_heredoc() {
    local local_script="$1"
    local remote_script="$2"

    if [ ! -f "$local_script" ]; then
        log_error "Local script not found: $local_script"
        return 1
    fi

    local line_count=$(wc -l < "$local_script")
    log_debug "Transferring $local_script to $remote_script ($line_count lines)"

    # ディレクトリ作成
    local remote_dir=$(dirname "$remote_script")
    if [ "$remote_dir" != "/tmp" ] && [ "$remote_dir" != "." ]; then
        log_debug "Creating directory: $remote_dir"
        xdotool type --delay 10 --clearmodifiers "mkdir -p $remote_dir"
        xdotool key Return
        sleep 0.5
    fi

    # heredoc方式で一度に転送
    log_debug "Starting heredoc transfer..."
    xdotool type --delay 10 --clearmodifiers "cat > ${remote_script} << 'EOF_SCRIPT_CONTENT'"
    xdotool key Return
    sleep 0.5

    # スクリプトの内容をクリップボード経由で転送
    log_debug "Copying script content to clipboard..."
    xclip -selection clipboard < "$local_script"
    sleep 0.3

    # クリップボードから貼り付け（Ctrl+Shift+V: ターミナルでの貼り付け）
    log_debug "Pasting from clipboard..."
    xdotool key --clearmodifiers ctrl+shift+v
    sleep 1

    # heredocの終了
    xdotool key Return
    xdotool type --delay 10 --clearmodifiers "EOF_SCRIPT_CONTENT"
    xdotool key Return
    sleep 1

    # 転送完了を確認
    log_debug "Verifying transfer..."
    xdotool type --delay 10 --clearmodifiers "if [ -f ${remote_script} ]; then echo '[VERIFIED] Transfer complete'; wc -l ${remote_script}; else echo '[FAILED] Transfer failed'; fi"
    xdotool key Return
    sleep 2

    log_debug "Transfer complete: $remote_script"
}

# タスクスクリプトとラッパースクリプトを転送して実行
transfer_and_execute_with_github() {
    local task_script="$1"
    local wrapper_script="$2"
    local remote_task="$3"
    local remote_wrapper="$4"

    log_info "=== GitHub Integration Mode ==="
    log_info "Task script: $task_script"
    log_info "Wrapper script: $wrapper_script"

    # ウィンドウをアクティブ化
    activate_etx_window || return 1
    sleep 0.5

    # 1. タスクスクリプト転送（heredoc方式）
    log_info "Transferring task script (heredoc method)..."
    transfer_script_heredoc "$task_script" "$remote_task" || return 1

    # 2. ラッパースクリプト転送（heredoc方式）
    log_info "Transferring wrapper script (heredoc method)..."
    transfer_script_heredoc "$wrapper_script" "$remote_wrapper" || return 1

    # 3. 実行権限付与
    log_info "Setting execute permissions..."
    xdotool type --delay 10 --clearmodifiers "chmod +x ${remote_task} ${remote_wrapper}"
    xdotool key Return
    sleep 3  # 1秒から3秒に延長

    # 4. ラッパー実行（バックグラウンド）
    log_info "Executing wrapper script in background..."
    log_info "Note: Script execution will start after all input is processed by ETX terminal"
    xdotool type --delay 10 --clearmodifiers "bash ${remote_wrapper} &"
    xdotool key Return
    sleep 0.5

    log_info "Script execution started on ETX"
    log_info "Results will be uploaded to GitHub"
    return 0
}

# 使用方法を表示
usage() {
    cat << EOF
Usage: $0 {exec|script|script-with-github|activate|list|test} [args...]

Commands:
  exec <command>                              Execute a single command on ETX
  script <local> [remote]                     Transfer and execute a script on ETX
  script-with-github <task> <wrapper> <r_task> <r_wrapper>
                                              Transfer task + wrapper scripts for GitHub integration
  activate                                    Activate ETX window (bring to front)
  list                                        List available windows
  test                                        Test connection to ETX

Examples:
  $0 exec 'ls -la'
  $0 script ./my_script.sh /tmp/remote_script.sh
  $0 script-with-github ./task.sh ./wrapper.sh \$HOME/.etx_tmp/task.sh \$HOME/.etx_tmp/wrapper.sh
  $0 activate
  $0 list
  $0 test

Environment Variables:
  ETX_WINDOW_NAME    Window title to search for (default: "ETX Terminal")
  ETX_USER           SSH user (default: khenmi)
  ETX_HOST           SSH host (default: ip-172-17-34-126)
  DEBUG              Set to 1 for debug output

EOF
}

# メイン処理
main() {
    local command="$1"

    # DISPLAY環境変数の確認
    if [ -z "$DISPLAY" ]; then
        log_error "DISPLAY environment variable is not set"
        log_info "Set it with: export DISPLAY=:2"
        exit 1
    fi

    case "$command" in
        "exec")
            # 単一コマンド実行
            shift
            if [ $# -eq 0 ]; then
                log_error "No command specified"
                usage
                exit 1
            fi
            execute_on_etx "$@"
            ;;
        "script")
            # スクリプトファイル実行
            shift
            if [ $# -eq 0 ]; then
                log_error "No script specified"
                usage
                exit 1
            fi
            local local_script="$1"
            local remote_script="${2:-}"
            transfer_and_execute "$local_script" "$remote_script"
            ;;
        "script-with-github")
            # タスクスクリプト + ラッパースクリプトの転送・実行
            shift
            if [ $# -lt 4 ]; then
                log_error "Usage: script-with-github <local_task> <local_wrapper> <remote_task> <remote_wrapper>"
                usage
                exit 1
            fi
            transfer_and_execute_with_github "$1" "$2" "$3" "$4"
            ;;
        "activate")
            # ウィンドウのアクティブ化のみ
            activate_etx_window
            ;;
        "list")
            # ウィンドウ一覧表示
            list_windows
            ;;
        "test")
            # 接続テスト
            test_connection
            ;;
        "-h"|"--help"|"help")
            usage
            exit 0
            ;;
        *)
            log_error "Unknown command: $command"
            echo ""
            usage
            exit 1
            ;;
    esac
}

main "$@"
