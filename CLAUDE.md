# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## プロジェクト概要

このリポジトリは、Palladium環境でのClaude Code活用を実現するためのプロジェクトです。特殊なネットワーク制約下(ローカルからリモートへの片方向SCP転送のみ可能)で、GUI自動操作とGitHub経由の結果回収を組み合わせた自動化ワークフローを構築します。

## 重要な開発ルール

### プロジェクト内完結の原則

**すべての依存関係、ツール、設定はプロジェクト内で完結させる**

1. **グローバルインストール禁止**
   - `npm link` やグローバルパッケージインストールは使用しない
   - すべての依存関係は `package.json` で管理し、プロジェクトの `node_modules` に配置
   - システム全体の環境を変更しない

2. **絶対パス使用の徹底**
   - 設定ファイルでは相対パスではなく絶対パスを使用
   - プロジェクトルート: `/home/khenmi/palladium-automation`
   - 環境変数で動的に取得する場合は明示的にドキュメント化

3. **チーム共有可能性**
   - 各メンバーが自分の環境でプロジェクトをクローンするだけで動作
   - グローバル環境への依存を最小化
   - 環境固有の設定はドキュメントで明示

4. **セットアップの簡素化**
   ```bash
   # 必要な手順はこれだけ
   cd ~/palladium-automation
   cd mcp-servers/etx-automation
   npm install
   ```

5. **設定ファイルの管理**
   - サンプル設定: `docs/claude_desktop_config.json.example`
   - 実際の設定: `~/.config/Claude/claude_desktop_config.json` (ユーザー個別)
   - プロジェクトパスは環境に応じて調整が必要であることを明記

## 環境制約

### ネットワーク構成
- **ローカル環境**: RHEL8 + GNOME
- **リモート環境(ETX)**: RHEL8 (Palladium チャンバー)
- **制約事項**:
  - リモート環境からインターネットへの直接アクセス不可
  - SSH/HTTP/HTTPS プロトコル使用不可
  - SCPによるファイル転送はローカル→リモートの片方向のみ可能
  - GitHubへのアクセスは両環境で可能

### 重要な接続情報
- ETXユーザー: `khenmi`
- ETXホスト: `ip-172-17-34-126`
- リモート作業ディレクトリ: `/home/khenmi/workspace`
- 結果共有用GitHubリポジトリ: `tier4/palladium-automation`

## アーキテクチャ

```
[ローカル RHEL8 + GNOME]
    ↓ Claude Code動作
    ↓ スクリプト生成
    ↓ SCP転送
    →→→ [リモート RHEL8 (ETX/Palladium)]
            ↓ GUI自動操作で実行
            ↓ 結果をGitHub経由で返却
            ↓
[ローカル] ←←← GitHub経由で結果取得
```

このアーキテクチャにより、Claude Codeはローカル環境で動作しながら、リモートのPalladium環境を制御できます。

## 自動化スクリプト

### 1. GUI自動操作スクリプト (`scripts/etx_automation.sh`)

xdotoolを使用してETXターミナルウィンドウを制御します。

**主要機能**:
- `exec`: リモートETXで単一コマンドを実行
- `script`: スクリプトファイルをETXに転送して実行（行単位echo方式）
- `activate`: ETXウィンドウをアクティブ化
- `list`: ウィンドウ一覧表示
- `test`: 接続テスト

**使用例**:
```bash
# 単一コマンド実行
./scripts/etx_automation.sh exec 'ls -la'

# スクリプト実行（行単位で転送）
./scripts/etx_automation.sh script ./my_script.sh /tmp/remote_script.sh

# ウィンドウアクティブ化
./scripts/etx_automation.sh activate

# ウィンドウ一覧表示
./scripts/etx_automation.sh list

# 接続テスト
./scripts/etx_automation.sh test
```

**重要事項**:
- ETX Xtermウィンドウを事前に起動しておく必要があります（Start Xtermをクリック）
- スクリプトは `$HOME/.etx_tmp/` ディレクトリに保存されます（複数ユーザー対応）
- ファイル名はタイムスタンプ + プロセスIDでユニークになります

### 2. ETXウィンドウキャプチャスクリプト (`scripts/capture_etx_window.sh`)

ETX Xtermの画面をPNG形式でキャプチャします。

**使用例**:
```bash
# デフォルトのファイル名でキャプチャ
./scripts/capture_etx_window.sh

# ファイル名を指定してキャプチャ
./scripts/capture_etx_window.sh /path/to/output.png
```

**機能**:
- ETX Xtermウィンドウを自動検出
- PNG形式で保存（netpbm使用）
- Claude Codeから画像として確認可能

### 3. Claude Code統合スクリプト (`scripts/claude_to_etx.sh`)

Claude Codeが生成したスクリプトをETXで実行し、GitHub経由で結果を自動回収する統合スクリプトです。

**実装済み機能**:
- ✅ xdotool経由でのスクリプト転送（SCP不要）
- ✅ GitHub経由の結果自動回収
- ✅ タスクIDディレクトリ方式（複数人並行実行対応）
- ✅ 取得後の自動クリーンアップ
- ✅ ローカルアーカイブ（`.archive/YYYYMM/`）
- ✅ 長期実行タスク対応（可変タイムアウト）

