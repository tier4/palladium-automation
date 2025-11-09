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

## Hornet RTL開発ワークフロー

**ローカルhornetがメイン開発環境です。**

```
[ローカル] hornet/ でRTL解析・編集 (Serena MCP使用)
   ↓
[ローカル] hornet/ で git commit & push
   ↓
[ga53pd01] hornet/ で git pull
   ↓
[ga53pd01] Palladiumエミュレーション実行
   ↓
[ローカル] 結果分析（ログ解析）
```

### 実行例

```bash
# 1. ローカルでRTL編集（Claude Code + Serena MCP）
cd hornet
# Serena MCPでVerilogコードを解析・編集
git add src/modified_file.sv
git commit -m "fix: update ALU logic"
git push origin <branch_name>

# 2. ga53pd01で最新コードを取得してビルド
# Claude Codeに以下のように指示:
「ga53pd01の/proj/tierivemu/work/henmi/hornetでgit pullして、ビルドを実行して」
```

### 重要な注意事項

- **ローカルとga53pd01のhornetは同じブランチを使用してください**
- ローカルhornetでSerena MCPを使ってRTL解析・編集を行う
- 修正後は必ずgit push してからga53pd01でgit pull
- ga53pd01はビルド・エミュレーション実行専用

## 環境設定

### .env ファイルによる環境カスタマイズ

**このプロジェクトは `.env` ファイルで環境変数を設定します。**

#### 初回セットアップ

```bash
# .env.example をコピーして自分の環境に合わせて編集
cp .env.example .env
nano .env
```

#### 設定例

```bash
# Remote SSH Configuration
REMOTE_HOST=ga53pd01
REMOTE_USER=your_username
PROJECT_NAME=your_project_name

# Bastion Configuration
BASTION_HOST=10.108.64.1
BASTION_USER=${REMOTE_USER}
```

#### 重要事項
- `.env` ファイルは `.gitignore` に含まれており、Git管理対象外
- 各ユーザーが自分の環境に合わせて設定
- スクリプトは `.env` から環境変数を自動読み込み

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
   git clone https://github.com/tier4/hornet.git  # hornetプロジェクトのクローン
   claude-serena  # Serena MCP設定（オプション）
   ```

5. **設定ファイルの管理**
   - サンプル設定: `docs/claude_desktop_config.json.example`
   - 実際の設定: `~/.config/Claude/claude_desktop_config.json` (ユーザー個別)
   - プロジェクトパスは環境に応じて調整が必要であることを明記

## 環境制約

### ネットワーク構成
- **ローカル環境**: RHEL8 + GNOME
- **リモート環境**: RHEL8 + Palladium (ga53pd01)
- **接続方式**: SSH ProxyJump経由（バスティオン: 10.108.64.1）

### 重要な接続情報

**注意**: 以下の設定は `.env` ファイルで環境に合わせてカスタマイズできます。

- リモートホスト: `${REMOTE_HOST}` (デフォルト: `ga53pd01`)
- ユーザー名: `${REMOTE_USER}` (`.env` で設定)
- プロジェクト名: `${PROJECT_NAME}` (`.env` で設定)
- リモート作業ディレクトリ: `/proj/${PROJECT_NAME}/work/${REMOTE_USER}/`
- 結果アーカイブ: `workspace/etx_results/.archive/YYYYMM/`
- GitHubリポジトリ: `tier4/palladium-automation`

## アーキテクチャ

### SSH同期実行方式（現在の実装）

```
[ローカル RHEL8 + GNOME]
    ↓ Claude Code動作
    ↓ タスクスクリプト生成
    ↓ SSH stdin経由で転送（2-3秒）
    →→→ [リモート ga53pd01 (Palladium)]
            ↓ スクリプト同期実行
            ↓ リアルタイム出力
            ↓ 実行結果を即座に返却
            ↓
[ローカル] ←←← SSH経由で結果取得（即時）
    ↓ ローカルアーカイブ保存
    ↓ .archive/YYYYMM/
```

**特徴**:
- ✅ 高速（2-3秒のオーバーヘッド）
- ✅ シンプル（GUI操作不要）
- ✅ リアルタイム出力
- ✅ 安定（xdotoolの問題なし）
- ⚠️ SSH接続を維持する必要あり（短〜中時間タスク向け）

**適用ケース**:
- 数分〜数十分のビルド・シミュレーション
- リアルタイムで出力を確認したいタスク
- 通常の開発作業

### X11転送方式（GUIツール表示用）

```
[ローカル RHEL8 + GNOME (DISPLAY=:2)]
    ↑ X11転送で表示
    ↑
