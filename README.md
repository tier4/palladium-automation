# Palladium Automation

ETX/Palladium環境での自動化ツール。Tier4ハードウェアプロジェクト（hornet、gion等）のエミュレーション・検証作業を効率化します。

## 重要: プロジェクト内完結の原則

**このプロジェクトはすべての依存関係とツールをプロジェクト内で管理します。**

- ✅ グローバルインストール不要（`npm link` 等は使用しない）
- ✅ プロジェクトをクローンして `npm install` するだけで動作
- ✅ チームメンバー全員が同じ環境で作業可能
- ✅ システム全体の環境を汚染しない

## 概要

このプロジェクトは、特殊なネットワーク制約下で、**SSH経由のスクリプト転送とGitHub経由の結果回収**を組み合わせた自動化を実現します。

### アーキテクチャ

```
[ローカル RHEL8 (ip-172-17-34-126)]
    ↓ Claude Code動作
    ↓ スクリプト生成
    ↓ SSH heredoc経由でga53pd01に転送
    →→→ [リモート ga53pd01 (Palladium Compute Server)]
            ↓ バックグラウンド実行
            ↓ 実行完了後スクリプト自動削除
            ↓ 結果をGitHub（タスクIDディレクトリ）にpush
            ↓
[ローカル] ←←← GitHub経由で結果取得・自動クリーンアップ
```

### 主要機能

- ✅ **SSH heredoc方式のスクリプト転送**: 高速・安定・GUI操作不要
- ✅ **GitHub経由の結果自動回収**: ポーリングで結果取得
- ✅ **タスクIDディレクトリ方式**: 複数人並行実行対応
- ✅ **自動クリーンアップ**:
  - リモートスクリプト: 実行完了後自動削除
  - GitHub結果: 取得後即削除
- ✅ **ローカルアーカイブ**: `.archive/YYYYMM/` に永続保存
- ✅ **長期実行タスク対応**: 可変タイムアウト（デフォルト30分）

## ディレクトリ構造

```
palladium-automation/
├── scripts/                    # 自動化スクリプト
│   ├── claude_to_ga53pd01.sh  # SSH統合スクリプト（推奨）
│   ├── claude_to_etx.sh       # GUI統合スクリプト（レガシー）
│   ├── etx_automation.sh      # GUI自動操作スクリプト
│   └── capture_etx_window.sh  # ETX画面キャプチャスクリプト
├── mcp-servers/               # カスタムMCPサーバー
│   └── etx-automation/        # ETX自動化MCPサーバー
│       ├── index.js
│       └── package.json
├── .claude/
│   └── etx_tasks/             # Claude Codeが生成したタスクの一時保存
├── workspace/
│   └── etx_results/           # GitHub同期と結果アーカイブ
│       ├── .git/              # tier4/palladium-automation との同期
│       ├── results/           # 一時的なタスク結果（取得後削除）
│       └── .archive/          # ローカル永続保存（Git管理外）
├── .github/
│   └── workflows/
│       └── cleanup-old-results.yml  # 3日後の自動削除
├── docs/
│   ├── memo.md                # 技術検討メモ
│   ├── setup.md               # セットアップガイド
│   ├── plan.md                # 実装プラン
│   ├── github_integration_plan.md         # GitHub統合プラン
│   └── github_integration_implementation.md  # 実装完了報告
├── CLAUDE.md                  # Claude Code向けリポジトリガイド
└── README.md                  # このファイル
```

## 環境要件

### ローカル環境 (ip-172-17-34-126)
- OS: RHEL8
- 必須ツール:
  - SSH (公開鍵認証設定済み)
  - Node.js (MCP Server用)
  - Git
- オプション（GUIベース方式を使う場合）:
  - xdotool, wmctrl, xclip
  - netpbm-progs（画面キャプチャ用）

### リモート環境 (ga53pd01)
- OS: RHEL8
- Palladium Compute Server
- SSH経由でアクセス可能
- `/proj/tierivemu/work/henmi/` へのアクセス権限

## クイックスタート

> 📖 **詳細なセットアップ手順**: [docs/setup.md](docs/setup.md) を参照してください

### 1. 必要なツールのインストール

```bash
# GUI自動操作ツール
sudo dnf install -y xdotool wmctrl xclip

# 画面キャプチャツール
sudo dnf install -y netpbm-progs

# Node.jsがない場合
# sudo dnf install -y nodejs npm
```

