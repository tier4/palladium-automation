# tier4/hornet 統合戦略の比較

## 前提条件

- **対象**: ETX/Palladium自動化ツール（現在の `palladium-automation`）
- **用途**: `tier4/hornet` の `eda/palladium-t4-sba/` でのPalladiumエミュレーション作業の自動化
- **環境**: ETX/Palladium chamber (RHEL8)

---

## Option 1: tier4/hornet に統合

### パターン 1A: eda/palladium-t4-sba/ 内に統合

```
tier4/hornet/
├── eda/
│   ├── palladium-t4-sba/
│   │   ├── Makefile
│   │   ├── README.md
│   │   ├── regression_palladium.sh
│   │   ├── config.txt
│   │   ├── script/
│   │   │   └── t4_hornet_palladium_sba.tcl
│   │   │
│   │   └── automation/              # ✨ 新規
│   │       ├── README.md
│   │       ├── scripts/
│   │       │   ├── etx_automation.sh
│   │       │   ├── capture_etx_window.sh
│   │       │   └── claude_to_etx.sh
│   │       ├── mcp-servers/
│   │       │   └── etx-automation/
│   │       └── docs/
│   │
│   ├── palladium-mvd-sba/
│   ├── xcelium-t4/
│   └── ...
│
└── results/                         # ✨ 新規（トップレベル）
    └── palladium-t4-sba/
        └── 2025-11-08/
            └── task_001_result.txt
```

#### メリット

✅ **配置の一貫性**
- Palladiumツールが `eda/palladium-t4-sba/` 内に集約
- 関連ファイルが近くにある

✅ **スコープが明確**
- `palladium-t4-sba` 専用であることが明確
- 他のEDAツール（xcelium、genus）と分離

✅ **学習コストが低い**
- Palladium作業者が見つけやすい

#### デメリット

❌ **ディレクトリが複雑化**
- `eda/palladium-t4-sba/automation/` と深い階層
- パスが長くなる

❌ **拡張性の制限**
- 他のPalladium環境（`palladium-mvd-sba`）で再利用しにくい
- xceliumなど他のツールとの共有が困難

❌ **責任の曖昧さ**
- EDAツール設定と自動化スクリプトが混在

---

### パターン 1B: トップレベルに automation/ を配置

```
tier4/hornet/
├── automation/                      # ✨ 新規
│   ├── README.md
│   ├── scripts/
│   │   ├── etx_automation.sh
│   │   ├── capture_etx_window.sh
│   │   └── claude_to_etx.sh
│   ├── mcp-servers/
│   │   └── etx-automation/
│   └── docs/
│
├── results/                         # ✨ 新規
│   ├── palladium-t4-sba/           # Palladium SBA結果
│   ├── palladium-mvd-sba/          # Palladium MVD結果
│   └── xcelium-t4/                 # Xcelium結果（将来）
│
├── eda/
│   ├── palladium-t4-sba/
│   │   ├── Makefile
│   │   ├── README.md
│   │   ├── regression_palladium.sh
│   │   └── script/
│   ├── palladium-mvd-sba/
│   ├── xcelium-t4/
│   └── ...
├── sim/
├── src/
└── README.md                        # 更新: 自動化ツールの説明追加
```

#### メリット

✅ **拡張性が高い**
- すべてのEDAツール（palladium-t4-sba、palladium-mvd-sba、xcelium-t4）で共用可能
- 将来的な拡張に対応しやすい

✅ **責任が明確**
- EDAツール設定: `eda/`
- 自動化ツール: `automation/`
- 実行結果: `results/`

✅ **パスが短い**
- `./automation/scripts/etx_automation.sh`

✅ **hornetプロジェクト全体で利用可能**
- シミュレーション、合成、検証すべてで使える

#### デメリット

⚠️ **プロジェクト本体への影響**
- トップレベルに新ディレクトリ追加
- hornetの既存構造に影響

⚠️ **スコープの拡大**
- Palladium専用から汎用自動化ツールへ
- 責任範囲が広がる

---

## Option 3: 独立した tier4/palladium-automation リポジトリ

```
tier4/palladium-automation/
├── README.md
├── scripts/
│   ├── etx_automation.sh
│   ├── capture_etx_window.sh
│   └── claude_to_etx.sh
├── mcp-servers/
│   └── etx-automation/
├── docs/
│   ├── setup.md
│   ├── usage.md
│   └── integration.md
├── examples/
│   ├── hornet-palladium-sba/
│   │   ├── run_regression.sh
│   │   └── README.md
│   └── gion-palladium/            # 将来の拡張
│       └── README.md
└── results/                       # GitHub経由の結果収集
    ├── hornet/
    │   └── palladium-t4-sba/
    └── gion/
```

