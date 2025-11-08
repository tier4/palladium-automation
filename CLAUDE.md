# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## プロジェクト概要

このリポジトリは、Palladium環境でのClaude Code活用を実現するためのプロジェクトです。**hornet GPU/GPGPU開発のラッパープロジェクト**として、SSH経由でga53pd01コンピュートサーバー上のPalladiumエミュレータを制御し、RTL解析・ビルド・シミュレーション・結果分析をワンストップで実行します。

### プロジェクト構成

```
palladium-automation/     # このプロジェクト（ラッパー）
├── hornet/              # git clone された hornetプロジェクト
│   ├── src/            # Verilog/SystemVerilog RTL
│   ├── eda/            # EDA tool configs, testbenches
│   └── tb/             # Testbenches
├── scripts/            # 自動化スクリプト
│   └── claude_to_ga53pd01.sh  # SSH sync execution
├── workspace/          # 実行結果
└── .serena/            # Serena MCP設定（Verilog解析）
```

### 主要機能

1. **RTL解析**: Serena MCPでhornetのVerilog/SystemVerilogコードを解析
2. **リモート実行**: SSH経由でga53pd01にスクリプト転送・実行（2-3秒）
3. **結果分析**: 実行結果の自動回収・アーカイブ・解析
4. **ワンストップ**: palladium-automation内で解析から実行まで完結

## 重要な開発ルール

### プロジェクト内完結の原則

**すべての依存関係、ツール、設定はプロジェクト内で完結させる**

1. **グローバルインストール禁止**
   - `npm link` やグローバルパッケージインストールは使用しない
   - すべての依存関係は `package.json` で管理し、プロジェクトの `node_modules` に配置
   - システム全体の環境を変更しない

2. **絶対パス使用の徹底**
   - 設定ファイルでは相対パスではなく絶対パスを使用
   - プロジェクトルート: `/home/khenmi/palladium-automation` (例)
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

### 3. SSH統合スクリプト (`scripts/claude_to_ga53pd01.sh`) **推奨**

SSH経由でga53pd01コンピュートサーバーにスクリプトを転送・実行し、結果を取得する統合スクリプトです。

**2つの実行モード**:

#### モード1: SSH同期実行（デフォルト・推奨）
- ✅ SSH heredoc方式による高速・安定したスクリプト転送
- ✅ リアルタイムで実行結果を表示
- ✅ 即座に結果取得（2-3秒）
- ✅ GUI操作不要（xdotoolの問題を解消）
- ✅ ローカルアーカイブ（`.archive/YYYYMM/`）
- ⚠️ SSH接続維持が必要（短〜中時間タスク向け）

#### モード2: GitHub非同期実行（長時間タスク用）
- ✅ GitHub経由の結果自動回収
- ✅ SSH切断後も実行継続
- ✅ タスクIDディレクトリ方式（複数人並行実行対応）
- ✅ 長期実行タスク対応（可変タイムアウト）
- ⏱️ 結果取得に時間がかかる（10-30秒）

**使用例**:
```bash
# 基本的な使用方法（SSH同期実行）
./scripts/claude_to_ga53pd01.sh /path/to/task_script.sh

# GitHub非同期実行モード（長時間タスク用）
USE_GITHUB=1 ./scripts/claude_to_ga53pd01.sh /path/to/long_task.sh

# GitHub非同期 + 長時間タイムアウト（8時間）
USE_GITHUB=1 GITHUB_POLL_TIMEOUT=28800 ./scripts/claude_to_ga53pd01.sh /path/to/very_long_task.sh

# 結果の保存先
# - SSH同期: ローカルアーカイブのみ: workspace/etx_results/.archive/YYYYMM/
# - GitHub非同期: GitHub一時保存 + ローカルアーカイブ
```

**環境変数**:
- `USE_GITHUB`: GitHub非同期モード有効化、デフォルト: 0（SSH同期）
- `REMOTE_HOST`: リモートホスト名、デフォルト: ga53pd01
- `REMOTE_USER`: SSHユーザー名、デフォルト: henmi
- `PROJECT_NAME`: プロジェクト名、デフォルト: tierivemu
- `GITHUB_POLL_TIMEOUT`: タイムアウト（秒）、デフォルト: 1800（30分）※GitHub非同期時のみ
- `GITHUB_POLL_INTERVAL`: ポーリング間隔（秒）、デフォルト: 10※GitHub非同期時のみ
- `SAVE_RESULTS_LOCALLY`: ローカル保存、デフォルト: 1