### 2. DISPLAY環境変数の設定

```bash
export DISPLAY=:2  # 環境に応じて調整
```

### 3. プロジェクトのセットアップ

```bash
cd ~/palladium-automation

# MCP Serverのセットアップ
cd mcp-servers/etx-automation
npm install
cd ../..
```

### 4. Claude Code (CLI) への追加

```bash
cd /home/khenmi/palladium-automation
claude mcp add --transport stdio etx-automation -- node /home/khenmi/palladium-automation/mcp-servers/etx-automation/index.js
```

確認：
```bash
claude mcp list
# 出力: etx-automation: ... - ✓ Connected
```

**注意**:
- プロジェクトパスは環境に合わせて調整してください
- Claude Desktop（デスクトップアプリ）を使用する場合は[docs/setup.md](docs/setup.md)を参照

## 使用方法

### 事前準備: ETX Xterm起動

**重要**: スクリプトを実行する前に、ETX TurboX Dashboardから「Start Xterm」をクリックして、ETX Xtermウィンドウを起動してください。

### GUI自動操作スクリプト

```bash
# ウィンドウ一覧確認
./scripts/etx_automation.sh list

# ETXウィンドウをアクティブ化
./scripts/etx_automation.sh activate

# 単一コマンド実行
./scripts/etx_automation.sh exec 'hostname'

# スクリプト実行（行単位で転送）
./scripts/etx_automation.sh script ./my_script.sh
```

**重要**:
- スクリプトは `$HOME/.etx_tmp/` ディレクトリに保存されます（複数ユーザー対応）
- ファイル名はタイムスタンプ + プロセスIDでユニークになります

### ETX画面キャプチャ

```bash
# デフォルトのファイル名でキャプチャ
./scripts/capture_etx_window.sh

# ファイル名を指定してキャプチャ
./scripts/capture_etx_window.sh /path/to/output.png
```

**用途**:
- ETX Xtermの実行結果を視覚的に確認
- デバッグ時のスクリーンショット取得
- Claude Codeから画像として確認可能

### SSH統合スクリプト（推奨）

```bash
# ga53pd01でスクリプトを実行（SSH heredoc方式）
./scripts/claude_to_ga53pd01.sh /path/to/task_script.sh

# 長時間タスク（8時間タイムアウト）
GITHUB_POLL_TIMEOUT=28800 ./scripts/claude_to_ga53pd01.sh /path/to/long_task.sh

# デバッグモード
DEBUG=1 ./scripts/claude_to_ga53pd01.sh /path/to/task_script.sh
```

**特徴**:
- 高速・安定（GUI操作不要）
- 実行後リモートスクリプト自動削除
- 結果はGitHub経由で自動回収
- ローカルアーカイブに保存

### GUI統合スクリプト（レガシー）

```bash
# xdotool方式（非推奨）
./scripts/claude_to_etx.sh /path/to/task_script.sh
```

### Claude CodeのMCPツール

Claude Code内で以下のツールが利用可能:
- `execute_on_etx`: ETXで単一コマンド実行
- `run_script_on_etx`: スクリプト転送・実行・結果回収
- `activate_etx_window`: ETXウィンドウのアクティブ化

## トラブルシューティング

### xdotoolが動作しない

```bash
# X11ディスプレイ確認
echo $DISPLAY

# 権限設定
xhost +SI:localuser:$(whoami)

# ウィンドウ検索テスト
wmctrl -l
xdotool search --name "Terminal"
```

### SCP接続エラー

```bash
# SSH鍵確認
ssh-add -l

# 手動転送テスト
scp /tmp/test.txt khenmi@ip-172-17-34-126:/tmp/
```

## 開発ステータス

- [x] プロジェクト構造の作成
- [x] 環境セットアップ
- [x] コアスクリプトの実装
- [x] MCP Serverの実装
- [ ] 統合テスト
- [x] ドキュメント作成

詳細な実装プランは [`docs/plan.md`](docs/plan.md) を参照してください。

## ドキュメント

- [セットアップガイド](docs/setup.md) - 詳細なセットアップ手順
- [実装プラン](docs/plan.md) - 開発計画と進捗
- [CLAUDE.md](CLAUDE.md) - Claude Code向けガイド
- [技術メモ](docs/memo.md) - 初期の技術検討

## ライセンス

(ライセンス情報を追加)

## 貢献

(貢献ガイドラインを追加)
