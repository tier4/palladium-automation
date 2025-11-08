# tier4/gion への統合プラン

## 現状分析

### 既存の tier4/gion プロジェクト

```
tier4/gion/
├── CLAUDE.md           # 既存のClaude向けガイド
├── README.md           # 既存のプロジェクト概要
├── RELEASE_NOTE.md
├── claudedocs/         # 既存のドキュメント
├── common/             # 共通ファイル
├── doc/                # ドキュメント
├── filelist/
├── hdl/                # Hardware Description Language
├── ip_xact/
├── lint/
├── sim/                # シミュレーション
├── syn/                # 合成
└── verify/             # 検証
```

**特徴**: HDL開発プロジェクト（Hardware/Verification向け）

### 統合する自動化ツール

```
palladium-automation/
├── scripts/            # ETX自動化スクリプト
├── mcp-servers/        # Claude Code MCP統合
├── results/            # 自動化実行結果（新規）
├── .claude/            # Claude Code設定
├── docs/               # 自動化ツールドキュメント
├── CLAUDE.md           # 自動化ツール向けガイド
└── README.md           # 自動化ツール概要
```

**特徴**: ETX/Palladium自動化ツール

---

## 統合戦略の比較

### Option A: トップレベル統合 ⚠️ **非推奨**

すべてをトップレベルに配置

```
tier4/gion/
├── CLAUDE.md           # ⚠️ 衝突: 既存 vs 自動化
├── README.md           # ⚠️ 衝突: 既存 vs 自動化
├── common/             # 既存
├── hdl/                # 既存
├── sim/                # 既存
├── scripts/            # ✨ 新規: 自動化スクリプト
├── mcp-servers/        # ✨ 新規: MCP統合
├── results/            # ✨ 新規: 実行結果
├── .claude/            # ✨ 新規
└── docs/               # ⚠️ 衝突の可能性
```

**問題点**:
- ❌ `CLAUDE.md` が衝突（既存のHDL向け vs 自動化ツール向け）
- ❌ `README.md` が衝突（プロジェクト概要 vs 自動化ツール説明）
- ❌ `docs/` の内容が混在（HDL vs 自動化）
- ❌ プロジェクトの責任が不明確

---

### Option B: サブディレクトリ統合 ⭐ **推奨**

自動化ツールを専用ディレクトリに配置

```
tier4/gion/
├── CLAUDE.md           # 既存（プロジェクト全体向け - 統合版に更新）
├── README.md           # 既存（プロジェクト全体 - 自動化ツール追記）
├── RELEASE_NOTE.md
├── claudedocs/         # 既存
├── common/             # 既存
├── doc/                # 既存
├── hdl/                # 既存
├── sim/                # 既存
├── verify/             # 既存
│
├── automation/         # ✨ 新規: 自動化ツール専用ディレクトリ
│   ├── README.md       # 自動化ツールの詳細説明
│   ├── scripts/        # ETX自動化スクリプト
│   │   ├── etx_automation.sh
│   │   ├── capture_etx_window.sh
│   │   └── claude_to_etx.sh
│   ├── mcp-servers/    # Claude Code MCP統合
│   │   └── etx-automation/
│   ├── .claude/        # Claude Code設定
│   │   └── etx_tasks/
│   ├── docs/           # 自動化ツールドキュメント
│   │   ├── setup.md
│   │   ├── plan.md
│   │   └── github_integration_plan.md
│   └── workspace/      # ローカル作業用
│
└── results/            # ✨ 新規: 自動化実行結果（トップレベル）
    ├── README.md       # 結果ファイルの説明
    ├── .gitkeep
    └── etx/            # ETXからの結果
        └── 2025-11-07/
            └── task_001_result.txt
```

**メリット**:
- ✅ **分離**: HDLプロジェクトと自動化ツールが明確に分離
- ✅ **衝突なし**: ファイル名の衝突を回避
- ✅ **責任明確**: 各ディレクトリの役割が明確
- ✅ **拡張性**: 将来的に他の自動化ツールも追加可能
- ✅ **既存への影響最小**: HDL開発者は `automation/` を意識する必要なし

