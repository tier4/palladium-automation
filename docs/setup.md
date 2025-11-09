# セットアップガイド

このガイドでは、Palladium自動化プロジェクトのセットアップ手順を説明します。

## 重要: プロジェクト内完結の原則

**このプロジェクトはグローバルインストールを使用しません。**

すべての依存関係とツールはプロジェクト内で管理されます。これにより:
- チームメンバー全員が同じ環境で作業可能
- システム全体の環境を汚染しない
- プロジェクトをクローンするだけで開始できる

## 目次

1. [前提条件](#前提条件)
2. [SSH公開鍵認証の設定](#ssh公開鍵認証の設定)
3. [プロジェクトのセットアップ](#プロジェクトのセットアップ)
4. [動作確認](#動作確認)
5. [トラブルシューティング](#トラブルシューティング)

---

## 前提条件

### ローカル環境（RHEL8）

必須ツール:
- SSH (OpenSSH 7.3以降)
- Git
- Bash

オプション:
- X11 Forwarding (GUIツール表示用)
- gnome-screenshot (画面キャプチャ用)

### リモート環境（ga53pd01）

- RHEL8
- Palladium Compute Server
- SSHアクセス可能
- バスティオンサーバー（10.108.64.1）経由でアクセス

---

## SSH公開鍵認証の設定

### 1. SSH鍵の生成

既にSSH鍵を持っている場合はスキップできます。

```bash
# SSH鍵の存在確認
ls -la ~/.ssh/id_*.pub

# 鍵がない場合は生成
ssh-keygen -t ed25519 -C "your_email@tier4.jp"

# パスフレーズの入力（推奨）
# Enter passphrase (empty for no passphrase): [パスフレーズを入力]
# Enter same passphrase again: [もう一度入力]
```

**推奨設定**:
- 鍵タイプ: `ed25519` （高速・安全）
- 保存場所: デフォルト（`~/.ssh/id_ed25519`）
- パスフレーズ: 設定推奨（セキュリティ向上）

### 2. バスティオンサーバーへの公開鍵登録

```bash
# バスティオンサーバーに公開鍵をコピー
ssh-copy-id henmi@10.108.64.1

# パスワードを入力
# henmi@10.108.64.1's password: [パスワード入力]

# 接続確認
ssh henmi@10.108.64.1 'hostname'
# 出力: [バスティオンサーバーのホスト名]
```

### 3. ga53pd01への公開鍵登録

```bash
# バスティオンサーバー経由でga53pd01にログイン
ssh henmi@10.108.64.1

# ga53pd01に公開鍵をコピー
ssh-copy-id henmi@ga53pd01

# パスワードを入力
# henmi@ga53pd01's password: [パスワード入力]

# ログアウト
exit
```

### 4. SSH ProxyJump設定

ProxyJump機能を使うと、バスティオンサーバー経由のアクセスが透過的になります。

`~/.ssh/config` ファイルを編集:

```bash
nano ~/.ssh/config
```

以下の設定を追加:

```ssh-config
# Palladium Bastion Server
Host palladium_bastion
  HostName 10.108.64.1
  User henmi
  IdentityFile ~/.ssh/id_ed25519
  ForwardX11 yes

# Palladium ga53pd01 via Bastion
Host ga53pd01
  HostName ga53pd01
  User henmi
  IdentityFile ~/.ssh/id_ed25519
  ProxyJump palladium_bastion
  ForwardX11 yes
```

**設定のカスタマイズ**:
- `User`: 自分のユーザー名に変更
- `IdentityFile`: 異なるSSH鍵を使用する場合は変更
- `ForwardX11`: X11フォワーディングが不要な場合は削除

### 5. SSH接続の確認

```bash
# ga53pd01への直接接続テスト（パスワード不要で接続できるはず）
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

### 1. プロジェクトのクローン

```bash
cd ~
git clone https://github.com/tier4/palladium-automation.git
cd palladium-automation
```

### 2. ディレクトリ構造の確認

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
├── docs/
├── CLAUDE.md
└── README.md
```

### 3. スクリプトの実行権限確認

```bash
chmod +x scripts/claude_to_ga53pd01.sh
```

### 4. アーカイブディレクトリの作成

```bash
# 結果保存用ディレクトリの作成
mkdir -p workspace/etx_results/.archive
```

---

## 動作確認

### 1. SSH接続テスト

```bash
# シンプルな接続テスト
ssh ga53pd01 'echo "Connection successful: $(hostname)"'
# 出力: Connection successful: ga53pd01
```

### 2. スクリプト実行テスト

#### 簡単なテストスクリプトを作成

```bash
cat > /tmp/test_task.sh << 'EOF'
#!/bin/bash
echo "=== Test Task Started ==="
echo "Date: $(date)"
echo "User: $(whoami)"
echo "Hostname: $(hostname)"
echo ""
echo "Working directory: $(pwd)"
echo "Test calculation: 10 + 20 = $((10 + 20))"
echo ""
echo "=== Test Task Complete ==="
EOF
```

#### SSH統合スクリプトで実行

```bash
./scripts/claude_to_ga53pd01.sh /tmp/test_task.sh
```

**期待される動作**:
1. スクリプトがga53pd01で実行される
2. 実行中の出力がリアルタイムで表示される
3. 結果が `workspace/etx_results/.archive/YYYYMM/` に保存される

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

### 3. 結果ファイルの確認

```bash
# アーカイブディレクトリの確認
ls -lh workspace/etx_results/.archive/$(date +%Y%m)/

# 最新の結果を表示
ls -t workspace/etx_results/.archive/$(date +%Y%m)/ | head -1 | xargs -I {} cat "workspace/etx_results/.archive/$(date +%Y%m)/{}"
```

---

## オプション: レガシーGUI自動操作ツール

SSH方式が標準実装です。GUI自動操作ツール（xdotoolベース）は `scripts/.legacy/` に移動されました。

詳細は [scripts/.legacy/README.md](../scripts/.legacy/README.md) を参照してください。

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

### スクリプト実行エラー: Permission denied

**症状**: `bash: ./scripts/claude_to_ga53pd01.sh: Permission denied`

**解決方法**:
```bash
# 実行権限を追加
chmod +x scripts/claude_to_ga53pd01.sh

# すべてのスクリプトに一括で追加
chmod +x scripts/*.sh
```

### 結果ファイルが見つからない

**原因**: アーカイブディレクトリが存在しない、または日付が異なる

**解決方法**:
```bash
# アーカイブディレクトリの作成
mkdir -p workspace/etx_results/.archive

# すべてのアーカイブを確認
find workspace/etx_results/.archive -type f -name "*.txt" | sort -r | head -5

# 最新の結果を表示
find workspace/etx_results/.archive -type f -name "*.txt" -printf '%T@ %p\n' | sort -rn | head -1 | cut -d' ' -f2- | xargs cat
```

### スクリプト実行が遅い

**原因**: SSH接続の確立に時間がかかっている

**解決方法**:

1. **SSH ControlMasterを有効化（接続再利用）**:

   `~/.ssh/config` に追加:
   ```ssh-config
   Host *
     ControlMaster auto
     ControlPath ~/.ssh/cm-%r@%h:%p
     ControlPersist 10m
   ```

2. **DNS解決の高速化**:

   `/etc/hosts` に追加（要root権限）:
   ```
   10.108.64.1 palladium_bastion
   ```

3. **接続確認**:
   ```bash
   # 初回接続（コントロールマスター確立）
   time ssh ga53pd01 'echo test'
   # 2回目以降は高速になる
   time ssh ga53pd01 'echo test'
   ```

---

## 次のステップ

セットアップが完了したら:

1. **実際のタスクを実行**:
   ```bash
   # 例: ビルドスクリプトを作成して実行
   cat > /tmp/build_task.sh << 'EOF'
   #!/bin/bash
   cd /proj/tierivemu/work/henmi/gion
   make clean
   make all
   EOF

   ./scripts/claude_to_ga53pd01.sh /tmp/build_task.sh
   ```

2. **Claude Codeと統合**:
   - Claude Codeでタスクを自動生成
   - `claude_to_ga53pd01.sh` で実行
   - 結果を確認・分析

3. **独自のワークフローを構築**:
   - テスト自動実行
   - ログ分析
   - レポート生成

---

## 参考資料

- [プロジェクト概要](../README.md)
- [SSH直接取得テスト結果](ssh_direct_retrieval_test.md)
- [CLAUDE.md](../CLAUDE.md) - Claude Code向けガイド

## サポート

問題が発生した場合:
1. このガイドのトラブルシューティングセクションを確認
2. プロジェクトのIssueを検索
3. 新しいIssueを作成して詳細を報告
