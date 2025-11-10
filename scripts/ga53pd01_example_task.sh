#!/bin/bash
# ga53pd01でのビルドタスク例
# 注意: claude_to_ga53pd01.shが自動的にGit同期を行うため、
#       このスクリプトではビルドコマンドのみを記述します。

set -e  # エラーで即座に終了

echo "=== ビルドタスク開始 ==="
echo "日付: $(date)"
echo "ホスト: $(hostname)"
echo ""

# プロジェクトディレクトリに移動
PROJECT_DIR="/proj/tierivemu/work/${USER}/hornet"
cd "${PROJECT_DIR}" || exit 1

# ビルドコマンド（必要に応じて修正）
echo "make clean を実行中..."
make clean

echo ""
echo "make all を実行中..."
make all

echo ""
echo "=== ビルド完了 ==="
