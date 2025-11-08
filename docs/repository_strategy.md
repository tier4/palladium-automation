# リポジトリ配置戦略

## 背景

現在のプロジェクト:
- **ローカルパス**: `/home/khenmi/palladium-automation`
- **Git管理**: なし（まだリポジトリ化されていない）
- **結果取得用リポジトリ**: `tier4/gion-automation`（計画中）

---

## 選択肢の比較

### Option 1: 単一リポジトリ統合型 ⭐ **推奨**

プロジェクト本体と結果取得を同一リポジトリで管理

```
tier4/gion-automation/
├── scripts/              # 自動化スクリプト
│   ├── etx_automation.sh
│   ├── capture_etx_window.sh
│   └── claude_to_etx.sh
├── mcp-servers/          # MCPサーバー
│   └── etx-automation/
├── results/              # ETXからの実行結果（Git管理）
│   ├── task_20251107_result.txt
│   └── ...
├── .claude/
│   └── etx_tasks/
├── docs/
├── CLAUDE.md
└── README.md
```

#### ローカル配置
```bash
/home/khenmi/palladium-automation/  # 現在のディレクトリ
```

#### ETXリモート配置
```bash
/home/henmi/gion-automation/    # ETX側にクローン
```

#### メリット
- ✅ **シンプル**: 1つのリポジトリで完結
- ✅ **バージョン管理**: スクリプトと結果を一元管理
- ✅ **共有しやすい**: チーム全体で利用可能
- ✅ **CI/CD統合**: GitHub Actionsで自動化可能
- ✅ **ドキュメント集約**: READMEとWikiで全体を説明

#### デメリット
- ⚠️ `results/` ディレクトリが大きくなる可能性
  - 対策: 古い結果を定期的にアーカイブ
- ⚠️ ETXとローカルで同じリポジトリを扱う
  - 対策: ブランチ戦略で分離（後述）

---

### Option 2: 分離リポジトリ型

プロジェクト本体と結果を別リポジトリで管理

#### プロジェクト本体
```
tier4/palladium-claude/
├── scripts/
├── mcp-servers/
├── docs/
├── CLAUDE.md
└── README.md
```

#### 結果専用リポジトリ
```
tier4/gion-automation-results/
└── results/
    ├── task_20251107_result.txt
    └── ...
```

#### ローカル配置
```bash
/home/khenmi/palladium-claude/           # プロジェクト本体
/home/khenmi/palladium-claude/workspace/
└── etx_results/  → tier4/gion-automation-results
```

#### ETXリモート配置
```bash
/home/henmi/.etx_tmp/
└── etx_results/  → tier4/gion-automation-results
```

#### メリット
- ✅ **分離**: プロジェクトと結果を独立管理
- ✅ **軽量**: 各リポジトリが小さい
- ✅ **権限管理**: 結果リポジトリのアクセス制御が容易

#### デメリット
- ❌ **複雑**: 2つのリポジトリを管理
- ❌ **同期**: バージョン間の整合性確保が難しい
- ❌ **セットアップ**: 初期設定が煩雑

---

### Option 3: モノレポ + サブモジュール型

プロジェクトをモノレポ化し、結果をサブモジュール管理

```
tier4/gion-automation/
├── automation/           # プロジェクト本体（このディレクトリ）
│   ├── scripts/
│   └── mcp-servers/
└── results/              # Git submodule → tier4/gion-automation-results
    └── (別リポジトリ)
```

#### メリット
- ✅ 統合と分離のバランス

#### デメリット
- ❌ **Git submodule**: 扱いが複雑
- ❌ **学習コスト**: チームメンバーの理解が必要
- ❌ **オーバーエンジニアリング**: このプロジェクトには不要

---

## 推奨構成: Option 1（単一リポジトリ統合型）

### 理由

1. **シンプルさ**: 初期セットアップと日常運用が簡単
2. **チーム協業**: 全員が同じリポジトリをクローンするだけ
3. **トレーサビリティ**: スクリプト変更と結果が同じ履歴に残る
4. **既存の `tier4/gion-automation`**: すでに存在するならそのまま活用

### 具体的な配置

#### ローカル環境

