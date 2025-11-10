# palladium-automation セットアップガイド

このガイドでは、**palladium-automationプロジェクトをgit cloneしてから、Claude Codeで使用できるようにするまでの手順**を説明します。

## セットアップ完了後にClaude Codeでできること

- ✅ **ga53pd01でスクリプトを自動実行** - Palladium環境でのビルド・シミュレーションを自然言語で指示
- ✅ **RTLコードの解析と編集** - Verilog/SystemVerilogコードをシンボルベースで理解・修正（Serena MCP）
- ✅ **ドキュメントの自動検索・参照** - Palladium/IXCOMのマニュアルをブラウザ自動化で取得（Playwright MCP）
- ✅ **実行結果の自動分析** - ログファイルのエラー解析・レポート生成
- ✅ **ワークフロー全体の自動化** - 「ビルドして、テストして、結果を分析して」を一度の指示で実行

## 重要: プロジェクト内完結の原則

**このプロジェクトはグローバルインストールを使用しません。**

すべての依存関係とツールはプロジェクト内で管理されます。これにより:
- チームメンバー全員が同じ環境で作業可能
- システム全体の環境を汚染しない
- プロジェクトをクローンするだけで開始できる

## 目次

1. [ga53pd01へのパスワードレスSSH接続設定](#ga53pd01へのパスワードレスssh接続設定)
2. [プロジェクトのセットアップ](#プロジェクトのセットアップ)
3. [動作確認](#動作確認)
4. [トラブルシューティング](#トラブルシューティング)

---

## ga53pd01へのパスワードレスSSH接続設定

**目的**: パスワード入力なしで `ssh ga53pd01` コマンドでダイレクトにga53pd01にアクセスできるようにします。

これにより、Claude Codeが自動的にスクリプトを実行する際に、認証で止まることなくシームレスに動作します。

**ユーザー名について**:
- 以下の手順では `your_palladium_username` と記載しています
- これは**Palladium環境のユーザー名**です（ローカルのユーザー名とは異なる場合があります）
- 例: ローカルが `khenmi`、Palladiumが `henmi` の場合、`henmi` を使用します

### 1. SSH鍵の生成

既にSSH公開鍵認証用の鍵ペア（`~/.ssh/id_ed25519` または `~/.ssh/id_rsa`）を持っている場合はスキップできます。

```bash
# SSH鍵の存在確認
ls -la ~/.ssh/id_*.pub
# 出力例: id_ed25519.pub または id_rsa.pub が表示されればOK

# 鍵がない場合は生成（パスフレーズなしで簡単セットアップ）
ssh-keygen -t ed25519 -C "your_email@tier4.jp" -N ""

# 実行すると以下のように表示されます:
# Generating public/private ed25519 key pair.
# Your identification has been saved in /home/username/.ssh/id_ed25519
# Your public key has been saved in /home/username/.ssh/id_ed25519.pub
```

### 2. バスティオンサーバー（ga53ut01 / 10.108.64.1）への公開鍵登録

```bash
# バスティオンサーバー（ga53ut01）に公開鍵をコピー
# 注: your_palladium_username を自分のPalladiumユーザー名に置き換えてください
ssh-copy-id your_palladium_username@10.108.64.1

# パスワードを入力
# your_palladium_username@10.108.64.1's password: [パスワード入力]

# 接続確認
ssh your_palladium_username@10.108.64.1 'hostname'
# 出力: ga53ut01
```

### 3. ga53pd01への公開鍵登録

```bash
# バスティオンサーバー（ga53ut01）経由でga53pd01にログイン
ssh your_palladium_username@10.108.64.1

# ga53pd01に公開鍵をコピー
ssh-copy-id your_palladium_username@ga53pd01

# パスワードを入力
# your_palladium_username@ga53pd01's password: [パスワード入力]

# ログアウト
exit
```

### 4. SSH ProxyJump設定

ProxyJump機能を使うと、バスティオンサーバー（ga53ut01）経由のアクセスが透過的になります。

`~/.ssh/config` ファイルを編集:

```bash
vi ~/.ssh/config
```

以下の設定を追加:

```ssh-config
# Palladium Bastion Server (ga53ut01)
Host palladium_bastion
  HostName 10.108.64.1
  User your_palladium_username    # 自分のPalladiumユーザー名に変更
  IdentityFile ~/.ssh/id_ed25519
  ForwardX11 yes

# Palladium ga53pd01 via Bastion (ga53ut01)
Host ga53pd01
  HostName ga53pd01
  User your_palladium_username    # 自分のPalladiumユーザー名に変更
  IdentityFile ~/.ssh/id_ed25519
  ProxyJump palladium_bastion
  ForwardX11 yes
```

### 5. t4_head から ga53pd01 パスワード無しSSH接続の確認

```bash
# gt4_head から a53pd01への直接接続テスト（パスワード不要で接続できるはず）
ssh ga53pd01 'hostname'
# 出力: ga53pd01

# 詳細情報の確認
ssh ga53pd01 'hostname; whoami; pwd'
# 出力例:
# ga53pd01
# henmi
# /home/henmi
```

**成功の確認ポイント**:
- ✅ パスワード入力なしで接続できる
- ✅ `ga53pd01` というホスト名が表示される
- ✅ 接続時間が2秒以内

**トラブルシューティング**:

パスワードを要求される場合:
```bash
# デバッグモードで接続
ssh -v ga53pd01

# 公開鍵認証が試行されているか確認
# "Offering public key: ..." というメッセージを探す

# 公開鍵が正しく登録されているか確認
ssh ga53pd01 'cat ~/.ssh/authorized_keys'
```

---

## プロジェクトのセットアップ

### 1. palladium-automation のクローン

```bash
cd ~   # 適切なディレクトリに移動
git clone https://github.com/tier4/palladium-automation.git
cd palladium-automation
```

### 2. 環境変数の設定

```bash
# .env.exampleをコピーして自分の環境に合わせて編集
cp .env.example .env
vi .env
```

**設定内容** (`.env` ファイル):
```bash
REMOTE_USER=your_palladium_username     # 自分のPalladiumユーザー名
```

**注意**: 他の設定項目（`REMOTE_HOST`、`PROJECT_NAME`、`BASTION_HOST`等）はデフォルト値で動作するため、通常は変更不要です。

### 3. Palladium対象プロジェクト（Hornet RTL）のクローン

```bash
# palladium-automation内にhornetをクローン（デフォルトブランチ: main）
git clone https://github.com/tier4/hornet.git

# または特定のブランチを指定してクローン
git clone -b <branch_name> https://github.com/tier4/hornet.git

# 確認
ls -la hornet/
# hornet/src/, hornet/eda/, hornet/tb/ などが表示されればOK
```

**重要な注意事項**:
- `hornet/`ディレクトリは`.gitignore`に含まれており、palladium-automationのGit管理対象外です
- **ローカルとga53pd01のhornetは同じブランチを使用してください**（後述の「次のステップ」でga53pd01にもクローンします）


### 4. アーカイブディレクトリの作成

```bash
# 結果保存用ディレクトリの作成
mkdir -p workspace/etx_results/.archive
```

### 5. ディレクトリ構造の確認

```bash
ls -la
```

期待される構造:
```
palladium-automation/
├── scripts/
│   ├── claude_to_ga53pd01.sh    # SSH統合スクリプト（推奨）
│   └── .legacy/                 # レガシースクリプト（GUI自動操作）
├── workspace/
│   └── etx_results/
│       └── .archive/            # ローカル結果アーカイブ
├── hornet/                      # Hornet RTLプロジェクト（git clone）
├── .env                         # 環境設定ファイル（要作成）
├── .env.example                 # 環境設定テンプレート
├── docs/
├── CLAUDE.md
└── README.md
```

### 6. スクリプトの実行権限確認

```bash
chmod +x scripts/claude_to_ga53pd01.sh
```

### 7. MCP設定

**注意**: MCPサーバーは各自の環境でインストールが必要です。

#### Serena MCP - Verilog/SystemVerilog解析

RTL解析機能が使えるようになります。

**前提条件**: `~/.bashrc` に以下の設定が必要です：

```bash
# Verible（Verilog言語サーバー）のロード
module load verible >/dev/null 2>&1

# claude-serenaエイリアスの設定
alias claude-serena='claude mcp add serena -- /opt/eda/uv/current/bin/uv run --directory /opt/eda/serena-verilog/current/ serena start-mcp-server --context ide-assistant --project $(pwd) --enable-web-dashboard false'
```

**インストール手順**:

```bash
# 1. 上記の設定を ~/.bashrc に追加（まだの場合）
vi ~/.bashrc

# 2. .bashrcを再読み込み
source ~/.bashrc

# 3. Serena MCPをインストール
claude-serena
```

**提供機能**:
- hornetプロジェクトのVerilog/SystemVerilogコード解析
- シンボルベース検索（モジュール、関数等）
- RTLコードの構造解析

#### Playwright MCP - ブラウザ自動化

Cadence Supportサイトのドキュメント参照ができるようにします。

**インストール手順**:

```bash
# Playwright MCPをインストール
claude mcp add playwright npx @playwright/mcp@latest
```

**提供機能**:
- Cadence Support Portalへのアクセス
- Palladium/IXCOMなどのドキュメントの検索・閲覧自動化
- スクリーンショット取得

---

## 動作確認

### スクリプト実行テスト

リポジトリに用意されているテストスクリプトを実行します：

```bash
# テストスクリプトを実行
./scripts/claude_to_ga53pd01.sh scripts/test_connection.sh
```

**期待される動作**:
1. スクリプトがga53pd01で実行される
2. 実行中の出力がリアルタイムで表示される
3. また、結果は `workspace/etx_results/.archive/YYYYMM/` にも保存される

**実行例**:
```
[INFO] === Running Task on ga53pd01: test_task ===
[INFO] Task ID: khenmi_20251108_183841
[INFO] Timestamp: 20251108_183841
[INFO] Execution mode: SSH Synchronous (real-time output)
[INFO] Executing script on ga53pd01...
[INFO] Output will be saved to: workspace/etx_results/.archive/202511/khenmi_20251108_183841_test_task_result.txt

=== Test Task Started ===
Date: Sat Nov  8 01:38:41 PST 2025
User: henmi
Hostname: ga53pd01

Working directory: /home/henmi
Test calculation: 10 + 20 = 30

=== Test Task Complete ===

[INFO] === Task Completed Successfully ===
[INFO] Result archived: workspace/etx_results/.archive/202511/khenmi_20251108_183841_test_task_result.txt
[INFO] Output: 10 lines, 4.0K
```

### 結果ファイルの確認

実行完了時の`[INFO]`メッセージに表示されたファイルパスを確認します：

```bash
# アーカイブディレクトリの確認
ls -lh workspace/etx_results/.archive/$(date +%Y%m)/

# INFOメッセージに表示されたファイルパスを直接指定して確認
# 例: workspace/etx_results/.archive/202511/khenmi_20251108_183841_test_connection_result.txt
cat workspace/etx_results/.archive/202511/khenmi_20251108_183841_test_connection_result.txt
```

---

## 次のステップ

セットアップが完了したら:

1. **ga53pd01にhornetプロジェクトをクローン または pull**:

   サンプルビルドスクリプトを実行するには、ga53pd01上にhornetをクローンする必要があります。

   **既にクローン済みの場合はスキップ可能です。**

   **手動でクローン**:
   ```bash
   # ga53pd01にログイン
   ssh ga53pd01

   # プロジェクトディレクトリに移動して、hornetをクローン
   cd /proj/tierivemu/work/<your_palladium_username>

   # デフォルトブランチ（main）をクローン
   git clone https://github.com/tier4/hornet.git

   # または特定のブランチを指定してクローン
   # git clone -b <branch_name> https://github.com/tier4/hornet.git

   exit
   ```

   **Claude Codeで自動実行** (推奨):
   ```
   「ga53pd01の /proj/tierivemu/work/<your_palladium_username>/ に
   https://github.com/tier4/hornet.git のmainブランチをgit cloneして」

   # 特定のブランチをクローンする場合:
   「ga53pd01の /proj/tierivemu/work/<your_palladium_username>/ に
   https://github.com/tier4/hornet.git の<branch_name>ブランチをgit cloneして」
   ```

2. **カスタムタスクスクリプトの作成**:

   **重要**: サンプルスクリプト（`ga53pd01_example_task.sh`）は直接編集せず、コピーして使用してください。

   ```bash
   # サンプルスクリプトをコピーして、自分用のスクリプトを作成
   cp scripts/ga53pd01_example_task.sh scripts/ga53pd01_task.sh

   # 必要に応じて編集（ターゲット、パス等）
   vi scripts/ga53pd01_task.sh

   # 実行
   ./scripts/claude_to_ga53pd01.sh scripts/ga53pd01_task.sh
   ```

   **理由**:
   - ✅ `git pull`時にコンフリクトしない
   - ✅ サンプルは常に最新版に更新される
   - ✅ ユーザー固有の設定を保持できる
   - ✅ 複数のタスクスクリプトを作成できる

   **注意**: `scripts/*_task.sh`は`.gitignore`に含まれており、Git管理対象外です。

3. **Hornet RTL開発ワークフロー（推奨）**:

   **ローカルhornetがメイン開発環境です。**

   ### Claude Codeへの指示方法

   Claude Codeに自然言語で指示することで、コミット・プッシュ・リモート実行を自動化できます。

   #### 基本的な指示例

   ```
   「hornetの変更をコミット＆プッシュして、ga53pd01でkv260ビルドを実行して」
   ```

   **Claude Codeの実行フロー**:

   1. **変更確認**
      ```bash
      cd hornet
      git status
      git diff
      ```

   2. **コミットメッセージ案の提示**
      ```
      以下の変更をコミットします：

      変更されたファイル:
      - src/alu.sv
      - src/control.sv

      コミットメッセージ案:
      "fix: update ALU logic and control signals"

      このメッセージでコミットしますか？
      ```
      ※ ユーザーが確認・修正可能

   3. **コミット＆プッシュ実行**
      ```bash
      git add .
      git commit -m "fix: update ALU logic and control signals"
      git push
      ```

   4. **ga53pd01でビルド実行**
      ```bash
      cd /home/khenmi/palladium-automation
      TARGET=kv260 ./scripts/claude_to_ga53pd01.sh ./scripts/ga53pd01_task.sh
      ```
      ※ 事前に`scripts/ga53pd01_task.sh`を作成しておく必要があります

   5. **claude_to_ga53pd01.shの自動処理**
      - ローカルhornetのGit状態を検証
        - ✓ 未コミット変更なし
        - ✓ 未プッシュコミットなし
        - ✓ upstream設定済み
      - リモートhornetで`git pull`実行
      - ローカルとリモートのブランチ・コミットが一致することを確認
      - ga53pd01で`scripts/ga53pd01_task.sh`実行

   6. **結果の保存と表示**
      ```
      === タスクが正常に完了しました ===
      結果を保存: workspace/etx_results/.archive/202511/...
      出力: 25 行, 1.2K
      ```

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

   ### メリット

   - ✅ **コミットメッセージを毎回確認・修正できる**
   - ✅ **意図しない変更がコミットされない**
   - ✅ **適切なコミットメッセージが自動生成される**
   - ✅ **柔軟に対応可能**（一部ファイルのみコミット等）
   - ✅ **自然言語で直感的に指示できる**

   **自動Git同期機能**:
   - ✅ ローカルの未コミット/未プッシュを自動検出
   - ✅ ga53pd01で自動git pull実行
   - ✅ ブランチ・コミットの一致を自動確認
   - ✅ 不一致時は実行を中止して警告

4. **Claude Code実用プロンプト例**:

   以下のようにClaude Codeに自然言語で指示することで、様々なタスクを自動実行できます。

   **ビルド・シミュレーション**:
   ```
   「ga53pd01でhornetのビルドを実行して、エラーがあれば教えて」

   「ga53pd01でXceliumシミュレーションを実行して、結果を分析して」

   「ga53pd01でPalladiumエミュレーションを開始して、ログを監視して」
   ```

   **RTL解析・修正** (Serena MCP使用):
   ```
   「hornetのt4_hornet_topモジュールを解析して、ALUの接続を確認して」

   「hornet/src/alu.svのビット幅エラーを修正して、commit & pushして」

   「hornetのクロックドメイン構成を調べて、CDC (Clock Domain Crossing) を確認して」

   「hornet内の未使用信号を検索して、リストアップして」

   「hornetのメモリインターフェース部分のコードを読んで、動作を説明して」

   「ga53pd01でgit pullしてから、修正したコードでビルドして」
   ```

   **RTLリファクタリング** (Serena MCP使用):
   ```
   「hornetの重複コードを見つけて、共通モジュールに抽出して」

   「モジュール名を "old_alu" から "new_alu" に一括リネームして」

   「未使用のパラメータを削除して、コードを整理して」
   ```

   **ログ解析・デバッグ**:
   ```
   「最新のシミュレーションログからエラーを抽出して、原因を分析して」

   「ga53pd01のビルドログでwarningを確認して、重大なものを教えて」

   「Palladiumのログでタイムアウトエラーを検索して」
   ```

   **自動テスト**:
   ```
   「hornetの全テストケースをga53pd01で実行して、結果をまとめて」

   「regression testを実行して、前回との差分を報告して」

   「特定のテストケースだけ再実行して、詳細なログを取得して」
   ```

   **画面キャプチャと分析** (Playwright MCP使用):
   ```
   「ga53pd01のGUIアプリをキャプチャして、表示内容を分析して」

   「Palladium Design Perspectiveの画面をキャプチャして、エラー表示がないか確認して」

   「シミュレーション実行中の画面を定期的にキャプチャして、進行状況を監視して」
   ```

   **Cadenceマニュアル参照** (Playwright MCP使用):
   ```
   「Cadence SupportサイトでPalladiumのエラーコード "XYZ123" を調べて」

   「IXCOMのコマンドリファレンスで "emulate -accel" オプションの使い方を教えて」

   「Xceliumの最新リリースノートを確認して、バグ修正一覧を教えて」

   「Palladium Z3のパフォーマンスチューニングガイドを検索して、推奨設定を教えて」
   ```

---

## トラブルシューティング

### SSH接続エラー: パスワードを要求される

**原因**: 公開鍵認証が正しく設定されていない

**解決方法**:

1. **SSH鍵が正しく登録されているか確認**:
   ```bash
   # バスティオンサーバーで確認
   ssh henmi@10.108.64.1 'cat ~/.ssh/authorized_keys'

   # ga53pd01で確認（バスティオンサーバー経由）
   ssh henmi@10.108.64.1 'ssh ga53pd01 "cat ~/.ssh/authorized_keys"'
   ```

2. **公開鍵の権限確認**:
   ```bash
   # ローカルの権限確認
   ls -la ~/.ssh/
   # id_ed25519: 600 (rw-------)
   # id_ed25519.pub: 644 (rw-r--r--)

   # 権限が異なる場合は修正
   chmod 600 ~/.ssh/id_ed25519
   chmod 644 ~/.ssh/id_ed25519.pub
   chmod 700 ~/.ssh
   ```

3. **SSH AgentにSSH鍵を追加**:
   ```bash
   # SSH Agentの起動確認
   ssh-add -l

   # 鍵がリストにない場合は追加
   ssh-add ~/.ssh/id_ed25519
   ```

4. **デバッグモードで詳細確認**:
   ```bash
   # 詳細ログを出力
   ssh -vv ga53pd01

   # 以下のメッセージを探す:
   # "Offering public key: ~/.ssh/id_ed25519"
   # "Server accepts key: ..."
   ```

### SSH接続エラー: ProxyJumpが機能しない

**症状**: `ssh: Could not resolve hostname ga53pd01`

**原因**: SSH config設定が読み込まれていない、または構文エラー

**解決方法**:

1. **設定ファイルの構文確認**:
   ```bash
   # SSH configの確認
   cat ~/.ssh/config

   # 構文チェック（存在する場合）
   ssh -G ga53pd01
   ```

2. **設定ファイルの権限確認**:
   ```bash
   ls -la ~/.ssh/config
   # 出力: -rw------- (600)

   # 権限が異なる場合は修正
   chmod 600 ~/.ssh/config
   ```

3. **手動でProxyJumpを指定**:
   ```bash
   # configなしで接続テスト
   ssh -J henmi@10.108.64.1 henmi@ga53pd01 'hostname'
   ```

---

## 参考資料

- [プロジェクト概要](../README.md)
- [SSH直接取得テスト結果](ssh_direct_retrieval_test.md)
- [CLAUDE.md](../CLAUDE.md) - Claude Code向けガイド