**デメリット**:
- ⚠️ パスが少し長くなる（`automation/scripts/etx_automation.sh`）
  - 対策: シェルエイリアスやスクリプト内で相対パス使用

---

### Option C: 別リポジトリ維持

`tier4/gion` と `tier4/palladium-automation` を分離

```
tier4/gion/              # 既存プロジェクト（変更なし）
└── (既存の構造のまま)

tier4/palladium-automation/   # 新規リポジトリ
├── scripts/
├── mcp-servers/
├── results/
└── docs/
```

**メリット**:
- ✅ 完全分離
- ✅ 既存プロジェクトへの影響ゼロ

**デメリット**:
- ❌ 連携が複雑
- ❌ バージョン管理が別々
- ❌ チームでの共有が煩雑

---

## 推奨: Option B（サブディレクトリ統合）

### 理由

1. **既存との共存**: HDLプロジェクトと自動化ツールが明確に分離
2. **ファイル衝突の回避**: `CLAUDE.md`, `README.md`, `docs/` の衝突なし
3. **単一リポジトリ**: バージョン管理が統一
4. **結果の共有**: `results/` をトップレベルに配置して全体で共有

---

## 統合後のディレクトリ詳細

### トップレベルファイルの更新

#### CLAUDE.md の統合

既存の `CLAUDE.md` に自動化ツールのセクションを追加：

```markdown
# CLAUDE.md

## gion プロジェクト概要

（既存の内容）

## ETX/Palladium 自動化ツール

このリポジトリには、ETX/Palladium環境での自動化ツールが含まれています。

詳細は [`automation/README.md`](automation/README.md) を参照してください。

### クイックスタート

```bash
# ETXで単一コマンド実行
./automation/scripts/etx_automation.sh exec 'hostname'

# スクリプト実行
./automation/scripts/etx_automation.sh script ./my_script.sh

# 画面キャプチャ
./automation/scripts/capture_etx_window.sh
```

### MCPサーバー統合

Claude Codeから自動化ツールを利用するには:

```bash
cd automation/mcp-servers/etx-automation
npm install
cd ../../..

# Claude Code (CLI) に追加
claude mcp add --transport stdio etx-automation -- node $(pwd)/automation/mcp-servers/etx-automation/index.js
```

詳細なセットアップ手順: [`automation/docs/setup.md`](automation/docs/setup.md)
```

#### README.md の更新

既存の `README.md` に自動化ツールのセクションを追加：

```markdown
# gion

（既存の内容）

## ETX/Palladium 自動化ツール

ETX環境での開発を効率化するための自動化ツールを提供しています。

- **GUI自動操作**: xdotoolによるETX Xterm制御
- **画面キャプチャ**: 実行結果の視覚的確認
- **Claude Code統合**: MCPサーバーによる自動化
- **GitHub結果取得**: 実行結果の自動回収

詳細: [automation/README.md](automation/README.md)
```

---

## 統合手順

### Phase 1: ローカル環境での統合

#### Step 1: 既存リポジトリのクローン

```bash
# tier4/gion を新しい場所にクローン
cd /home/khenmi
git clone https://github.com/tier4/gion.git

# または既存のクローンを使用
cd /home/khenmi/gion
git pull origin main
```

#### Step 2: 自動化ツールの統合

```bash
cd /home/khenmi/gion

# automation/ ディレクトリ作成
mkdir -p automation

# palladium-automation の内容をコピー
cp -r /home/khenmi/palladium-automation/scripts automation/
cp -r /home/khenmi/palladium-automation/mcp-servers automation/
cp -r /home/khenmi/palladium-automation/.claude automation/
cp -r /home/khenmi/palladium-automation/docs automation/
cp -r /home/khenmi/palladium-automation/workspace automation/

# automation/README.md を作成
cp /home/khenmi/palladium-automation/README.md automation/README.md

# results/ ディレクトリをトップレベルに作成
mkdir -p results/etx
touch results/.gitkeep
cat > results/README.md << 'EOF'
# ETX/Palladium 実行結果

このディレクトリには、ETX環境での自動化スクリプト実行結果が保存されます。

## ディレクトリ構造

```
results/
└── etx/                    # ETX実行結果
    └── YYYY-MM-DD/         # 日付ごとに整理
        └── task_NNN_result.txt
