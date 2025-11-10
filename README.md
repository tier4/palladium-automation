# Palladium Automation（β版）

**Hornet GPU/GPGPU開発のラッパープロジェクト**。SSH経由のga53pd01 Palladiumエミュレータ制御と、Serena MCPによるVerilog/SystemVerilog解析を統合し、RTL開発からシミュレーション実行までをワンストップで実現します。

## 背景

Cadenceのポリシーにより、**Palladiumエミュレーション環境（チャンバー）にClaude Codeを直接インストールできない**という制約があります。

この制約に対し、本プロジェクトでは以下のアプローチを採用しています：

- **接続元（ローカル: t4_head）**: Claude Codeを実行し、外部APIにアクセス可能
- **接続先（リモート: Palladiumチャンバー）**: Claude Code不要、SSH経由で制御

この構成により、Palladiumチャンバー側でClaude Codeが外部にアクセスできなくても、ローカルのClaude CodeからSSH経由でPalladiumエミュレーション環境を統合的に制御・デバッグできる環境を実現しています。

## 重要: プロジェクト内完結の原則

**このプロジェクトはすべての依存関係とツールをプロジェクト内で管理します。**

- ✅ グローバルインストール不要
- ✅ プロジェクトをクローンしてSSH設定とMCPインストールを行うだけで動作
- ✅ チームメンバー全員が同じ環境で作業可能
- ✅ システム全体の環境を汚染しない

## 概要

このプロジェクトは、特殊なネットワーク制約下で、**SSH経由のスクリプト実行**による自動化を実現します。

### アーキテクチャ

```
[ローカル RHEL8 (ip-172-17-34-126)]
    ↓ Claude Code動作
    ↓ スクリプト生成
    ↓ SSH stdin経由でga53pd01に転送
    →→→ [リモート ga53pd01 (Palladium Compute Server)]
            ↓ 同期実行
            ↓ 標準出力・標準エラー出力
            ↓
[ローカル] ←←← SSH経由でリアルタイム表示 + ローカル保存
```

### 主要機能

- ✅ **Hornet統合**: hornetプロジェクトをgit cloneで組み込み
- ✅ **Serena MCP**: Verilog/SystemVerilogのシンボルベース解析
- ✅ **自動Git同期**: ローカルとga53pd01のhornetを自動同期・検証
- ✅ **SSH同期実行方式**: 高速（2-3秒）・シンプル・GUI操作不要
- ✅ **リアルタイム出力**: 実行中の出力をその場で確認
- ✅ **ローカルアーカイブ**: `.archive/YYYYMM/` に自動保存
- ✅ **ワンストップ開発**: RTL解析→スクリプト生成→実行→結果分析

## ディレクトリ構造

```
palladium-automation/
├── hornet/                    # git clone されたhornetプロジェクト
│   ├── src/                   # Verilog/SystemVerilog RTL
│   ├── eda/                   # EDA tool configs, testbenches
│   └── tb/                    # Testbenches
├── scripts/
│   ├── claude_to_ga53pd01.sh  # SSH統合スクリプト（推奨）
│   └── .legacy/               # レガシースクリプト（xdotool方式）
├── .serena/                   # Serena MCP設定
│   ├── project.yml            # Verilog言語設定
│   └── memories/              # プロジェクトメモリ
├── workspace/
│   └── etx_results/
│       └── .archive/          # ローカル永続保存（YYYYMM別）
├── docs/
│   ├── setup.md               # セットアップガイド
│   ├── mcp_setup_cli.md       # Serena MCP設定ガイド
│   ├── ssh_direct_retrieval_test.md  # SSH直接取得テスト結果
│   └── .legacy/               # レガシードキュメント
├── CLAUDE.md                  # Claude Code向けリポジトリガイド
└── README.md                  # このファイル
```

**注意**: `hornet/`ディレクトリは`.gitignore`に追加されており、このリポジトリのGit管理対象外です。

## 環境要件

### ローカル環境 (ip-172-17-34-126)
- OS: RHEL8
- 必須ツール:
  - SSH (公開鍵認証設定済み)
  - Git
  - Bash

### リモート環境 (ga53pd01)
- OS: RHEL8
- Palladium Compute Server
- SSH経由でアクセス可能（ProxyJump設定推奨）
- バスティオンサーバー経由: 10.108.64.1 → ga53pd01

## クイックスタート

> 📖 **詳細なセットアップ手順**: [docs/setup.md](docs/setup.md) を参照してください

### 1. SSH公開鍵認証の設定

```bash
# SSH鍵生成（まだ持っていない場合）
ssh-keygen -t ed25519 -C "your_email@example.com"

# バスティオンサーバーに公開鍵を登録
ssh-copy-id henmi@10.108.64.1

# バスティオンサーバー経由でga53pd01に公開鍵を登録
ssh henmi@10.108.64.1
ssh-copy-id henmi@ga53pd01
exit

# ~/.ssh/config にProxyJump設定を追加
# 詳細は docs/setup.md を参照
```

### 2. プロジェクトのクローン

```bash
cd ~
git clone https://github.com/tier4/palladium-automation.git
cd palladium-automation
```

### 3. 環境変数の設定

```bash
# .env.exampleをコピーして自分の環境に合わせて編集
cp .env.example .env
nano .env
```

**設定例**:
```bash
REMOTE_HOST=ga53pd01
REMOTE_USER=your_username
PROJECT_NAME=your_project_name
BASTION_HOST=10.108.64.1
```

**重要**: `.env` ファイルはGit管理対象外なので、各自の環境に合わせて設定してください。

### 4. Hornetプロジェクトのクローン

