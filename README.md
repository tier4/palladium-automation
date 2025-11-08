# Palladium Automation

ETX/Palladium環境での自動化ツール。Tier4ハードウェアプロジェクト（hornet、gion等）のエミュレーション・検証作業を効率化します。

## 重要: プロジェクト内完結の原則

**このプロジェクトはすべての依存関係とツールをプロジェクト内で管理します。**

- ✅ グローバルインストール不要（`npm link` 等は使用しない）
- ✅ プロジェクトをクローンして `npm install` するだけで動作
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

- ✅ **SSH同期実行方式**: 高速（2-3秒）・シンプル・GUI操作不要
- ✅ **リアルタイム出力**: 実行中の出力をその場で確認
- ✅ **ローカルアーカイブ**: `.archive/YYYYMM/` に自動保存
- ✅ **リモートファイル不要**: SSH接続のみで完結
- ✅ **複数人並行実行対応**: タスクIDで識別

## ディレクトリ構造

```
palladium-automation/
├── scripts/                    # 自動化スクリプト
│   ├── claude_to_ga53pd01.sh  # SSH統合スクリプト（推奨）
│   ├── claude_to_etx.sh       # GUI統合スクリプト（レガシー）
│   ├── etx_automation.sh      # GUI自動操作スクリプト
│   └── capture_etx_window.sh  # ETX画面キャプチャスクリプト
├── .claude/
│   └── etx_tasks/             # Claude Codeが生成したタスクの一時保存
├── workspace/
│   └── etx_results/           # 実行結果アーカイブ
│       └── .archive/          # ローカル永続保存（YYYYMM別）
├── .github/
│   └── workflows/
│       └── cleanup-old-results.yml  # 3日後の自動削除（レガシー）
├── docs/
│   ├── memo.md                # 技術検討メモ
│   ├── setup.md               # セットアップガイド
│   ├── plan.md                # 実装プラン
│   ├── ssh_direct_retrieval_test.md  # SSH直接取得テスト結果
│   ├── github_integration_plan.md         # GitHub統合プラン（レガシー）
│   └── github_integration_implementation.md  # 実装完了報告（レガシー）
├── CLAUDE.md                  # Claude Code向けリポジトリガイド
└── README.md                  # このファイル
```

## 環境要件

### ローカル環境 (ip-172-17-34-126)
- OS: RHEL8
- 必須ツール:
  - SSH (公開鍵認証設定済み)
  - Git
- オプション（GUIベース方式を使う場合）:
  - xdotool, wmctrl, xclip
  - netpbm-progs（画面キャプチャ用）

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

### 3. 接続テスト

```bash
# ga53pd01への接続確認
ssh ga53pd01 'hostname'
# 出力: ga53pd01
```

### 4. オプション: GUI自動操作ツール（レガシー機能）

```bash
# GUI自動操作ツール
sudo dnf install -y xdotool wmctrl xclip

# 画面キャプチャツール
sudo dnf install -y netpbm-progs

# DISPLAY環境変数の設定
export DISPLAY=:2  # 環境に応じて調整
```

## 使用方法

### SSH統合スクリプト（推奨）

```bash
# ga53pd01でスクリプトを実行（SSH同期実行）
./scripts/claude_to_ga53pd01.sh /path/to/task_script.sh

# デバッグモード
DEBUG=1 ./scripts/claude_to_ga53pd01.sh /path/to/task_script.sh
```

**特徴**:
- 高速（2-3秒）・安定（GUI操作不要）
- リアルタイムで出力表示
- ローカルアーカイブに自動保存（`.archive/YYYYMM/`）
- リモートにファイルを残さない

**実行例**:
```bash
# 簡単なテストスクリプトを作成
cat > /tmp/test.sh << 'EOF'
#!/bin/bash
echo "Hostname: $(hostname)"
echo "Date: $(date)"
echo "User: $(whoami)"
EOF

# 実行
./scripts/claude_to_ga53pd01.sh /tmp/test.sh
```

### Claude CodeのBashツールから使用

Claude Codeでタスクを指示すると、自動的に以下の流れで実行されます：

1. Claude Codeがタスクスクリプトを生成
2. `claude_to_ga53pd01.sh` でga53pd01に転送・実行
3. 結果がリアルタイムで表示
4. ローカルアーカイブに保存

**例**:
```
ユーザー: 「ga53pd01でgionプロジェクトのビルドを実行して」
→ Claude Codeがビルドスクリプトを生成
→ claude_to_ga53pd01.sh で実行
→ 結果表示
```

### GUI自動操作スクリプト（レガシー）

**非推奨**: SSH方式の方がシンプルで高速です。

<details>
<summary>GUI方式の使用方法（クリックで展開）</summary>

**事前準備**: ETX TurboX Dashboardから「Start Xterm」をクリック

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

**画面キャプチャ**:
```bash
./scripts/capture_etx_window.sh /path/to/output.png
```

</details>

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

### GUI自動操作の問題（レガシー）

<details>
<summary>xdotoolのトラブルシューティング（クリックで展開）</summary>

```bash
# X11ディスプレイ確認
echo $DISPLAY

# 権限設定
xhost +SI:localuser:$(whoami)

# ウィンドウ検索テスト
wmctrl -l
xdotool search --name "Terminal"
```

</details>

## 開発ステータス

- [x] プロジェクト構造の作成
- [x] 環境セットアップ
- [x] SSH公開鍵認証の設定
- [x] SSH同期実行スクリプトの実装
- [x] ローカルアーカイブ機能の実装
- [x] 統合テスト
- [x] ドキュメント作成

詳細な実装経緯は以下を参照してください：
- [`docs/plan.md`](docs/plan.md) - 実装プラン
- [`docs/ssh_direct_retrieval_test.md`](docs/ssh_direct_retrieval_test.md) - SSH直接取得テスト結果

## ドキュメント

- [セットアップガイド](docs/setup.md) - 詳細なセットアップ手順
- [実装プラン](docs/plan.md) - 開発計画と進捗
- [CLAUDE.md](CLAUDE.md) - Claude Code向けガイド
- [技術メモ](docs/memo.md) - 初期の技術検討

## ライセンス

(ライセンス情報を追加)

## 貢献

(貢献ガイドラインを追加)