### tier4/hornet での利用方法

#### 方法A: Git Submodule

```
tier4/hornet/
├── automation -> palladium-automation/  # Git submodule
├── eda/
│   └── palladium-t4-sba/
│       ├── Makefile
│       └── README.md              # 更新: automation使用方法を追記
└── ...
```

#### 方法B: 独立運用（推奨）

```bash
# ローカル環境
cd /home/khenmi
git clone https://github.com/tier4/hornet.git
git clone https://github.com/tier4/palladium-automation.git

# 自動化ツールから hornet を操作
cd palladium-automation
./scripts/etx_automation.sh exec 'cd /path/to/hornet/eda/palladium-t4-sba && make hornet'
```

### メリット

✅ **完全な独立性**
- hornetプロジェクトへの影響ゼロ
- 他のプロジェクト（gion、他のハードウェアプロジェクト）でも利用可能

✅ **バージョン管理の独立**
- 自動化ツールの更新がhornetに影響しない
- リリースサイクルを分離可能

✅ **責任範囲が明確**
- hornet: HDL/エミュレーション
- palladium-automation: 自動化インフラ

✅ **チーム構成に適合**
- 自動化チームとHDL開発チームの分離
- 権限管理が容易

✅ **汎用性**
- Tier4内の複数プロジェクトで共有
- EDA tools全般の自動化に拡張可能

### デメリット

❌ **セットアップの複雑化**
- 2つのリポジトリをクローン
- パス設定が必要

❌ **統合が弱い**
- hornet固有の設定を別途管理
- ドキュメントが分散

❌ **発見しにくい**
- hornetユーザーが自動化ツールの存在に気づきにくい

---

## 詳細比較表

| 項目 | Option 1A<br>eda/内に統合 | Option 1B<br>トップレベル統合 | Option 3<br>独立リポジトリ |
|------|---------------------------|------------------------------|---------------------------|
| **配置場所** | `eda/palladium-t4-sba/automation/` | `automation/` | `tier4/palladium-automation` |
| **プロジェクト影響** | 小（サブディレクトリのみ） | 中（トップレベル追加） | なし（完全独立） |
| **拡張性** | 低（palladium-t4-sba専用） | 高（hornet全体） | 最高（全プロジェクト） |
| **セットアップ複雑度** | 低 | 低 | 中 |
| **発見しやすさ** | 高（palladium作業者） | 高（hornet全体） | 低（別リポジトリ） |
| **責任の明確さ** | 中（ツールと混在） | 高 | 最高 |
| **バージョン管理** | hornetに依存 | hornetに依存 | 独立 |
| **他プロジェクトでの利用** | 不可 | 困難 | 容易 |
| **保守性** | 中 | 高 | 最高 |

---

## 推奨: **Option 3（独立リポジトリ）**

### 理由

1. **プロジェクト本体へのインパクトがゼロ**
   - hornetの既存構造を変更しない
   - HDL開発者は自動化ツールを意識不要

2. **汎用性と拡張性**
   - 将来的にgionやその他のプロジェクトでも利用可能
   - EDAツール全般（Palladium、Xcelium、VCS等）に対応可能

3. **責任範囲の明確化**
   - 自動化ツール専門のリポジトリ
   - 独立したバージョン管理とリリースサイクル

4. **長期的な保守性**
   - 自動化ツールの更新がhornetに影響しない
   - チーム構成の変化に対応しやすい

5. **Tier4内での共有**
   - 組織全体で自動化インフラを共有
   - ベストプラクティスの蓄積

---

## 実装プラン（Option 3の場合）

### Phase 1: 新規リポジトリ作成

```bash
# ローカルで準備
cd /home/khenmi/palladium-automation

# リポジトリ名を変更
mv /home/khenmi/palladium-automation /home/khenmi/palladium-automation

# Git初期化
cd /home/khenmi/palladium-automation
git init
git add .
git commit -m "Initial commit: Palladium/ETX automation tools"

# GitHubリポジトリ作成（GitHub Webで）
# https://github.com/tier4/new
# Repository name: palladium-automation

# リモート追加
git remote add origin https://github.com/tier4/palladium-automation.git
git branch -M main
git push -u origin main
```

### Phase 2: tier4/hornet との連携

#### hornet/README.md に自動化ツールの説明を追加

```markdown
# Hornet

（既存の内容）

## ETX/Palladium 自動化ツール

Palladiumエミュレーション作業を効率化するための自動化ツールが利用可能です。

**リポジトリ**: [tier4/palladium-automation](https://github.com/tier4/palladium-automation)

### クイックスタート

```bash
# 自動化ツールのクローン
cd /home/khenmi
git clone https://github.com/tier4/palladium-automation.git

