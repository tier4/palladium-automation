# セットアップガイド

このガイドでは、Palladium Claude Code統合プロジェクトのセットアップ手順を説明します。

## 重要: プロジェクト内完結の原則

**このプロジェクトはグローバルインストールを使用しません。**

すべての依存関係とツールはプロジェクト内で管理されます。これにより:
- チームメンバー全員が同じ環境で作業可能
- システム全体の環境を汚染しない
- プロジェクトをクローンするだけで開始できる

## 目次

1. [前提条件](#前提条件)
2. [基本セットアップ](#基本セットアップ)
3. [MCP Server設定](#mcp-server設定)
4. [動作確認](#動作確認)
5. [トラブルシューティング](#トラブルシューティング)

---

## 前提条件

### ローカル環境（RHEL8 + GNOME）

必須ツール:
- xdotool
- wmctrl
- xclip
- Node.js (v16以降)
- Git
- SCP/SSH

### リモート環境（ETX/Palladium）

- RHEL8
- GitHub認証設定済み
- SCPアクセス可能

### 環境変数

```bash
# X11ディスプレイの設定（必須）
export DISPLAY=:2  # 環境に応じて調整

# .bashrcに追加することを推奨
echo 'export DISPLAY=:2' >> ~/.bashrc
```

---

## 基本セットアップ

### 1. 必要なツールのインストール

```bash
# GUI自動操作ツール
sudo dnf install -y xdotool wmctrl xclip

# 画面キャプチャツール
sudo dnf install -y netpbm-progs

# Node.jsがない場合（既にインストール済みの場合はスキップ）
# sudo dnf install -y nodejs npm
```

### 2. プロジェクトのクローン

```bash
cd ~
git clone https://github.com/your-org/palladium-automation.git
cd palladium-automation
```

### 3. ディレクトリ構造の確認

```bash
tree -L 2 -a
```

期待される構造:
```
palladium-automation/
├── .claude/
│   └── etx_tasks/
├── scripts/
│   ├── etx_automation.sh
│   └── claude_to_etx.sh
├── mcp-servers/
│   └── etx-automation/
├── workspace/
│   └── etx_results/
└── docs/
```

### 4. スクリプトの実行権限確認

```bash
chmod +x scripts/etx_automation.sh
chmod +x scripts/capture_etx_window.sh
chmod +x scripts/claude_to_etx.sh
chmod +x mcp-servers/etx-automation/index.js
```

---

## MCP Server設定

### 1. MCP Serverのインストール

```bash
cd ~/palladium-automation/mcp-servers/etx-automation
npm install
```

**注意**: グローバルインストール（npm link）は不要です。プロジェクト内で完結します。

### 2. インストール確認

```bash
# 依存関係がインストールされているか確認
ls -la mcp-servers/etx-automation/node_modules/@modelcontextprotocol

# MCPサーバーが実行可能か確認
node mcp-servers/etx-automation/index.js --version 2>&1 | head -5
```

### 3. Claude Code設定ファイルの作成

Claude Code設定ファイルの場所:
```bash
~/.config/Claude/claude_desktop_config.json
```

サンプル設定をコピー:
```bash
mkdir -p ~/.config/Claude
cp docs/claude_desktop_config.json.example ~/.config/Claude/claude_desktop_config.json
```

### 4. 設定ファイルの編集

```bash
nano ~/.config/Claude/claude_desktop_config.json
```

**最小構成（etx-automationのみ）**:
```json
{
  "mcpServers": {
    "etx-automation": {
      "command": "node",
      "args": ["/home/khenmi/palladium-automation/mcp-servers/etx-automation/index.js"]
    }
  }
}
```

### 4. MCP Serverの追加

#### Claude Code (CLI) を使用する場合（推奨）

```bash
cd /home/khenmi/palladium-automation
claude mcp add --transport stdio etx-automation -- node /home/khenmi/palladium-automation/mcp-servers/etx-automation/index.js
```

確認:
```bash
claude mcp list
# 出力: etx-automation: node /home/khenmi/palladium-automation/mcp-servers/etx-automation/index.js - ✓ Connected
```

#### Claude Desktop (デスクトップアプリ) を使用する場合

`~/.config/Claude/claude_desktop_config.json` を作成または編集：

```json
{
  "mcpServers": {
    "etx-automation": {
      "command": "node",
      "args": ["/home/khenmi/palladium-automation/mcp-servers/etx-automation/index.js"],
      "env": {
        "DEBUG": "0"
      }
    }
  }
}
```

**オプション: GitHub統合を追加する場合**:
```json
{
  "mcpServers": {
    "etx-automation": { ... },
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "ghp_your_token_here"
      }
    }
  }
}
```

**重要**:
- `/home/khenmi/palladium-automation` の部分は、あなたの環境のプロジェクトパスに合わせて変更してください
- Claude Code (CLI) と Claude Desktop (デスクトップアプリ) は異なる設定ファイルを使用します

### 5. Claude Codeの再起動（Claude Desktopの場合）

Claude Desktopを使用している場合、設定を反映させるためアプリケーションを再起動します。

---

## ETX Xtermの起動（重要）

**このプロジェクトでは、ETXから起動したXtermウィンドウをローカルで制御します。**

### ETX Xtermの起動手順

1. **ETX TurboX Clientにアクセス**
   - ブラウザでETX TurboX Dashboardを開く
   - または既存のETX接続を使用

2. **Start Xtermをクリック**
   - ETX Dashboard内の「Start Xterm」アイコンをクリック
   - ローカルデスクトップに新しいXtermウィンドウが表示される

3. **ウィンドウタイトルの確認**
   ```bash
   # ウィンドウ一覧で確認
   wmctrl -l | grep ga53
   ```

   期待される出力例：
   ```
   0x02a00405  0 ga53ut01 henmi@ga53ut01: /home/henmi
   ```

4. **ウィンドウ名の設定**
   - デフォルトでは `ga53ut01` をウィンドウ名として使用
   - 環境に応じて変更する場合：
     ```bash
     export ETX_WINDOW_NAME="your_window_name"
     ```

### 注意事項

- **ETX Xtermを起動せずにスクリプトを実行すると、ローカルのターミナルで実行されてしまいます**
- スクリプト実行前に必ずETX Xtermウィンドウが起動していることを確認してください
- ETX Xtermウィンドウは作業中、開いたままにしておく必要があります

---

## 動作確認

### 0. ETX Xterm起動確認（最初に実施）

```bash
# ETX Xtermウィンドウの起動を確認
wmctrl -l | grep ga53

# ウィンドウが見つからない場合は、ETX Dashboardから「Start Xterm」を実行
```

### 1. 基本コマンドテスト

```bash
cd ~/palladium-automation

# ウィンドウ一覧表示
./scripts/etx_automation.sh list

# ETX接続テスト
./scripts/etx_automation.sh test

# ETXウィンドウのアクティブ化
./scripts/etx_automation.sh activate
```

### 2. スクリプト実行テスト

```bash
# テストスクリプトの実行
./scripts/etx_automation.sh script .claude/etx_tasks/test_task.sh
```

### 3. Claude Code統合テスト（オプション）

GitHub経由の結果回収をテストする場合:

```bash
# GitHub設定の確認
# 1. GitHubリポジトリ: tier4/gion-automation へのアクセス権限
# 2. リモートETX環境でのGitHub認証設定

# テスト実行
./scripts/claude_to_etx.sh .claude/etx_tasks/test_task.sh
```

### 4. MCPサーバーの動作確認

Claude Code内で以下のツールが利用可能になっているか確認:

- `execute_on_etx` - ETXで単一コマンド実行
- `run_script_on_etx` - スクリプト転送・実行・結果回収
- `activate_etx_window` - ETXウィンドウのアクティブ化
- `list_windows` - ウィンドウ一覧表示
- `test_etx_connection` - 接続テスト

### 5. 画面キャプチャのテスト

```bash
# ETX Xtermが起動していることを確認
wmctrl -l | grep ga53

# キャプチャテスト
./scripts/capture_etx_window.sh

# 出力ファイル確認
ls -lh /tmp/etx_capture_*.png
```

**キャプチャ機能の使い道**:
- Claude Codeでスクリプト実行後、視覚的に結果を確認
- デバッグ時のスクリーンショット取得
- 実行エラーの診断

---

## トラブルシューティング

### xdotoolが動作しない

**症状**: `DISPLAY environment variable is not set`

**解決方法**:
```bash
# DISPLAY環境変数の確認
echo $DISPLAY

# 設定されていない場合
export DISPLAY=:2

# .bashrcに追加
echo 'export DISPLAY=:2' >> ~/.bashrc
source ~/.bashrc

# X11権限の設定
xhost +SI:localuser:$(whoami)
```

### ETXウィンドウが見つからない

**症状**: `ETX window not found`

**原因**: ETX Xtermウィンドウが起動していない、またはウィンドウ名が異なる

**解決方法**:

1. **ETX Xtermの起動確認**:
   ```bash
   # 全ウィンドウのリスト確認
   wmctrl -l

   # ETX関連のウィンドウを検索
   wmctrl -l | grep -i "ga53\|etx"
   ```

2. **ETX Xtermが起動していない場合**:
   - ETX TurboX Dashboard を開く
   - 「Start Xterm」アイコンをクリック
   - ローカルデスクトップにXtermウィンドウが表示されることを確認

3. **ウィンドウ名が異なる場合**:
   ```bash
   # 正しいウィンドウ名を確認
   wmctrl -l

   # 環境変数で指定
   export ETX_WINDOW_NAME="実際のウィンドウ名"
   ```

4. **よくある間違い**:
   - ❌ ローカルのターミナル（`khenmi@ip-172-17-34-126`）を使用している
   - ✅ ETX Xterm（`henmi@ga53ut01`）を使用する必要がある

### SCP接続エラー (Note: 現在のバージョンでは使用していません)

**症状**: `SCP transfer failed`

**解決方法**:
```bash
# SSH鍵の確認
ssh-add -l

# SSH鍵がない場合は追加
ssh-add ~/.ssh/id_rsa

# 手動接続テスト
scp /tmp/test.txt khenmi@ip-172-17-34-126:/tmp/

# ホストキーの確認
ssh-keyscan ip-172-17-34-126 >> ~/.ssh/known_hosts
```

### npm installが失敗する

**症状**: `Permission denied` または `EACCES`

**解決方法**:
```bash
# プロジェクトディレクトリの権限確認
ls -la ~/palladium-automation/mcp-servers/etx-automation

# 権限を修正
chmod -R u+w ~/palladium-automation/mcp-servers/etx-automation

# 再度インストール
cd ~/palladium-automation/mcp-servers/etx-automation
rm -rf node_modules package-lock.json
npm install
```

### Claude CodeがMCPサーバーを認識しない

**症状**: ツールが表示されない

**確認事項**:
1. 設定ファイルの場所が正しいか: `~/.config/Claude/claude_desktop_config.json`
2. JSONの構文エラーがないか（カンマ、括弧の確認）
3. プロジェクトパスが正しいか（絶対パスを使用）
4. MCP Serverの依存関係がインストールされているか
5. Claude Codeを完全に再起動したか

**デバッグ方法**:
```bash
# MCPサーバーを直接実行してエラー確認
node /home/khenmi/palladium-automation/mcp-servers/etx-automation/index.js

# 依存関係の確認
ls /home/khenmi/palladium-automation/mcp-servers/etx-automation/node_modules/@modelcontextprotocol

# JSON構文チェック
cat ~/.config/Claude/claude_desktop_config.json | jq .

# 設定ファイルの内容確認
cat ~/.config/Claude/claude_desktop_config.json
```

### GitHub結果取得がタイムアウトする

**症状**: `Timeout waiting for results`

**原因と解決方法**:
1. **リモートETXでGitHubにアクセスできない**
   - ETX環境でGitHub認証を確認
   - `git config --global user.name` と `user.email` の設定確認

2. **タスク実行が5分以上かかっている**
   - タイムアウト時間を調整（環境変数で設定可能に改善予定）
   - 手動でGitHubリポジトリを確認: https://github.com/tier4/gion-automation/tree/main/results

3. **ネットワーク遅延**
   - ポーリング間隔を調整
   - ローカルログファイルで確認

---

## 次のステップ

セットアップが完了したら:

1. [使用例](examples.md) を参照して実際のユースケースを試す
2. Claude Code内でMCPツールを使用してETX操作を自動化
3. 独自のタスクスクリプトを作成

---

## 参考資料

- [プロジェクト概要](../README.md)
- [実装プラン](plan.md)
- [CLAUDE.md](../CLAUDE.md) - Claude Code向けガイド
- [技術メモ](memo.md)

## サポート

問題が発生した場合:
1. このガイドのトラブルシューティングセクションを確認
2. プロジェクトのIssueを検索
3. 新しいIssueを作成して詳細を報告