```bash
# 現在のディレクトリをGit管理下に
cd /home/khenmi/palladium-automation

# リモートリポジトリを追加
git init
git remote add origin https://github.com/tier4/gion-automation.git

# または既存リポジトリをクローン
cd /home/khenmi
git clone https://github.com/tier4/gion-automation.git palladium-automation
cd palladium-automation
```

#### ETXリモート環境

```bash
# ETX Xtermで実行
cd /home/henmi
git clone https://github.com/tier4/gion-automation.git

# または軽量クローン（結果アップロードのみ）
cd /home/henmi/.etx_tmp
git clone --depth=1 https://github.com/tier4/gion-automation.git etx_results
```

---

## ディレクトリ構造詳細

### 統合後のリポジトリ構造

```
tier4/gion-automation/
├── .github/
│   └── workflows/        # CI/CD（オプション）
│       └── cleanup-old-results.yml
├── .claude/
│   └── etx_tasks/        # Claude Code一時タスク（Git管理外）
├── scripts/              # 自動化スクリプト
│   ├── etx_automation.sh
│   ├── capture_etx_window.sh
│   ├── claude_to_etx.sh
│   └── xwd_to_png.py
├── mcp-servers/          # MCPサーバー
│   └── etx-automation/
│       ├── index.js
│       └── package.json
├── results/              # ETX実行結果（Git管理）✨
│   ├── .gitkeep
│   ├── 2025-11-07/       # 日付ごとに整理（オプション）
│   │   ├── task_001_result.txt
│   │   └── task_002_result.txt
│   └── README.md         # 結果ファイルの説明
├── workspace/            # ローカル作業用（Git管理外）
│   └── etx_results/      # GitHub同期用（シンボリックリンク → ../results）
├── docs/
│   ├── setup.md
│   ├── plan.md
│   ├── github_integration_plan.md
│   └── repository_strategy.md  # このファイル
├── .gitignore
├── CLAUDE.md
├── README.md
└── package.json          # プロジェクトメタデータ（オプション）
```

### .gitignore の更新

```gitignore
# Claude Code一時ファイル
.claude/etx_tasks/*
!.claude/etx_tasks/.gitkeep

# ワークスペース（ローカル作業用）
workspace/etx_results/*
!workspace/etx_results/.gitkeep

# Node.js
node_modules/
mcp-servers/*/node_modules/

# 一時ファイル
*.tmp
*.log
*.xwd
*.png
!docs/test_screenshots/*.png

# 環境変数
.env
.env.local
```

---

## ブランチ戦略

複数環境（ローカル、ETX）で同じリポジトリを扱うため、ブランチを活用：

### ブランチ構成

```
main                    # 本番環境・安定版
  ├── develop          # 開発版
  ├── feature/*        # 機能開発
  └── results/*        # 結果専用ブランチ（オプション）
```

### ワークフロー

#### ローカル環境（開発）
```bash
# 開発ブランチで作業
git checkout develop
# スクリプト編集
git add scripts/
git commit -m "feat: improve ETX automation"
git push origin develop

# 安定版をmainにマージ
git checkout main
git merge develop
git push origin main
```

#### ETXリモート環境（結果アップロード）
```bash
# 結果をmainブランチに直接push
cd /home/henmi/.etx_tmp/etx_results
git checkout main
git add results/task_20251107_result.txt
git commit -m "ETX Task Result: task_20251107_result.txt"
git push origin main
```

#### コンフリクト回避策

1. **ファイル分離**: スクリプトと結果ファイルは別ディレクトリ
2. **タイムスタンプ付きファイル名**: 重複を防止
3. **pull前にpush**: ETXから結果をpushする際は常に `git pull --rebase` を実行

---

## セットアップ手順

### Step 1: リポジトリの初期化（既存リポジトリがない場合）

```bash
# ローカル環境で実行
cd /home/khenmi/palladium-automation

# Git初期化
git init

# 初回コミット
git add .
git commit -m "Initial commit: Palladium Claude Code integration"

# GitHubリポジトリ作成（GitHub Webで実行）
# https://github.com/tier4/new
# リポジトリ名: gion-automation

# リモート追加
git remote add origin https://github.com/tier4/gion-automation.git
git branch -M main
git push -u origin main
```