```bash
# palladium-automation内にhornetをクローン
git clone https://github.com/tier4/hornet.git
```

### 5. MCP設定（オプション）

このプロジェクトでは以下のMCPサーバーを利用できます。各自の環境で必要に応じてインストールしてください。

#### Serena MCP - Verilog/SystemVerilog解析

RTL解析機能が必要な場合：

```bash
# Serena MCPを追加
claude-serena
# または手動で ~/.claude.json に設定
```

**機能**: hornetプロジェクトのVerilog/SystemVerilogコードのシンボルベース解析

詳細は [docs/mcp_setup_cli.md](docs/mcp_setup_cli.md) を参照してください。

#### Playwright MCP - ブラウザ自動化

Cadence Supportサイトのドキュメント参照が必要な場合：

```bash
# Claude Desktopで自動的に利用可能
# 追加のインストール・設定は不要
```

**機能**: Palladium/IXCOMドキュメントの検索・閲覧の自動化

### 6. 接続テスト

```bash
# ga53pd01への接続確認
ssh ga53pd01 'hostname'
# 出力: ga53pd01
```

これでセットアップ完了です！詳細な手順は [docs/setup.md](docs/setup.md) を参照してください。

## 使用方法

### 初回セットアップ: カスタムタスクスクリプトの作成

**重要**: サンプルスクリプト（`ga53pd01_example_task.sh`）は直接編集せず、コピーして使用してください。

```bash
# サンプルスクリプトをコピーして、自分用のスクリプトを作成
cp scripts/ga53pd01_example_task.sh scripts/ga53pd01_task.sh

# 必要に応じて編集（ターゲット、パス等）
vi scripts/ga53pd01_task.sh
```

**理由**:
- ✅ `git pull`時にコンフリクトしない
- ✅ サンプルは常に最新版に更新される
- ✅ ユーザー固有の設定を保持できる
- ✅ 複数のタスクスクリプトを作成できる

**注意**: `scripts/*_task.sh`は`.gitignore`に含まれており、Git管理対象外です。

### SSH統合スクリプト（推奨）

```bash
# ga53pd01でスクリプトを実行（SSH同期実行）
./scripts/claude_to_ga53pd01.sh scripts/ga53pd01_task.sh

# デバッグモード
DEBUG=1 ./scripts/claude_to_ga53pd01.sh scripts/ga53pd01_task.sh

# ターゲット指定
TARGET=zcu102 ./scripts/claude_to_ga53pd01.sh scripts/ga53pd01_task.sh
```

**特徴**:
- 高速（2-3秒）・安定（GUI操作不要）
- リアルタイムで出力表示
- ローカルアーカイブに自動保存（`.archive/YYYYMM/`）
- リモートにファイルを残さない

### Claude Codeによる自動化（推奨）

Claude Codeに自然言語で指示することで、コミット・プッシュ・リモート実行を自動化できます。

#### 基本的な使い方

```
「hornetの変更をコミット＆プッシュして、ga53pd01でkv260ビルドを実行して」
```

**Claude Codeの実行フロー**:

1. **変更確認** - `git status`, `git diff`で変更を確認
2. **コミットメッセージ案の提示** - ユーザーが確認・修正可能
3. **コミット＆プッシュ** - ローカルの変更をリモートにプッシュ
4. **Git同期検証** - `claude_to_ga53pd01.sh`がローカルとリモートを自動検証
   - ✓ 未コミット変更なし
   - ✓ 未プッシュコミットなし
   - ✓ upstream設定済み
5. **リモート実行** - ga53pd01で`git pull` → `scripts/ga53pd01_task.sh`実行
6. **結果保存** - ローカルアーカイブに自動保存

**注意**: `scripts/ga53pd01_task.sh`を事前に作成しておく必要があります（上記「初回セットアップ」参照）。

#### その他の指示例

**ターゲット指定**:
```
「hornetの変更をコミット＆プッシュして、ga53pd01でzcu102ビルドを実行して」
```

**カスタムコミットメッセージ**:
```
「hornetの変更を"feat: add new pipeline stage"でコミット＆プッシュして、ビルドして」
```

**複数タスク**:
```
「hornetの変更をコミット＆プッシュして、ga53pd01でビルドして、結果を分析して」
```

#### メリット

- ✅ **コミットメッセージを毎回確認・修正できる**
- ✅ **意図しない変更がコミットされない**
- ✅ **適切なコミットメッセージが自動生成される**
- ✅ **柔軟に対応可能**（一部ファイルのみコミット等）
- ✅ **自然言語で直感的に指示できる**

詳細は [docs/setup.md](docs/setup.md) の「Hornet RTL開発ワークフロー」を参照してください。

## トラブルシューティング

### SSH接続エラー

```bash
# SSH鍵確認
ssh-add -l

# ProxyJump設定確認
cat ~/.ssh/config | grep -A5 "Host ga53pd01"

# 手動接続テスト
ssh ga53pd01 'hostname'

# デバッグモードで接続
ssh -v ga53pd01
```

### 実行結果が見つからない

```bash
# アーカイブディレクトリ確認
ls -lh workspace/etx_results/.archive/$(date +%Y%m)/

# 最新の結果ファイルを表示
ls -lt workspace/etx_results/.archive/$(date +%Y%m)/ | head -5
```

## ドキュメント

- [セットアップガイド](docs/setup.md) - 詳細なセットアップ手順
- [Serena MCP設定](docs/mcp_setup_cli.md) - Verilog解析MCPの設定
- [CLAUDE.md](CLAUDE.md) - Claude Code向けガイド
