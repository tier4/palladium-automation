# レガシースクリプト

このディレクトリには、xdotoolベースのGUI自動操作スクリプトが保管されています。

## 現在の推奨方式

**SSH同期実行方式**を使用してください：
```bash
../claude_to_ga53pd01.sh /path/to/script.sh
```

詳細は [メインREADME](../../README.md) を参照してください。

## レガシースクリプト一覧

### `claude_to_etx.sh`
- **機能**: xdotool + GitHub統合によるスクリプト実行
- **非推奨理由**:
  - GUI操作が不安定
  - GitHub経由の結果回収が遅い（10-30秒）
  - 複雑な実装
- **代替**: `../claude_to_ga53pd01.sh` (SSH同期実行、2-3秒)

### `etx_automation.sh`
- **機能**: xdotoolによるETX Xtermの基本操作
- **非推奨理由**:
  - ETX Xtermウィンドウの起動が必要
  - タイミング制御が複雑
  - エンコーディング問題
- **代替**: SSHコマンド直接実行

### `capture_etx_window.sh`
- **機能**: ETX Xtermの画面キャプチャ
- **非推奨理由**:
  - SSH経由でログを直接取得できるため不要
- **代替**: SSH経由でログファイル取得

## 使用が必要な場合

特殊なケース（例: GUI表示の確認が必要）では、これらのスクリプトを使用できます。

### 前提条件
- DISPLAY環境変数の設定
- xdotool, wmctrl, xclipのインストール
- ETX Xtermウィンドウの起動

### 使用例
```bash
# 環境変数設定
export DISPLAY=:2

# ETX Xtermが起動していることを確認
wmctrl -l | grep ga53

# スクリプト実行
./claude_to_etx.sh /path/to/script.sh
```

## 歴史的背景

これらのスクリプトは、SSH接続が確立される前に開発されました。xdotoolを使用してGUI操作を自動化し、GitHubを経由して結果を回収する方式でした。

SSH ProxyJumpの設定後、より高速でシンプルなSSH同期実行方式に移行しました。

## 参考資料

- [SSH直接取得テスト結果](../../docs/ssh_direct_retrieval_test.md)
- [メインREADME](../../README.md)