### Step 2: ローカル環境のセットアップ

```bash
# 既存リポジトリがある場合はクローン
cd /home/khenmi
git clone https://github.com/tier4/gion-automation.git palladium-automation
cd palladium-automation

# MCP Serverセットアップ
cd mcp-servers/etx-automation
npm install
cd ../..

# 結果ディレクトリの作成
mkdir -p results
touch results/.gitkeep

# workspace/etx_results をシンボリックリンク化（オプション）
mkdir -p workspace
ln -s ../results workspace/etx_results
```

### Step 3: ETXリモート環境のセットアップ

```bash
# ETX Xtermで実行
cd /home/henmi

# 軽量クローン（結果アップロード専用）
git clone --depth=1 https://github.com/tier4/gion-automation.git

# または作業用に.etx_tmpに配置
cd /home/henmi/.etx_tmp
git clone --depth=1 https://github.com/tier4/gion-automation.git etx_results
cd etx_results

# Git設定
git config user.name "ETX Automation"
git config user.email "etx@automation.local"

# 結果ディレクトリ確認
ls -la results/
```

### Step 4: スクリプトの修正

`scripts/claude_to_etx.sh` のラッパースクリプトを修正：

```bash
# リポジトリパスの設定
REPO_PATH="$HOME/gion-automation"  # または $HOME/.etx_tmp/etx_results

# ラッパースクリプト内
cd "${REPO_PATH}" || exit 1
git pull origin main
mkdir -p results
cp "${RESULT_PATH}" results/
git add results/
git commit -m "ETX Task Result: ${RESULT_FILE}"
git push origin main
```

---

## 既存リポジトリがある場合

### tier4/gion-automation が既に存在する場合

#### Option A: 既存リポジトリに統合

```bash
# ローカルで既存リポジトリをクローン
cd /home/khenmi
git clone https://github.com/tier4/gion-automation.git palladium-automation
cd palladium-automation

# 現在のファイルをマージ
cp -r /home/khenmi/palladium-automation_old/* .
git add .
git commit -m "feat: integrate Palladium Claude Code automation"
git push origin main
```

#### Option B: 新しいディレクトリに配置

```bash
# 既存リポジトリの構造を確認
git clone https://github.com/tier4/gion-automation.git
cd gion-automation
ls -la

# automation/ サブディレクトリを作成
mkdir -p automation
mv scripts mcp-servers docs CLAUDE.md README.md automation/

# 結果ディレクトリは別途
mkdir -p results

git add .
git commit -m "refactor: reorganize into automation/ subdirectory"
git push origin main
```

---

## 移行計画

### Phase 1: リポジトリ準備（今回）

1. ✅ `tier4/gion-automation` の確認または作成
2. ✅ 現在のファイルをリポジトリに追加
3. ✅ `.gitignore` の設定
4. ✅ 初回コミット・プッシュ

### Phase 2: ローカル環境統合

1. ローカルで `git clone` または `git init`
2. MCPサーバーのセットアップ
3. 動作確認

### Phase 3: ETXリモート環境統合

1. ETX Xtermで軽量クローン
2. Git認証設定
3. 結果アップロードテスト

### Phase 4: GitHub統合機能実装

1. `scripts/claude_to_etx.sh` の修正
2. ラッパースクリプトのリポジトリパス設定
3. エンドツーエンドテスト

---

## まとめ

### 推奨構成

| 項目 | 内容 |
|------|------|
| **リポジトリ** | `tier4/gion-automation`（単一リポジトリ） |
| **ローカルパス** | `/home/khenmi/palladium-automation` |
| **ETXパス** | `/home/henmi/.etx_tmp/etx_results` |
| **結果ディレクトリ** | `results/`（Git管理） |
| **ブランチ戦略** | `main`（結果とスクリプト共存） |

### 次のステップ

1. `tier4/gion-automation` が存在するか確認
2. 存在する場合: 既存内容を確認
3. 存在しない場合: 新規作成
4. ローカル環境でGit初期化
5. ETX環境でクローン設定
