# オプション機能設定ガイド

このドキュメントでは、palladium-automationプロジェクトのオプション機能について説明します。

**基本的な使用には不要です**。必要に応じて設定してください。

## オプション機能でできること

オプション機能を設定すると、以下の高度な機能が使えるようになります：

### Serena MCP（Verilog/SystemVerilog解析）

- ✅ hornetプロジェクトのRTLコード解析
- ✅ シンボルベース検索（モジュール、関数等）
- ✅ RTLコードの構造解析・編集
- ✅ リファクタリング支援

### Playwright MCP（ブラウザ自動化）

- ✅ Cadence Support Portalへのアクセス
- ✅ Palladium/IXCOMドキュメントの自動検索
- ✅ GUIツールのスクリーンショット取得
- ✅ マニュアル参照の自動化

## 目次

1. [MCP設定（オプション）](#mcp設定オプション)

---

## MCP設定（オプション）

MCPサーバーを使用すると、RTL解析やドキュメント参照が可能になります。

**基本的なスクリプト実行には不要です**。高度な機能が必要な場合のみ設定してください。

### 前提条件

MCPサーバーは`palladium-automation`ディレクトリで実行してください。

```bash
cd ~/palladium-automation
```

### Serena MCP - Verilog/SystemVerilog解析（オプション）

RTL解析機能が使えるようになります。

#### 前提条件

`~/.bashrc` に以下の設定が必要です：

```bash
# Claude Code用設定
export PATH="$HOME/.local/bin:$PATH"
```

設定後、ターミナルを再起動するか：

```bash
source ~/.bashrc
```

#### インストール

```bash
cd ~/palladium-automation

# Serena MCPをインストール
claude-serena

# インストール時の質問に答える:
# - Project directory: /home/khenmi/palladium-automation (カレントディレクトリを指定)
# - Language: verilog (Verilog/SystemVerilogを選択)
```

#### 確認

```bash
# MCPサーバーの接続確認
claude mcp list
# serena: ... - ✓ Connected と表示されればOK
```

#### 機能

- `mcp__serena__find_file`: Verilogファイルを検索
- `mcp__serena__get_symbols_overview`: ファイルのシンボル概要取得
- `mcp__serena__find_symbol`: シンボル検索（モジュール、関数等）
- `mcp__serena__search_for_pattern`: パターン検索
- その他の解析・編集ツール

#### プロンプト例

**RTL解析・修正**:
```
「hornetのt4_hornet_topモジュールを解析して、ALUの接続を確認して」

「hornet/src/alu.svのビット幅エラーを修正して、commit & pushして」

「hornetのクロックドメイン構成を調べて、CDC (Clock Domain Crossing) を確認して」

「hornet内の未使用信号を検索して、リストアップして」

「hornetのメモリインターフェース部分のコードを読んで、動作を説明して」
```

**RTLリファクタリング**:
```
「hornetの重複コードを見つけて、共通モジュールに抽出して」

「モジュール名を "old_alu" から "new_alu" に一括リネームして」

「未使用のパラメータを削除して、コードを整理して」
```

### Playwright MCP - ブラウザ自動化（オプション）

Palladium/IXCOMドキュメントの検索・閲覧を自動化できます。

#### インストール

```bash
cd ~/palladium-automation

# Playwright MCPをインストール
claude mcp add playwright npx @playwright/mcp@latest
```

#### 確認

```bash
# MCPサーバーの接続確認
claude mcp list
# playwright: ... - ✓ Connected と表示されればOK
```

#### 機能

- Cadence Support Portalへのアクセス
- ドキュメント検索の自動化
- スクリーンショット取得

#### プロンプト例

**画面キャプチャと分析**:
```
「ga53pd01のGUIアプリをキャプチャして、表示内容を分析して」

「Palladium Design Perspectiveの画面をキャプチャして、エラー表示がないか確認して」

「シミュレーション実行中の画面を定期的にキャプチャして、進行状況を監視して」
```

**Cadenceマニュアル参照**:
```
「Cadence SupportサイトでPalladiumのエラーコード "XYZ123" を調べて」

「IXCOMのコマンドリファレンスで "emulate -accel" オプションの使い方を教えて」

「Xceliumの最新リリースノートを確認して、バグ修正一覧を教えて」

「Palladium Z3のパフォーマンスチューニングガイドを検索して、推奨設定を教えて」
```

---

## 参考: オプション機能が必要な場面

### Serena MCPが必要な場合

- Verilog/SystemVerilogコードを解析したい
- モジュールやシンボルの関係を調べたい
- RTLコードを編集したい

### Playwright MCPが必要な場合

- Palladium/IXCOMのマニュアルを頻繁に参照する
- ドキュメント検索を自動化したい
- スクリーンショットでGUIツールを確認したい

---

## トラブルシューティング

### MCP接続エラー

```bash
# Serena MCPの再設定
claude-serena

# MCP接続状態確認
claude mcp list

# Claude Codeの再起動
# VSCode/Cursorでリロード
```