```

## 結果ファイルの命名規則

`{task_name}_{timestamp}_result.txt`

例: `build_test_20251107_140530_result.txt`
EOF
```

#### Step 3: .gitignore の更新

```bash
cd /home/khenmi/gion

# 既存の .gitignore に追記
cat >> .gitignore << 'EOF'

# ========================================
# ETX/Palladium 自動化ツール
# ========================================

# Claude Code一時ファイル
automation/.claude/etx_tasks/*
!automation/.claude/etx_tasks/.gitkeep

# ワークスペース（ローカル作業用）
automation/workspace/etx_results/*
!automation/workspace/etx_results/.gitkeep

# 自動化ツール用Node.js
automation/mcp-servers/*/node_modules/

# キャプチャ画像（一時）
automation/*.xwd
automation/*.png
!automation/docs/test_screenshots/*.png

# 一時ファイル
automation/*.tmp
EOF
```

#### Step 4: トップレベルファイルの更新

```bash
# CLAUDE.md の更新（手動編集が必要）
# 既存内容を保持しつつ、自動化ツールのセクションを追加

# README.md の更新（手動編集が必要）
# 既存内容を保持しつつ、自動化ツールのセクションを追加
```

#### Step 5: コミット・プッシュ

```bash
cd /home/khenmi/gion

git add automation/ results/
git add .gitignore

git commit -m "feat: integrate ETX/Palladium automation tools

Add automation tools for ETX environment:
- GUI automation scripts (xdotool)
- Screen capture functionality
- Claude Code MCP server integration
- GitHub result collection (planned)

Directory structure:
- automation/: All automation tools
- results/: ETX execution results
"

git push origin main
```

---

### Phase 2: ETXリモート環境のセットアップ

#### Step 1: ETXでリポジトリをクローン

```bash
# ETX Xtermで実行
cd /home/henmi

# 軽量クローン（結果アップロード用）
git clone --depth=1 https://github.com/tier4/gion.git

# Git設定
cd gion
git config user.name "ETX Automation"
git config user.email "etx@automation.local"
```

#### Step 2: 結果ディレクトリの確認

```bash
cd /home/henmi/gion
ls -la results/etx/

# 日付ディレクトリの作成
mkdir -p results/etx/$(date +%Y-%m-%d)
```

---

### Phase 3: スクリプトのパス修正

#### automation/scripts/claude_to_etx.sh の修正

```bash
# リポジトリパスを更新
REPO_PATH="$HOME/gion"         # 変更: palladium-automation → gion
RESULTS_DIR="$REPO_PATH/results/etx"  # 変更

# ラッパースクリプト内
cd "${REPO_PATH}" || exit 1
git pull origin main
mkdir -p results/etx/$(date +%Y-%m-%d)
cp "${RESULT_PATH}" results/etx/$(date +%Y-%m-%d)/
git add results/
git commit -m "ETX Task Result: ${RESULT_FILE}"
git push origin main
```

#### automation/mcp-servers/etx-automation/index.js の修正

```javascript
// スクリプトパスを更新
const PROJECT_ROOT = path.resolve(__dirname, '../..');  // automation/
const AUTOMATION_SCRIPT = path.join(PROJECT_ROOT, 'scripts/etx_automation.sh');
const CLAUDE_TO_ETX_SCRIPT = path.join(PROJECT_ROOT, 'scripts/claude_to_etx.sh');
const CAPTURE_SCRIPT = path.join(PROJECT_ROOT, 'scripts/capture_etx_window.sh');
```

