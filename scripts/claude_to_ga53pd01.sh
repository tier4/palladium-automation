#!/bin/bash
# ga53pd01でのSSH経由スクリプト実行
# ローカルとリモートのhornet Git同期を自動化

set -e

# プロジェクトルートの取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# ~/.ssh/configからREMOTE_USERを取得
get_ssh_user() {
    local host="$1"
    # ssh -Gで実際の設定値を取得（Host設定を含む）
    local user=$(ssh -G "${host}" 2>/dev/null | grep "^user " | head -1 | awk '{print $2}')
    if [ -n "$user" ] && [ "$user" != "$(whoami)" ]; then
        echo "$user"
    else
        # デフォルトは現在のユーザー
        whoami
    fi
}

# .envファイルからGIT_SYNC設定を読み込み（オプション）
GIT_SYNC="0"  # デフォルト: 無効
ENV_FILE="${PROJECT_ROOT}/.env"
if [ -f "${ENV_FILE}" ]; then
    # GIT_SYNCの値を取得（大文字小文字区別なし）
    git_sync_value=$(grep -i "^GIT_SYNC=" "${ENV_FILE}" | cut -d'=' -f2 | tr -d ' "' | tr '[:upper:]' '[:lower:]')
    if [ "$git_sync_value" = "true" ]; then
        GIT_SYNC="1"
        log_debug "Git同期が有効化されました (.env: GIT_SYNC=true)"
    fi
fi

# デフォルト設定
REMOTE_HOST="${REMOTE_HOST:-ga53pd01}"
REMOTE_USER="${REMOTE_USER:-$(get_ssh_user ${REMOTE_HOST})}"
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

# 使用方法
usage() {
    cat << EOF
使用方法: $0 <task_script>

引数:
  task_script    ga53pd01で実行するbashスクリプトのパス

環境変数:
  REMOTE_HOST    対象ホスト (デフォルト: ga53pd01)
  REMOTE_USER    SSHユーザー (デフォルト: ~/.ssh/configから自動取得)
  DEBUG          デバッグ出力を有効化 (デフォルト: 0)

実行例:
  $0 /tmp/my_task.sh
  DEBUG=1 $0 /tmp/my_task.sh

機能:
  - SSH同期実行（高速、リアルタイム出力）
  - ローカルアーカイブに自動保存（.archive/YYYYMM/）
  - リモートにファイルを残さない

EOF
}

# ローカルhornetのGit状態をチェック
check_local_hornet_git() {
    local hornet_path="${PROJECT_ROOT}/hornet"

    if [ ! -d "${hornet_path}/.git" ]; then
        log_warn "Local hornet is not a git repository: ${hornet_path}"
        return 1
    fi

    log_info "Checking local hornet Git status..."
    cd "${hornet_path}"

    # 未コミット変更のチェック
    if [ -n "$(git status --porcelain)" ]; then
        log_error "ローカルhornetに未コミットの変更があります！"
        echo ""
        git status --short
        echo ""
        log_error "【対処方法】以下のいずれかを実行してください："
        log_error "  1. 変更をコミット: git add . && git commit -m 'your message'"
        log_error "  2. 変更を一時退避: git stash"
        log_error ""
        log_error "説明: ga53pd01で実行する前に、ローカルの変更を確定する必要があります。"
        return 1
    fi

    # 未プッシュコミットのチェック
    git fetch origin --quiet 2>/dev/null || true
    local local_commit=$(git rev-parse HEAD)
    local remote_commit=$(git rev-parse @{u} 2>/dev/null)
    local current_branch=$(git branch --show-current)

    if [ -z "$remote_commit" ]; then
        log_error "ローカルhornetブランチにupstream（追跡ブランチ）が設定されていません"
        echo ""
        log_error "【説明】"
        log_error "  upstream = ローカルブランチが追跡するリモートブランチ"
        log_error "  新しく作成したブランチは、まだリモートにpushされていないため"
        log_error "  upstreamが設定されていません。"
        echo ""
        log_error "【対処方法】以下のコマンドでブランチをリモートにpushしてください："
        log_error "  git push -u origin ${current_branch}"
        echo ""
        log_error "  -u オプション: upstreamを設定しながらpush"
        log_error "  これ以降は 'git push' だけで自動的にこのブランチにpushされます"
        return 1
    elif [ "$local_commit" != "$remote_commit" ]; then
        log_error "ローカルhornetに未プッシュのコミットがあります！"
        echo ""
        log_error "  ローカル:  $local_commit"
        log_error "  リモート:  $remote_commit"
        echo ""
        log_error "【対処方法】以下のコマンドでコミットをpushしてください："
        log_error "  git push"
        echo ""
        log_error "説明: ga53pd01で最新コードを使用するため、まずリモートにpushが必要です。"
        return 1
    fi

    # ローカルGit情報を保存（後でリモートと比較）
    LOCAL_BRANCH=$(git branch --show-current)
    LOCAL_COMMIT=$(git rev-parse HEAD)

    log_info "ローカルhornet: ブランチ=${LOCAL_BRANCH}, コミット=${LOCAL_COMMIT:0:8}"

    cd - > /dev/null
    return 0
}