**動作フロー（SSH同期実行）**:
1. タスクスクリプトをSSH stdin経由でga53pd01に転送
2. ga53pd01で同期実行（リアルタイム出力）
3. 実行完了後、結果をローカルアーカイブに保存
4. リモートに一時ファイルは残らない

**動作フロー（GitHub非同期実行）**:
1. タスクスクリプトとラッパースクリプトを生成
2. SSH heredocでga53pd01に転送
3. ga53pd01でバックグラウンド実行
4. 実行完了後、リモートスクリプトを自動削除
5. 結果をGitHubにpush（タスクIDディレクトリ）
6. ローカルでポーリング＆結果取得
7. ローカルアーカイブに保存
8. GitHubから自動削除

**リモートスクリプト保存先**: `/proj/tierivemu/work/henmi/etx_tmp/`（GitHub非同期時のみ）

**詳細**: テスト結果と比較は [docs/ssh_direct_retrieval_test.md](docs/ssh_direct_retrieval_test.md) を参照

### 4. GUI統合スクリプト (`scripts/claude_to_etx.sh`) **レガシー**

xdotoolを使用してETXターミナルでスクリプトを実行する旧方式です。

**注意**: GUI操作による不安定性のため、`claude_to_ga53pd01.sh`の使用を推奨します。

**動作フロー**:
1. タスクスクリプトとラッパースクリプトを生成
2. xdotoolでETXに転送（行単位echo方式）
3. ETXでバックグラウンド実行
4. 結果をGitHubにpush
5. ローカルで結果取得

## Claude Codeからの使用方法

SSH同期実行がシンプルなため、MCPサーバーは不要です。Claude CodeのBashツールから直接スクリプトを実行できます。

**基本的な使用方法**:
```bash
# Claude Codeが生成したスクリプトを実行
./scripts/claude_to_ga53pd01.sh /path/to/task_script.sh
```

**Claude Codeでの実行例**:
```
ユーザー: "ga53pd01でホスト名を確認して"

Claude Code:
1. タスクスクリプトを生成（/tmp/check_hostname.sh）
2. Bashツールで実行:
   ./scripts/claude_to_ga53pd01.sh /tmp/check_hostname.sh
3. リアルタイムで結果を確認
```

**特徴**:
- MCPサーバー不要（シンプル）
- Bashツールで直接実行
- リアルタイムで出力確認
- 自動的にローカルアーカイブに保存

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

## Serena MCP統合（Verilog解析）

### セットアップ

**Serena MCPは既に設定済みです**。以下のコマンドで確認できます：

```bash
claude mcp list
# serena: ... - ✓ Connected
```

### Hornetプロジェクトの管理

Hornetプロジェクトは`palladium-automation/hornet/`にgit cloneされています：

```bash
# Hornetの更新
cd hornet
git fetch origin
git pull origin main

# Hornet の状態確認
cd hornet
git status
git log --oneline -10
```

**重要**: `hornet/`ディレクトリは`.gitignore`に追加されており、palladium-automationのGit管理対象外です。

### Serena MCPの使用

Serena MCPツールは自動的に利用可能です：

- `mcp__serena__find_file`: Verilogファイルを検索
- `mcp__serena__get_symbols_overview`: ファイルのシンボル概要取得
- `mcp__serena__find_symbol`: シンボル検索（モジュール、関数等）
- `mcp__serena__search_for_pattern`: パターン検索
- `mcp__serena__read_file`: ファイル読み取り
- その他の解析・編集ツール

### 典型的なワークフロー

```
ユーザー: 「hornetのt4_hornet_topモジュールを解析して、ALUの接続を確認して」

Claude Code:
1. mcp__serena__find_file で t4_hornet_top.sv を検索
   → hornet/src/t4_hornet_top.sv

2. mcp__serena__get_symbols_overview でシンボル概要取得
   → モジュール構造を把握

3. mcp__serena__search_for_pattern でALU関連の接続を検索
   → ALU instantiation を発見

4. 分析結果をユーザーに報告
```