---

## ファイル構造の最終確認

### 統合後の完全な構造

```
tier4/gion/
│
├── CLAUDE.md                    # 更新: 自動化ツールのセクション追加
├── README.md                    # 更新: 自動化ツールのセクション追加
├── RELEASE_NOTE.md              # 既存
│
├── claudedocs/                  # 既存
├── common/                      # 既存
├── doc/                         # 既存
├── filelist/                    # 既存
├── hdl/                         # 既存
├── ip_xact/                     # 既存
├── lint/                        # 既存
├── sim/                         # 既存
├── syn/                         # 既存
├── verify/                      # 既存
│
├── automation/                  # ✨ 新規: 自動化ツール
│   ├── README.md                # 自動化ツール詳細
│   ├── .claude/
│   │   └── etx_tasks/
│   ├── scripts/
│   │   ├── etx_automation.sh
│   │   ├── capture_etx_window.sh
│   │   └── claude_to_etx.sh
│   ├── mcp-servers/
│   │   └── etx-automation/
│   │       ├── index.js
│   │       └── package.json
│   ├── docs/
│   │   ├── setup.md
│   │   ├── plan.md
│   │   ├── github_integration_plan.md
│   │   └── repository_strategy.md
│   └── workspace/
│       └── etx_results/
│
└── results/                     # ✨ 新規: 実行結果（Git管理）
    ├── README.md
    ├── .gitkeep
    └── etx/
        └── 2025-11-07/
            └── task_001_result.txt
```

---

## 利用方法（統合後）

### ローカル環境

```bash
# プロジェクトのクローン
cd /home/khenmi
git clone https://github.com/tier4/gion.git
cd gion

# MCPサーバーのセットアップ
cd automation/mcp-servers/etx-automation
npm install
cd ../../..

# Claude Code (CLI) への追加
claude mcp add --transport stdio etx-automation -- \
  node /home/khenmi/gion/automation/mcp-servers/etx-automation/index.js

# スクリプト実行
./automation/scripts/etx_automation.sh exec 'hostname'

# 画面キャプチャ
./automation/scripts/capture_etx_window.sh
```

### ETXリモート環境

```bash
# プロジェクトのクローン
cd /home/henmi
git clone --depth=1 https://github.com/tier4/gion.git
cd gion

# Git設定
git config user.name "ETX Automation"
git config user.email "etx@automation.local"

# 結果ディレクトリ確認
ls -la results/etx/
```

---

## 移行計画

### Phase 1: 統合準備（今回）✅
1. ✅ リポジトリ戦略の策定
2. ✅ ディレクトリ構造の設計
3. ✅ 統合手順の作成

### Phase 2: ローカル統合（次回）
1. `tier4/gion` をクローン
2. `automation/` ディレクトリに統合
3. トップレベルファイルの更新
4. コミット・プッシュ

### Phase 3: ETX統合
1. ETXで `tier4/gion` をクローン
2. Git認証設定
3. 結果アップロードテスト

### Phase 4: GitHub統合機能実装
1. スクリプトのパス修正
2. ラッパースクリプトの調整
3. エンドツーエンドテスト

---

## まとめ

### 推奨構成: Option B（サブディレクトリ統合）

| 項目 | 内容 |
|------|------|
| **リポジトリ** | `tier4/gion`（既存） |
| **自動化ツール** | `automation/` サブディレクトリ |
| **実行結果** | `results/etx/` トップレベル |
| **ローカルパス** | `/home/khenmi/gion` |
| **ETXパス** | `/home/henmi/gion` |

### メリット
- ✅ 既存プロジェクトと自動化ツールが明確に分離
- ✅ ファイル衝突の回避
- ✅ 単一リポジトリで管理
- ✅ チーム全体で共有可能

### 次のステップ
1. `tier4/gion` の現在の `CLAUDE.md` と `README.md` を確認
2. 統合方針の最終確認
3. Phase 2（ローカル統合）の実行
