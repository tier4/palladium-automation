#!/bin/bash
# ga53pd01でのビルドタスク例
# 注意: claude_to_ga53pd01.shが自動的にGit同期を行うため、
#       このスクリプトではビルドコマンドのみを記述します。
#
# ビルドターゲット（必要に応じて変更）
# 利用可能なターゲット: kv260, zcu102, zcu106, vck190, au250

set -e  # エラーで即座に終了

TARGET="${TARGET:-all}"  # デフォルトターゲットは'all'

echo "=== ビルドタスク開始 ==="
echo "日付: $(date)"
echo "ホスト: $(hostname)"
echo "ターゲット: ${TARGET}"
echo ""

# プロジェクトディレクトリに移動
PROJECT_DIR="/proj/tierivemu/work/${USER}/hornet"
cd "${PROJECT_DIR}" || exit 1

# ビルドコマンド
echo "make clean を実行中..."
make clean

echo ""
echo "make ${TARGET} を実行中..."
make "${TARGET}"

echo ""
echo "=== ビルド完了 ==="