# ETXでコマンド実行
cd palladium-automation
./scripts/etx_automation.sh exec 'hostname'

# Palladiumリグレッション実行
./scripts/etx_automation.sh exec 'cd /path/to/hornet/eda/palladium-t4-sba && ./regression_palladium.sh'
```

詳細: [palladium-automation/README.md](https://github.com/tier4/palladium-automation)
```

#### eda/palladium-t4-sba/README.md に自動化ツールの説明を追加

```markdown
# Hornet Emulation by Palladium

（既存の内容）

## Automation Tools

ETX環境での作業を自動化するツールが利用可能です。

詳細: [tier4/palladium-automation](https://github.com/tier4/palladium-automation)

### 自動化例

```bash
# ローカル環境から ETX でリグレッション実行
cd /home/khenmi/palladium-automation
./scripts/claude_to_etx.sh /path/to/run_regression_script.sh

# 実行結果をGitHub経由で自動取得
```
```

### Phase 3: ローカル環境のセットアップ

```bash
# ローカル環境
cd /home/khenmi
git clone https://github.com/tier4/hornet.git
git clone https://github.com/tier4/palladium-automation.git

# 自動化ツールのセットアップ
cd palladium-automation
cd mcp-servers/etx-automation
npm install
cd ../..

# Claude Code (CLI) への追加
claude mcp add --transport stdio etx-automation -- \
  node /home/khenmi/palladium-automation/mcp-servers/etx-automation/index.js
```

### Phase 4: ETX環境のセットアップ

```bash
# ETX Xtermで実行
cd /home/henmi
git clone https://github.com/tier4/hornet.git
git clone --depth=1 https://github.com/tier4/palladium-automation.git

# Git設定
cd palladium-automation
git config user.name "ETX Automation"
git config user.email "etx@automation.local"
```

---

## Option 1B を選択する場合

もし「hornetプロジェクト内で完結させたい」という要件があれば、**Option 1B（トップレベル統合）** も良い選択肢です。

### 推奨する理由

- hornet全体で自動化ツールを利用可能
- palladium-t4-sba、palladium-mvd-sba、xcelium-t4すべてで共用
- パスが短く使いやすい

### 実装プラン（Option 1Bの場合）

```bash
cd /home/khenmi/hornet

# automation/ ディレクトリ作成
mkdir -p automation

# palladium-automation の内容をコピー
cp -r /home/khenmi/palladium-automation/scripts automation/
cp -r /home/khenmi/palladium-automation/mcp-servers automation/
cp -r /home/khenmi/palladium-automation/.claude automation/
cp -r /home/khenmi/palladium-automation/docs automation/
cp /home/khenmi/palladium-automation/README.md automation/README.md

# results/ ディレクトリ作成
mkdir -p results/palladium-t4-sba
mkdir -p results/palladium-mvd-sba

# .gitignore 更新
cat >> .gitignore << 'EOF'

# ========================================
# ETX/Palladium 自動化ツール
# ========================================
automation/.claude/etx_tasks/*
automation/workspace/
automation/*.xwd
automation/*.png
results/*/
EOF

# コミット
git add automation/ results/
git add .gitignore
git commit -m "feat: integrate ETX/Palladium automation tools

Add automation tools for ETX environment:
- GUI automation scripts (xdotool)
- Screen capture functionality
- Claude Code MCP server integration
- GitHub result collection

Directory structure:
- automation/: All automation tools
- results/: Execution results from EDA tools
"

git push origin main
```

---

## まとめ

### 推奨順位

1. **Option 3（独立リポジトリ）** ⭐⭐⭐
   - プロジェクト影響なし
   - 汎用性・拡張性最高
   - 長期的な保守性

2. **Option 1B（トップレベル統合）** ⭐⭐
   - hornet内で完結
   - 統合が強い
   - 発見しやすい

3. **Option 1A（eda/内統合）** ⭐
   - スコープが限定的
   - 拡張性が低い

### 決定のポイント

| 要件 | 推奨オプション |
|------|--------------|
| プロジェクト本体への影響を最小化したい | **Option 3** |
| 将来的にgionでも使いたい | **Option 3** |
| hornet内で完結させたい | **Option 1B** |
| palladium-t4-sba専用で良い | **Option 1A** |

---

## 次のステップ

どのオプションを選択するか決定後:

1. リポジトリ/ディレクトリの作成
2. ファイルの配置
3. ドキュメントの更新
4. セットアップとテスト
