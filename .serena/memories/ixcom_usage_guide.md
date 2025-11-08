# IXCOM Usage Guide

## Overview

IXCOM (Integrated Xcelium Compiler) は、Cadence Palladium Z3/Z2エミュレーション環境向けのHDLコンパイラです。Verilog、SystemVerilog、VHDLデザインをPalladiumハードウェア上で実行可能な形式にコンパイル・エラボレーションします。

## インストール情報

- **バージョン**: IXCOM V24.05.338.s005 (2025年4月リリース)
- **インストールパス**: `/apps/IXCOM2405/24.05.338.s005/`
- **実行ファイル**: `/apps/IXCOM2405/24.05.338.s005/bin/ixcom`
- **ビットモード**: 64bit (デフォルト)

## 基本的な使用方法

IXCOMには2つの主要な使用モデルがあります：

### 1. ワンステップコンパイル（解析+エラボレーション統合）

```bash
ixcom [options] [compile_options] file(s)
```

このモデルでは、Verilogデザインの解析とエラボレーションを1ステップで実行します。

**例**:
```bash
ixcom -top my_top design.sv testbench.sv
```

### 2. ツーステップコンパイル（解析→エラボレーション）

```bash
# ステップ1: 解析（language-specific analyzer使用）
vlan design.sv
# ステップ2: エラボレーション
ixcom [options] [elaborate_options] -top <design_unit>
```

## 重要なオプション

### コンパイルオプション

| オプション | 説明 |
|-----------|------|
| `-top <module>` | トップレベルモジュール指定 |
| `-f <file>` | オプションファイル読み込み |
| `+define+<macro>` | マクロ定義 |
| `+incdir+<path>` | インクルードディレクトリ指定 |
| `-makelib <libpath>` | HDLファイルを指定ライブラリにコンパイル |
| `-log <file>` | ログファイル指定 (デフォルト: ixcom.log) |
| `-64` | 64bitモード明示指定 |
| `-32` | 32bitモード明示指定 |

### SystemVerilog/Verilogコンパイルオプション

| オプション | 説明 |
|-----------|------|
| `+sva[+<module>]` | SystemVerilogアサーション有効化 |
| `+no_sva[+<module>]` | SystemVerilogアサーション無効化 |
| `-assert` | PSLアサーション有効化 |
| `+maxdelays` | min:typ:maxから最大ディレイ選択 |
| `+mindelays` | min:typ:maxから最小ディレイ選択 |
| `+specblk` | specify block処理有効化（デフォルト:無視） |

### エラボレーションオプション

| オプション | 説明 |
|-----------|------|
| `-L <library>` | デザインユニット検索ライブラリ指定 |
| `-defparam <arg>` | Verilogパラメータ値の再定義 |
| `-bbcell <du>` | 指定セルをブラックボックス化 |
| `+profile` | SW/HWプロファイリング有効化 |
| `-dumpDb` | エラボレート済みデザインDB出力 |

### ハードウェア専用RTLマーキング

| オプション | 説明 |
|-----------|------|
| `+hwOnlyRtl+<module>` | 指定モジュールをハードウェア専用としてマーク |
| `+hwOnlyRtlTop+<module>` | 指定モジュール階層全体をハードウェア専用化 |
| `+hwOnlyRtlExcl+<module>` | hwOnlyRtlマーキング解除 |

### X値サポート（4値論理）

| オプション | 説明 |
|-----------|------|
| `-fourState` | X値サポート（エミュレータ依存） |
| `-fourStateWithEnhancedMemory` | X値+メモリ操作拡張機能 |

### コンパイル最適化

| オプション | 説明 |
|-----------|------|
| `+localDiskComp` | ローカルディスクコンパイル（高速化） |
| `-disableParallelLwdModel` | 並列LWDモデルビルド無効化 |
| `-elabProfile` | エラボレーション実行時プロファイル生成 |

### デバッグ・検証

| オプション | 説明 |
|-----------|------|
| `-conformal` | Conformal-LECによる等価性チェック自動実行 |
| `-conformalTop <module>` | LEC用トップモジュール指定 |
| `-enableLWD` | LWDスクリプト生成（波形デバッグ） |
| `-intf_debug_struct` | SVインターフェースデバッグ構造体生成 |

## Cadence Doc Assistant (CDA)

IXCOM 24.05以降、ドキュメントビューアとして**Cadence Doc Assistant (CDA)**が標準となりました。

### 基本情報