# メイン処理
main() {
    local task_script="$1"

    if [ -z "$task_script" ]; then
        log_error "タスクスクリプトが指定されていません"
        usage
        exit 1
    fi

    if [ ! -f "$task_script" ]; then
        log_error "タスクスクリプトが見つかりません: $task_script"
        exit 1
    fi

    # Git同期が有効な場合のみチェック
    if [ "${GIT_SYNC}" = "1" ]; then
        # ローカルhornetのGit状態をチェック
        if ! check_local_hornet_git; then
            log_error "ローカルhornetのGitチェックに失敗しました。実行を中止します。"
            exit 1
        fi
    else
        log_warn "Git同期はスキップされます（有効化するには.envにGIT_SYNC=trueを設定）"
        # Git同期なしの場合、ローカル情報は取得しない
        LOCAL_BRANCH=""
        LOCAL_COMMIT=""
    fi

    # タスクID生成
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local task_id="${USER}_${timestamp}"
    local task_name=$(basename "$task_script" .sh)

    log_info "=== ga53pd01でタスクを実行: $task_name ==="
    log_info "タスクID: $task_id"
    log_info "タイムスタンプ: $timestamp"
    log_info "実行モード: SSH同期実行（リアルタイム出力）"

    # Prepare local archive path
    local archive_month=$(date +%Y%m)
    local archive_path="${ARCHIVE_DIR}/${archive_month}"
    local result_file="${archive_path}/${task_id}_${task_name}_result.txt"

    # Create archive directory
    mkdir -p "$archive_path"

    # Git同期が有効な場合のみリモート同期を実行
    if [ "${GIT_SYNC}" = "1" ]; then
        log_info "${REMOTE_HOST}のリモートhornetを同期中..."

        # リモートhornetを同期してGit情報を取得
        local remote_git_output=$( (ssh "${REMOTE_HOST}" 'bash -s' <<'SYNC_SCRIPT'
HORNET_DIR="/proj/tierivemu/work/${USER}/hornet"

if [ -d "${HORNET_DIR}/.git" ]; then
    cd "${HORNET_DIR}"

    # Pull latest changes
    if git pull --quiet >/dev/null 2>&1; then
        # Success (no output)
        true
    else
        echo "ERROR=Git pull failed"
        exit 1
    fi

    # Output Git info for local comparison
    echo "REMOTE_BRANCH=$(git branch --show-current)"
    echo "REMOTE_COMMIT=$(git rev-parse HEAD)"
else
    echo "ERROR=Remote hornet is not a git repository: ${HORNET_DIR}"
    exit 1
fi
SYNC_SCRIPT
) 2>&1 | grep -E '^(REMOTE_BRANCH|REMOTE_COMMIT|ERROR)=' )

        local sync_exit_code=$?
        if [ $sync_exit_code -ne 0 ]; then
            log_error "リモートhornetの同期に失敗しました"
            exit 1
        fi

        # エラーチェック
        if echo "$remote_git_output" | grep -q '^ERROR='; then
            local error_msg=$(echo "$remote_git_output" | grep '^ERROR=' | cut -d'=' -f2-)
            log_error "リモートエラー: $error_msg"
            exit 1
        fi

        log_info "リモートでのgit pull成功"

        # リモートGit情報を解析
        eval "$remote_git_output"
        log_info "リモートhornet: ブランチ=${REMOTE_BRANCH}, コミット=${REMOTE_COMMIT:0:8}"

        # ローカルとリモートのGit情報を比較
        if [ "$LOCAL_BRANCH" != "$REMOTE_BRANCH" ]; then
            log_error "ブランチが一致しません！"
            log_error "  ローカル:  $LOCAL_BRANCH"
            log_error "  リモート:  $REMOTE_BRANCH"
            exit 1
        fi

        if [ "$LOCAL_COMMIT" != "$REMOTE_COMMIT" ]; then
            log_error "コミットが一致しません！"
            log_error "  ローカル:  $LOCAL_COMMIT"
            log_error "  リモート:  $REMOTE_COMMIT"
            exit 1
        fi

        log_info "✓ ローカルとリモートのhornetが同期されています"
        echo ""
    fi

    log_info "${REMOTE_HOST}でスクリプトを実行中..."
    log_info "出力先: $result_file"
    echo ""

    # SSH経由で実行し、アーカイブに保存
    if ssh "${REMOTE_HOST}" "bash -s" < "$task_script" 2>&1 | tee "$result_file"; then
        echo ""
        log_info "=== タスクが正常に完了しました ==="
        log_info "結果を保存: $result_file"

        # サマリー表示
        local line_count=$(wc -l < "$result_file")
        local file_size=$(du -h "$result_file" | cut -f1)
        log_info "出力: $line_count 行, $file_size"

        return 0
    else
        local exit_code=$?
        echo ""
        log_error "=== タスクが失敗しました ==="
        log_error "終了コード: $exit_code"
        log_warn "部分的な結果を保存: $result_file"
        return $exit_code
    fi
}

# エントリーポイント
if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
    usage
    exit 0
fi

main "$@"
