# プロジェクト統合計画

このディレクトリには、palladium-automationを他のプロジェクト（gion/hornet）に統合する計画書が保管されています。

## 📋 統合計画ドキュメント

### `gion_integration_plan.md`
- **対象**: tier4/gion (HDL開発プロジェクト)
- **統合方式**: `automation/`サブディレクトリ統合
- **ステータス**: 計画段階（Phase 1完了）

### `hornet_integration_comparison.md`
- **対象**: tier4/hornet (GPU/GPGPU開発プロジェクト)
- **内容**: gionとhornetへの統合方式の比較
- **ステータス**: 検討段階

### `repository_strategy.md`
- **内容**: リポジトリ戦略全般の検討
- **トピック**:
  - 独立リポジトリ vs 統合
  - モノレポ vs マルチレポ
  - ディレクトリ構造の設計
- **ステータス**: 戦略検討中

## 🎯 現在のステータス

**palladium-automationは現在、独立したプロジェクトとして運用されています。**

### 現在の構成

```
tier4/palladium-automation (独立リポジトリ)
├── scripts/
│   └── claude_to_ga53pd01.sh  # SSH同期実行
├── workspace/
│   └── etx_results/.archive/  # ローカル結果保存
├── docs/
└── CLAUDE.md
```

### 統合時の構成（計画）

```
tier4/gion/ または tier4/hornet/
├── automation/              # palladium-automationを統合
│   ├── scripts/
│   ├── docs/
│   └── workspace/
└── (既存のプロジェクト構造)
```

## ⚠️ 重要な変更事項

これらの統合計画は、**xdotool + GitHub方式**を前提に作成されました。

現在は**SSH同期実行方式**に移行しているため、統合を実施する際には以下の更新が必要です：

### 更新が必要な箇所

1. **スクリプト構成**:
   - 旧: `claude_to_etx.sh` (xdotool + GitHub)
   - 新: `claude_to_ga53pd01.sh` (SSH sync)

2. **結果保存方式**:
   - 旧: GitHubにpush → ローカルでpull
   - 新: SSH経由でリアルタイム取得 → ローカルアーカイブ

3. **依存関係**:
   - 旧: xdotool, wmctrl, xclip, GitHub統合
   - 新: SSH公開鍵認証のみ

4. **MCPサーバー**:
   - 旧: etx-automation MCPサーバー
   - 新: 不要（SSH直接実行）

## 📝 統合を実施する場合の手順

### 1. 統合計画の更新

各計画書をSSH同期実行方式に合わせて更新：

```bash
# 例: gion_integration_plan.md を開いて更新
# - xdotool関連の削除
# - SSH方式の追記
# - MCPサーバー削除
# - ディレクトリ構造の簡素化
```

### 2. 統合テスト

ローカル環境で統合をシミュレーション：

```bash
# gionをクローン
git clone https://github.com/tier4/gion.git /tmp/gion_test

# automationディレクトリに統合
mkdir -p /tmp/gion_test/automation
cp -r scripts/ /tmp/gion_test/automation/
cp -r workspace/ /tmp/gion_test/automation/
cp -r docs/ /tmp/gion_test/automation/

# 動作確認
cd /tmp/gion_test
./automation/scripts/claude_to_ga53pd01.sh /tmp/test.sh
```

### 3. 本番統合

テスト成功後、本番環境で統合：

```bash
cd ~/gion  # または ~/hornet
git checkout -b feature/add-automation-tools
mkdir -p automation
# ... 統合作業 ...
git commit -m "feat: integrate palladium-automation tools"
git push origin feature/add-automation-tools
# Pull Request作成
```

## 🤔 統合すべきか？

### 統合のメリット

- ✅ 単一リポジトリで管理
- ✅ プロジェクト固有の設定を共有
- ✅ バージョン管理が統一

### 独立運用のメリット

- ✅ プロジェクト間で独立
- ✅ 複数プロジェクトで共用可能
- ✅ 開発サイクルが独立

### 推奨

**現時点では独立運用を推奨**します：

1. **汎用性**: ga53pd01上の任意のプロジェクト（gion, hornet等）で使用可能
2. **シンプル**: SSH方式により、プロジェクト固有の設定が不要
3. **保守性**: 自動化ツールの更新が各プロジェクトに影響しない

統合が必要になるのは：
- プロジェクト固有のスクリプトが増えた場合
- チーム全体で標準化が必要な場合
- プロジェクト固有の設定ファイルが必要な場合

## 📚 参考資料

- [メインREADME](../../README.md)
- [セットアップガイド](../setup.md)
- [SSH直接取得テスト結果](../ssh_direct_retrieval_test.md)

## 更新履歴

- 2025-11-08: 統合計画ファイルを `integration_plans/` に整理
- 2025-11-07: 初期計画作成（xdotool + GitHub方式）