[リモート ga53pd01 (DISPLAY=10.108.64.21:16.0)]
    ↓ GUIツール起動（CDA、波形ビューア等）
    ↓ X11 Forwarding経由
    ↓
[ローカル] gnome-screenshot でキャプチャ
    ↓
[Claude Code] Read tool で画像確認
```

**特徴**:
- ✅ GUIツールをローカルで表示
- ✅ Claude Codeで画像確認可能
- ✅ CDA、Simvision等に対応

### 長時間タスクについて

**現在の制限**: `claude_to_ga53pd01.sh`はSSH同期実行のみ実装されています。数時間以上かかる長時間タスクの場合は、以下の対処方法があります：

1. **SSH画面セッション使用**: `screen`または`tmux`でセッションを維持
2. **nohupでバックグラウンド実行**: SSH経由で`nohup`コマンドを使用
3. **GitHub非同期モードの実装**: 将来的な拡張として検討中

このアーキテクチャにより、Claude Codeはローカル環境で動作しながら、リモートのPalladium環境を効率的に制御できます。

## リモート実行スクリプト

### SSH統合スクリプト (`scripts/claude_to_ga53pd01.sh`)

ga53pd01でスクリプトを実行するメインスクリプトです。

**基本的な使用方法**:
```bash
# SSH同期実行（現在の実装）
./scripts/claude_to_ga53pd01.sh /path/to/task_script.sh
```

**機能**:
- SSH heredoc方式による高速実行（2-3秒）
- リアルタイム出力表示
- SSH接続を維持して即座に結果取得
- 短〜中時間タスク向け（数分〜数十分）

**結果保存先**:
- ローカルアーカイブ: `workspace/etx_results/.archive/YYYYMM/`
- タスクIDディレクトリ形式で保存

### レガシースクリプト

GUI自動操作スクリプト（xdotoolベース）は `scripts/.legacy/` に移動されました。詳細は [scripts/.legacy/README.md](scripts/.legacy/README.md) を参照してください。

## Claude Codeからの使用方法

Claude CodeのBashツールから直接スクリプトを実行できます。

**実行例**:
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

### ga53pd01での作業手順

1. **スクリプト生成**: ローカルでタスクに応じたbashスクリプトを生成
2. **SSH実行**: `./scripts/claude_to_ga53pd01.sh <script>` で実行
3. **結果確認**: リアルタイムまたはアーカイブから確認
4. **デバッグ**: 必要に応じてSSHで直接ログイン

### 典型的なユースケース

**ビルド実行**:
```
ユーザー: 「ga53pd01でgionプロジェクトのビルドを実行して」
→ ビルドスクリプト生成 → claude_to_ga53pd01.sh で実行 → 結果表示
```

**ログ確認**:
```
ユーザー: 「ga53pd01でXceliumシミュレーションのエラーログを確認して」
→ grepスクリプト生成 → claude_to_ga53pd01.sh で実行 → 結果解析 → エラー原因特定
```

## トラブルシューティング

### SSH接続の問題

```bash
# SSH鍵の確認
ssh-add -l

# 接続テスト
ssh ga53pd01 'hostname'

# ProxyJump設定確認
cat ~/.ssh/config | grep -A5 "Host ga53pd01"

# デバッグモードで接続
ssh -v ga53pd01
```

### スクリプト実行エラー

```bash
# デバッグモードで実行
DEBUG=1 ./scripts/claude_to_ga53pd01.sh /path/to/script.sh

# アーカイブ確認
ls -lh workspace/etx_results/.archive/$(date +%Y%m)/

# 最新の結果ファイルを表示
ls -lt workspace/etx_results/.archive/$(date +%Y%m)/ | head -5
```

### GitHub非同期実行のタイムアウト

長時間タスクで結果取得がタイムアウトする場合:

```bash
# タイムアウト時間を延長（例: 8時間）
USE_GITHUB=1 GITHUB_POLL_TIMEOUT=28800 ./scripts/claude_to_ga53pd01.sh /path/to/long_task.sh

# リモート環境でGitHub認証確認
ssh ga53pd01 'git config --get user.name'
ssh ga53pd01 'git config --get user.email'
```

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

## GUIツール表示とキャプチャ

ga53pd01上のGUIツール（CDA、波形ビューア等）は、X11転送経由でローカルGNOMEデスクトップに表示し、Claude Codeで確認できます。

### 基本ワークフロー

```
ga53pd01 (SSH経由)
  ↓ GUIツール起動
  ↓ X11転送 (DISPLAY=10.108.64.21:16.0)
  ↓