**使用例**:
```bash
# 基本的な使用方法
./scripts/claude_to_etx.sh /path/to/task_script.sh

# 長時間タスク（8時間タイムアウト）
GITHUB_POLL_TIMEOUT=28800 ./scripts/claude_to_etx.sh /path/to/long_task.sh

# 結果の保存先
# - GitHub: https://github.com/tier4/palladium-automation/tree/main/results/<task_id>/
# - ローカルアーカイブ: workspace/etx_results/.archive/YYYYMM/
```

**環境変数**:
- `GITHUB_POLL_TIMEOUT`: タイムアウト（秒）、デフォルト: 1800（30分）
- `GITHUB_POLL_INTERVAL`: ポーリング間隔（秒）、デフォルト: 10
- `SAVE_RESULTS_LOCALLY`: ローカル保存、デフォルト: 1

**動作フロー**:
1. タスクスクリプトとラッパースクリプトを生成
2. xdotoolでETXに転送（行単位echo方式）
3. ETXでバックグラウンド実行
4. 結果をGitHubにpush（タスクIDディレクトリ）
5. ローカルでポーリング＆結果取得
6. ローカルアーカイブに保存
7. GitHubから自動削除

## MCP Server統合

### etx-automation MCPサーバー

Claude CodeがETXを直接制御できるようにするカスタムMCPサーバーを提供します。

**場所**: `mcp-servers/etx-automation/`

**提供ツール**:
- `execute_on_etx`: ETXで単一コマンド実行
- `run_script_on_etx`: スクリプト転送・実行・GitHub結果回収（タイムアウト設定可能）
- `activate_etx_window`: ETXウィンドウのアクティブ化
- `list_windows`: ウィンドウ一覧表示
- `test_etx_connection`: 接続テスト

**run_script_on_etxの新機能**:
- GitHub経由の自動結果回収
- タスクIDディレクトリ方式
- 長期実行タスク対応（`timeout`パラメータ）
- ローカルアーカイブ自動保存
- 取得後の自動クリーンアップ

**セットアップ**:
```bash
cd mcp-servers/etx-automation
npm install
```

**Claude Code (CLI) への追加**:
```bash
# プロジェクトディレクトリで実行
cd /home/khenmi/palladium-automation
claude mcp add --transport stdio etx-automation -- node /home/khenmi/palladium-automation/mcp-servers/etx-automation/index.js
```

**確認**:
```bash
claude mcp list
# 出力: etx-automation: node /home/khenmi/palladium-automation/mcp-servers/etx-automation/index.js - ✓ Connected
```

**注**:
- プロジェクトパスは環境に合わせて調整してください
- MCPサーバーはプロジェクトごとに自動的に読み込まれます（`~/.claude.json`に保存）
- Claude Desktop（デスクトップアプリ）を使用する場合は、`~/.config/Claude/claude_desktop_config.json`に設定してください

## 開発ワークフロー

### Claude CodeでETXを操作する際の推奨手順

1. **スクリプト生成**: ローカルでタスクに応じたbashスクリプトを生成
2. **MCP経由で実行**: `run_script_on_etx` ツールでETXに転送・実行
3. **結果確認**: GitHub経由で実行結果を自動取得・表示
4. **エラー対応**: 必要に応じて `execute_on_etx` で直接コマンド実行

### 典型的なユースケース

**ビルド実行**:
```
ユーザー: 「ETXでgionプロジェクトのビルドを実行して」
→ ビルドスクリプト生成 → run_script_on_etx → 結果表示
```

**ログ確認**:
```
ユーザー: 「ETXでXceliumシミュレーションのエラーログを確認して」
→ execute_on_etx で grep実行 → 結果解析 → エラー原因特定
```

## トラブルシューティング

### xdotoolの初期設定

```bash
# 必要パッケージのインストール
sudo dnf install xdotool wmctrl xclip

# X11ディスプレイ確認
echo $DISPLAY  # 出力例: :0

# 権限設定
xhost +SI:localuser:$(whoami)

# ETXウィンドウの検索
wmctrl -l
xdotool search --name "ETX Terminal"
```

### SCP接続の確認

```bash
# SSH鍵の確認
ssh-add -l

# 手動転送テスト
scp /tmp/test.txt khenmi@ip-172-17-34-126:/tmp/
```

### GitHub同期の問題

結果取得がタイムアウトする場合:
1. リモート環境でGitHub認証が正しく設定されているか確認
2. ネットワーク遅延を考慮してタイムアウト時間を調整
3. 手動でGitHubリポジトリを確認

## ディレクトリ構造

```
palladium-automation/
├── scripts/
│   ├── etx_automation.sh      # GUI自動操作スクリプト
│   └── claude_to_etx.sh       # Claude Code統合スクリプト
├── mcp-servers/
│   └── etx-automation/        # カスタムMCPサーバー
│       ├── index.js
│       └── package.json
├── .claude/
│   └── etx_tasks/             # Claude Codeが生成したタスクの一時保存
├── workspace/
│   └── etx_results/           # GitHubから取得した実行結果
├── docs/
│   ├── memo.md                # 技術検討メモ
│   └── plan.md                # 実装プラン
├── CLAUDE.md                  # このファイル
└── README.md                  # プロジェクト概要
```

## 注意事項

- リモート環境(ETX/Palladium)は外部ネットワークアクセスが制限されているため、すべての依存関係は事前に準備が必要
- GUI自動操作は視覚的なフィードバックが限定的なため、ログ出力を充実させることが重要
- GitHub経由の結果回収にはネットワーク遅延があるため、長時間実行されるタスクに適している
- xdotoolはウィンドウタイトルでターミナルを識別するため、ターミナルタイトルの変更に注意