- **バージョン**: Doc Assistant v02.20
- **パス**: `/apps/IXCOM2405/24.05.338.s005/bin/cda`
- **旧ツール**: `cdnshelp` (24.05以降非推奨)

### 起動方法

```bash
# デフォルト起動
cda &

# 特定製品のマニュアルを開く
cda -tool &

# 階層パス指定
cda -hierarchy <install_dir1>/doc:<install_dir2>/doc &

# 特定ページを開く
cda -openpage <toolname>:<tagname> &

# テキスト検索
cda -search "search term" &

# XMLオーガナイザ再構築
cda -refresh &
```

### 動作モード

1. **オンラインモード（デフォルト）**: クラウドサーバーから最新ドキュメント取得
2. **オフラインモード**: インストール階層からローカルドキュメント表示

## 主要ドキュメント

### オンラインドキュメント（Cadence Support Portal）

1. **IXCOM ReadMe** (IXCOM 25.08, 2025年8月版)
   - 既知の問題と解決策
   - 新機能と改善点
   - サポートOS/システム要件

2. **Palladium Z3/Z2 Planning and Installation Guide**
   - システム概要、安全要件
   - 電気・環境要件
   - ハードウェア/ソフトウェアインストール手順

3. **Compiling Designs with IXCOM** (IXCOM 23.03, 2024年11月)
   - コンパイルステージ詳細
   - ixcom compiler使用法

4. **Behavioral Compilation with IXCOM** (IXCOM 23.03, 2024年11月)
   - SIXC_CTRL directive使用法
   - クロックイベント制御

5. **Modeling Guide for VHDL Designs in ICE Mode**
   - VHDLオペランド仕様
   - ユーザー定義パッケージ

### アクセス方法

- **Cadence ASK Portal**: https://support.cadence.com/apex/HomePage
- ログイン後、"Palladium Z3" で検索

## 典型的なワークフロー

### 1. 基本コンパイル

```bash
# ワンステップコンパイル
ixcom -top testbench \
      +incdir+./include \
      +define+SIM \
      -f filelist.f \
      -log compile.log
```

### 2. ライブラリを使用したコンパイル

```bash
# ライブラリ作成とコンパイル
ixcom -makelib work \
      design.sv \
      -endlib \
      -top testbench
```

### 3. 4値論理（X値サポート）

```bash
ixcom -fourState \
      -top testbench \
      design.sv
```

### 4. デバッグ有効化

```bash
ixcom -enableLWD \
      -top testbench \
      design.sv
```

### 5. Conformal LEC統合

```bash
ixcom -conformal \
      -conformalTop my_dut \
      -top testbench \
      design.sv
```

## 注意事項

1. **ビットモード**: デフォルトは64bit。32bitが必要な場合は`-32`を明示指定。
2. **タイムスケール**: Verilogファイルに`timescale`がない場合、`-vtimescale`で指定。
3. **エラー処理**: デフォルトでエラー数上限あり。`+max_error_count+<N>`で変更可能。
4. **ログ**: デフォルトで`ixcom.log`生成。`-log`で変更可能。
5. **クリーンアップ**: `-clean`でixcom生成ファイル削除（`-cleanbg`でバックグラウンド実行）。

## 環境変数

IXCOMは以下のような環境変数を参照する可能性があります：

- `IXCOM_HOME`: IXCOMインストールディレクトリ
- `VXE_HOME`: VXE（Verification eXecution Environment）ホーム
- `DISPLAY`: X11ディスプレイ（GUIツール使用時）

## トラブルシューティング

### バージョン不一致エラー

```bash
# HDLICEバージョンチェック無効化
ixcom -ignoreVersionCheck hdlice -top testbench design.sv

# xeCompileバージョンチェック無効化
ixcom -ignoreVersionCheck xecompile -top testbench design.sv
```

### セットアップチェックエラー

```bash
# ハードウェアプラットフォームセットアップチェック無視
ixcom -ignoreHWPlatformSetupCheck -top testbench design.sv

# シミュレーションセットアップチェック無視
ixcom -ignoreSimSetupCheck -top testbench design.sv
```

## 関連コマンド

- `vlan`: Verilog解析器
- `vhlan`: VHDL解析器
- `xmelab`: Xceliumエラボレータ
- `xmsim`: Xceliumシミュレータ
- `xeCompile`: Palladiumコンパイラ

## 参考情報

- **オンラインヘルプ**: `ixcom -help`
- **コンパイルヘルプ**: `ixcom -help compile`
- **エラボレーションヘルプ**: `ixcom -help elaborate`
- **CDAヘルプ**: `cda -help`