ローカルGNOME (DISPLAY=:2)
  ↓ gnome-screenshot
  ↓
Claude Code
  ↓ Read tool
  ✓ 画像確認
```

### 利用可能なGUIツール

| ツール | 説明 | 起動コマンド |
|--------|------|-------------|
| CDA | Cadence Doc Assistant (ドキュメントビューア) | `cda -tool &` |
| gedit | テキストエディタ（テスト用） | `gedit <file> &` |
| xterm | ターミナル | `xterm &` |
| Simvision | 波形ビューア（シミュレーション後） | `simvision &` |

### Claude Code プロンプト例

#### 例1: CDAを起動してキャプチャ

```
ユーザー: 「ga53pd01でCadence Doc Assistantを起動してキャプチャを取って」

Claude Code:
1. ga53pd01でCDA起動スクリプトを作成
2. SSH経由でCDAを起動（バックグラウンド実行）
3. X11転送でローカルに表示（自動）
4. gnome-screenshotでキャプチャ
5. Read toolで画像確認
6. ユーザーに結果報告
```

#### 例2: IXCOMドキュメントをCDAで表示

```
ユーザー: 「CDAでIXCOMのループブレーカーに関するドキュメントを表示して」

Claude Code:
1. ga53pd01でCDA起動：cda -search "loop breaker" &
2. X11転送でローカル表示
3. gnome-screenshotでキャプチャ
4. 画像を確認してユーザーに報告
```

#### 例3: 任意のGUIツールをキャプチャ

```
ユーザー: 「ga53pd01でgeditを起動して、サンプルテキストを表示してキャプチャして」

Claude Code:
1. サンプルテキストファイル作成
2. gedit起動スクリプト作成・実行
3. X11転送でローカル表示
4. gnome-screenshotでキャプチャ
5. Read toolで画像確認
6. クリーンアップ（プロセス終了）
```

### 実装方法

#### 1. ga53pd01でGUIツール起動

スクリプト例：
```bash
#!/bin/bash
# /tmp/launch_gui.sh

echo "DISPLAY=${DISPLAY}"
cda -tool &
CDA_PID=$!
echo "CDA launched with PID: $CDA_PID"
sleep 5  # GUIの起動待ち
echo "CDA window visible on local display"
```

実行：
```bash
./scripts/claude_to_ga53pd01.sh /tmp/launch_gui.sh
```

#### 2. ローカルでスクリーンショット取得

```bash
# タイムスタンプ付きでキャプチャ
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
gnome-screenshot -f /tmp/gui_capture_${TIMESTAMP}.png
```

#### 3. Claude Codeで確認

```python
# Read toolで画像読み込み
Read("/tmp/gui_capture_20251109_091405.png")
```

#### 4. クリーンアップ

```bash
#!/bin/bash
# /tmp/cleanup_gui.sh

echo "Cleaning up GUI process..."
kill <PID>
```

### 注意事項

- **DISPLAY変数**: ga53pd01は`10.108.64.21:16.0`、ローカルは`:2`
- **X11転送**: SSH設定で`ForwardX11 yes`が必要（既に設定済み）
- **プロセス管理**: バックグラウンドプロセスは必ずクリーンアップ
- **タイムアウト**: GUIツールの起動には5-10秒程度待つ
- **スクリーンショットツール**: `gnome-screenshot`を使用（ローカル環境）

### トラブルシューティング

#### GUIが表示されない場合

```bash
# DISPLAY変数確認
echo $DISPLAY

# X11転送確認
xdpyinfo 2>&1 | head -5

# SSH X11転送確認（ローカル）
ssh -X henmi@ga53pd01 "echo \$DISPLAY"
```

#### スクリーンショットが撮れない場合

```bash
# gnome-screenshotの確認
which gnome-screenshot

# 権限確認
ls -la /tmp/gui_capture_*.png
```

## 注意事項

- リモート環境(ga53pd01/Palladium)は外部ネットワークアクセスが制限されているため、すべての依存関係は事前に準備が必要
- SSH同期実行は短〜中時間タスク向け（2-3秒のオーバーヘッド）
- 長時間タスクの場合は`USE_GITHUB=1`モードを使用
- hornetディレクトリの変更は、必要に応じて上流にpush