### Serena MCPのメモリ機能

Serenaは以下のメモリファイルを自動的に管理します：

- `project_purpose.md`: プロジェクトの目的
- `tech_stack.md`: 技術スタック
- `suggested_commands.md`: 推奨コマンド
- `codebase_structure.md`: コードベース構造
- `task_completion_checklist.md`: タスク完了チェックリスト

これらはClaude Codeが自動的に参照します。

### Serenaメモリの追加情報

プロジェクト固有の情報（IXCOM使用方法、Palladium設定等）は、Serenaメモリに保存されています：

- `ixcom_usage_guide.md`: IXCOMコンパイラの使用方法とオプション

新しいメモリの追加：
```bash
# Serena MCPのwrite_memoryツールを使用
mcp__serena__write_memory --memory_name <name> --content <content>
```

## Palladium/IXCOMドキュメントアクセス

### Playwright MCPによるオンラインドキュメント参照

Cadence公式ドキュメントは**Playwright MCP**を使用してアクセスできます。

**アクセス手順**:

1. **Cadence Support Portalにログイン**:
   ```
   URL: https://support.cadence.com/apex/HomePage
   ログイン情報: ユーザーが入力（Kentoshi Henmi）
   ```

2. **ドキュメント検索**:
   - Playwright MCPでページナビゲーション・検索を実行
   - 例: "Palladium Z3"で検索 → 210件以上の結果

3. **主要ドキュメント**:
   - **IXCOM ReadMe** (IXCOM 25.08): 既知の問題、新機能
   - **Palladium Z3/Z2 Planning and Installation Guide**: システム概要、環境要件
   - **Compiling Designs with IXCOM**: コンパイル詳細
   - **Behavioral Compilation with IXCOM**: SIXC_CTRL directive使用法

**Playwright MCP使用例**:
```
ユーザー: 「IXCOMのループブレーカー機能について調べて」

Claude Code:
1. mcp__playwright__browser_navigate でCadence Support Portalにアクセス
2. mcp__playwright__browser_type で"IXCOM loop breaker"を検索
3. mcp__playwright__browser_click で該当ドキュメントを開く
4. mcp__playwright__browser_take_screenshot でスクリーンショット取得
5. 関連情報を抽出してユーザーに報告
```

### ローカルドキュメント参照（ga53pd01）

ga53pd01上では**Cadence Doc Assistant (CDA)**を使用してローカルドキュメントにアクセスできます。

**CDA情報**:
- バージョン: Doc Assistant v02.20
- パス: `/apps/IXCOM2405/24.05.338.s005/bin/cda`
- 旧ツール: `cdnshelp` (24.05以降非推奨)

**起動方法**:
```bash
# デフォルト起動（オンラインモード：クラウドから最新ドキュメント取得）
cda &

# 製品マニュアル表示
cda -tool &

# オフラインモード（ローカルインストールからドキュメント）
cda -hierarchy /apps/IXCOM2405/24.05.338.s005/doc &

# 検索
cda -search "loop breaker" &
```

### IXCOMコマンドラインヘルプ

ga53pd01でIXCOMのヘルプを直接確認できます：

```bash
# 基本ヘルプ
ixcom -help

# コンパイルオプション
ixcom -help compile

# エラボレーションオプション
ixcom -help elaborate

# バージョン確認
ixcom -version
```

**IXCOM基本情報**:
- バージョン: V24.05.338.s005
- パス: `/apps/IXCOM2405/24.05.338.s005/bin/ixcom`
- 詳細: `.serena/memories/ixcom_usage_guide.md` 参照

## 注意事項

- リモート環境(ga53pd01/Palladium)は外部ネットワークアクセスが制限されているため、すべての依存関係は事前に準備が必要
- SSH同期実行は短〜中時間タスク向け（2-3秒のオーバーヘッド）
- 長時間タスクの場合は`USE_GITHUB=1`モードを使用
- hornetディレクトリの変更は、必要に応じて上流にpush
