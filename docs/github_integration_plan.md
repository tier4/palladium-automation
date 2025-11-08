# GitHub経由の結果取得機能 - 実装プラン

## 現状分析

### 既存の実装（scripts/claude_to_etx.sh）

**実装済みの部分**:
- ✅ ラッパースクリプト生成機能
- ✅ GitHub経由の結果アップロード（リモート側）
- ✅ GitHub経由の結果取得（ローカル側）
- ✅ ポーリングメカニズム（5分間、10秒間隔）

**問題点**:
- ❌ **SCP転送に依存している** (Line 138-148)
  - `scp $task_file ${ETX_USER}@${ETX_HOST}:${remote_script}`
  - ETXリモートホストへのSCP転送は不可能
- ❌ GUI自動操作（xdotool）との統合が必要

### 既存の動作フロー（SCP方式 - 動作しない）

```
[ローカル]
  ↓ タスクスクリプト生成
  ↓ ラッパースクリプト生成
  ↓ SCP転送 (❌ 動作しない)
  →→→ [リモート ETX]
          ↓ スクリプト実行
          ↓ 結果を/tmpに保存
          ↓ GitHubにpush
          ↓
[ローカル] ←←← GitHub経由で結果取得（ポーリング）
```

---

## 解決策: xdotool方式への統合

### 新しい動作フロー

```
[ローカル RHEL8]
    ↓ Claude Code (スクリプト生成)
    ↓ ラッパースクリプト生成（GitHub結果アップロード機能付き）
    ↓ ETX Xterm起動 (Start Xterm)
    ↓ xdotool (ウィンドウアクティブ化)
    ↓ xdotool type (行単位でecho >> file)
    →→→ [リモート ETX/Palladium (ga53ut01)]
            ↓ タスクスクリプトファイル作成
            ↓ ラッパースクリプトファイル作成
            ↓ chmod +x (実行権限付与)
            ↓ bash wrapper.sh (ラッパー実行)
            ↓ ├─ タスク実行
            ↓ ├─ 結果を/tmpに保存
            ↓ └─ GitHubに結果をpush
            ↓
[ローカル] ←←← GitHub経由で結果取得（ポーリング）
            ↓ git pull (10秒間隔)
            ↓ 結果ファイル確認
            ↓ 見つかったら表示
```

---

## 実装プラン

### Phase 1: etx_automation.sh の拡張

#### 1.1 新しい関数の追加: `transfer_and_execute_with_github()`

**目的**: タスクスクリプトとラッパースクリプトの両方を転送して実行

**実装箇所**: `scripts/etx_automation.sh`

**機能**:
1. タスクスクリプトを行単位で転送（既存のロジック）
2. ラッパースクリプトを行単位で転送（新規）
3. 両方に実行権限付与
4. ラッパースクリプトを実行（バックグラウンド）

**使用例**:
```bash
./scripts/etx_automation.sh script-with-github \
    /tmp/task_script.sh \
    /tmp/wrapper_script.sh \
    remote_task.sh \
    remote_wrapper.sh
```

**実装イメージ**:
```bash
transfer_and_execute_with_github() {
    local task_script="$1"
    local wrapper_script="$2"
    local remote_task="$3"
    local remote_wrapper="$4"

    # 1. タスクスクリプト転送
    log_info "Transferring task script..."
    transfer_script_line_by_line "$task_script" "$remote_task"

    # 2. ラッパースクリプト転送
    log_info "Transferring wrapper script..."
    transfer_script_line_by_line "$wrapper_script" "$remote_wrapper"

    # 3. 実行権限付与
    log_info "Setting execute permissions..."
    xdotool type --delay 10 --clearmodifiers "chmod +x ${remote_task} ${remote_wrapper}"
    xdotool key Return
    sleep 1

    # 4. ラッパー実行（バックグラウンド）
    log_info "Executing wrapper script..."
    xdotool type --delay 10 --clearmodifiers "bash ${remote_wrapper} &"
    xdotool key Return

    log_info "Script execution started in background"
}

# 行単位転送の共通関数化
transfer_script_line_by_line() {
    local local_script="$1"
    local remote_script="$2"

    # ディレクトリ作成
    local remote_dir=$(dirname "$remote_script")
    if [ "$remote_dir" != "/tmp" ] && [ "$remote_dir" != "." ]; then
        xdotool type --delay 10 --clearmodifiers "mkdir -p $remote_dir"
        xdotool key Return
        sleep 0.5
    fi

    # ファイル削除
    xdotool type --delay 10 --clearmodifiers "rm -f ${remote_script}"
    xdotool key Return
    sleep 0.5

    # 行単位で追記
    while IFS= read -r line; do
        escaped_line="${line//\'/\'\\\'\'}"
        xdotool type --delay 5 --clearmodifiers "echo '${escaped_line}' >> ${remote_script}"
        xdotool key Return
        sleep 0.2
    done < "$local_script"

    sleep 1
}
```

---

### Phase 2: claude_to_etx.sh の修正

#### 2.1 SCP転送部分をxdotool方式に置き換え

**変更箇所**: Line 135-168

**Before (SCP方式)**:
```bash
# 2. タスクスクリプトとラッパーを転送
log_info "Transferring scripts to ETX..."

if ! scp "$task_file" "${ETX_USER}@${ETX_HOST}:${remote_script}" 2>&1; then
    log_error "Failed to transfer task script"
    rm -f "$wrapper_script"
    return 1
fi

if ! scp "$wrapper_script" "${ETX_USER}@${ETX_HOST}:/tmp/wrapper_${timestamp}.sh" 2>&1; then
    log_error "Failed to transfer wrapper script"
    rm -f "$wrapper_script"
    return 1
fi

log_info "Transfer complete"
rm -f "$wrapper_script"

# 3. ETXで実行（GUI自動操作）
log_info "Executing on ETX via GUI automation..."

# 実行権限付与
if ! "$ETX_AUTOMATION_SCRIPT" exec "chmod +x ${remote_script} /tmp/wrapper_${timestamp}.sh"; then
    log_error "Failed to set execute permissions"
    return 1
fi
sleep 1

# バックグラウンドでラッパースクリプト実行
if ! "$ETX_AUTOMATION_SCRIPT" exec "bash /tmp/wrapper_${timestamp}.sh &"; then
    log_error "Failed to execute wrapper script"
    return 1
fi

log_info "Script execution started on ETX"
```

**After (xdotool方式)**:
```bash
# 2. タスクスクリプトとラッパーを転送・実行（GUI自動操作）
log_info "Transferring and executing scripts on ETX via GUI automation..."

local remote_task_script="\$HOME/.etx_tmp/task_${timestamp}.sh"
local remote_wrapper_script="\$HOME/.etx_tmp/wrapper_${timestamp}.sh"

if ! "$ETX_AUTOMATION_SCRIPT" script-with-github \
    "$task_file" \
    "$wrapper_script" \
    "$remote_task_script" \
    "$remote_wrapper_script"; then
    log_error "Failed to transfer and execute scripts"
    rm -f "$wrapper_script"
    return 1
fi

log_info "Scripts transferred and execution started on ETX"
rm -f "$wrapper_script"
```

#### 2.2 ラッパースクリプトの修正

**変更箇所**: Line 69-128

**重要な修正**:
1. リモートスクリプトパスを `$HOME/.etx_tmp/` 配下に変更
2. 結果ファイルも `$HOME/.etx_tmp/` に保存
3. GitHub認証の確認処理を追加

**修正後のラッパースクリプト**:
```bash
cat > "$wrapper_script" << 'EOF_WRAPPER'
#!/bin/bash
# Auto-generated wrapper script for ETX automation with GitHub result collection

TASK_SCRIPT="__REMOTE_TASK_SCRIPT__"
RESULT_FILE="__RESULT_FILE__"
GITHUB_REPO="__GITHUB_REPO__"
RESULT_PATH="$HOME/.etx_tmp/${RESULT_FILE}"

echo "=== Wrapper Script Started ===" | tee "${RESULT_PATH}"
echo "Date: $(date)" | tee -a "${RESULT_PATH}"
echo "Hostname: $(hostname)" | tee -a "${RESULT_PATH}"
echo "User: $(whoami)" | tee -a "${RESULT_PATH}"
echo "Task Script: ${TASK_SCRIPT}" | tee -a "${RESULT_PATH}"
echo "" | tee -a "${RESULT_PATH}"

# タスク実行
echo "=== Task Start: $(date) ===" | tee -a "${RESULT_PATH}"
if bash "${TASK_SCRIPT}" >> "${RESULT_PATH}" 2>&1; then
    echo "=== Task End: $(date) ===" | tee -a "${RESULT_PATH}"
    echo "Status: SUCCESS" | tee -a "${RESULT_PATH}"
    EXIT_CODE=0
else
    EXIT_CODE=$?
    echo "=== Task End: $(date) ===" | tee -a "${RESULT_PATH}"
    echo "Status: FAILED (exit code: ${EXIT_CODE})" | tee -a "${RESULT_PATH}"
fi
echo "" | tee -a "${RESULT_PATH}"

# GitHub認証確認
echo "=== Checking GitHub Authentication ===" | tee -a "${RESULT_PATH}"
if ! git config --global user.name >/dev/null 2>&1; then
    echo "WARNING: Git user.name not configured" | tee -a "${RESULT_PATH}"
    git config --global user.name "ETX Automation"
fi

if ! git config --global user.email >/dev/null 2>&1; then
    echo "WARNING: Git user.email not configured" | tee -a "${RESULT_PATH}"
    git config --global user.email "etx@automation.local"
fi

# 結果をGitHubにpush
echo "=== Uploading results to GitHub ===" | tee -a "${RESULT_PATH}"
cd "$HOME/.etx_tmp" || exit 1

# GitHubリポジトリのクローンまたは更新
if [ -d "etx_results/.git" ]; then
    echo "Updating existing repository..." | tee -a "${RESULT_PATH}"
    cd etx_results
    git pull origin main >> "${RESULT_PATH}" 2>&1 || {
        echo "WARNING: git pull failed, will try to re-clone" | tee -a "${RESULT_PATH}"
        cd ..
        rm -rf etx_results
        git clone "https://github.com/${GITHUB_REPO}.git" etx_results >> "${RESULT_PATH}" 2>&1
        cd etx_results
    }
else
    echo "Cloning repository..." | tee -a "${RESULT_PATH}"
    git clone "https://github.com/${GITHUB_REPO}.git" etx_results >> "${RESULT_PATH}" 2>&1 || {
        echo "ERROR: Failed to clone repository" | tee -a "${RESULT_PATH}"
        exit 1
    }
    cd etx_results
fi

# 結果ディレクトリの作成
mkdir -p results

# 結果ファイルのコピー
cp "${RESULT_PATH}" results/ || {
    echo "ERROR: Failed to copy result file" | tee -a "${RESULT_PATH}"
    exit 1
}

git add "results/${RESULT_FILE}"

# コミットとプッシュ
git commit -m "ETX Task Result: ${RESULT_FILE}" >> "${RESULT_PATH}" 2>&1 || {
    echo "WARNING: git commit failed (possibly nothing to commit)" | tee -a "${RESULT_PATH}"
}

if git push origin main >> "${RESULT_PATH}" 2>&1; then
    echo "SUCCESS: Result uploaded to GitHub: results/${RESULT_FILE}" | tee -a "${RESULT_PATH}"
else
    echo "ERROR: Failed to push to GitHub" | tee -a "${RESULT_PATH}"
    echo "Check GitHub authentication and network connectivity" | tee -a "${RESULT_PATH}"
fi

echo "=== Wrapper Script Completed (Exit Code: ${EXIT_CODE}) ===" | tee -a "${RESULT_PATH}"
exit ${EXIT_CODE}
EOF_WRAPPER
```

---

### Phase 3: GitHub結果取得の最適化

#### 3.1 ローカル側のポーリング改善

**変更箇所**: Line 171-214

**改善点**:
1. 初回のクローン/pullを確実に実行
2. エラー処理の改善
3. タイムアウト時のメッセージ改善

**実装**:
```bash
# 4. 結果をGitHubから取得（ポーリング）
log_info "Waiting for results from GitHub (polling every ${poll_interval}s, max ${max_wait}s)..."

# GitHubリポジトリのセットアップ
cd "$RESULTS_DIR"
if [ ! -d ".git" ]; then
    log_info "Cloning GitHub repository for the first time..."
    if ! git clone "https://github.com/${GITHUB_REPO}.git" . >/dev/null 2>&1; then
        log_error "Failed to clone GitHub repository"
        log_info "Please check:"
        log_info "  1. GitHub repository exists: https://github.com/${GITHUB_REPO}"
        log_info "  2. You have access to the repository"
        log_info "  3. GitHub authentication is configured"
        return 1
    fi
fi

local waited=0
while [ $waited -lt $max_wait ]; do
    log_debug "Polling GitHub (${waited}s / ${max_wait}s)..."

    # GitHubから最新を取得
    if git pull origin main >/dev/null 2>&1; then
        log_debug "Successfully pulled from GitHub"
    else
        log_warn "Failed to pull from GitHub (will retry)"
    fi

    # 結果ファイルの確認
    if [ -f "results/${result_file}" ]; then
        log_info "=== Task Result Found ==="
        echo ""
        cat "results/${result_file}"
        echo ""
        log_info "Result file saved to: $RESULTS_DIR/results/${result_file}"

        # 成功/失敗の判定
        if grep -q "Status: SUCCESS" "results/${result_file}"; then
            log_info "Task completed successfully on ETX"
            return 0
        else
            log_error "Task failed on ETX (see result above)"
            return 1
        fi
    fi

    sleep $poll_interval
    waited=$((waited + poll_interval))

    if [ $((waited % 30)) -eq 0 ]; then
        log_info "Still waiting... (${waited}s / ${max_wait}s)"
    fi
done

log_error "Timeout waiting for results after ${max_wait}s"
log_info "The task may still be running on ETX, or GitHub push failed"
log_info "Troubleshooting steps:"
log_info "  1. Check ETX Xterm window to see if script is still running"
log_info "  2. Check GitHub repository: https://github.com/${GITHUB_REPO}/tree/main/results"
log_info "  3. Check ETX GitHub authentication: ssh to ETX and run 'git config --list'"
log_info "  4. Check local result file on ETX: \$HOME/.etx_tmp/${result_file}"
return 1
```

---

### Phase 4: MCP Server統合

#### 4.1 run_script_on_etx ツールの修正

**変更箇所**: `mcp-servers/etx-automation/index.js` Line 164-187

**修正内容**:
- `claude_to_etx.sh` を呼び出すだけでOK（スクリプトが既にxdotool対応に修正されているため）
- 結果の出力を改善

**実装**:
```javascript
case 'run_script_on_etx':
  // スクリプトをETXで実行し、GitHub経由で結果を回収
  if (!args.script_content) {
    throw new Error('script_content is required');
  }

  // 一時スクリプトファイルを作成
  const timestamp = Date.now();
  const scriptPath = `/tmp/mcp_task_${timestamp}.sh`;
  fs.writeFileSync(scriptPath, args.script_content, { mode: 0o755 });

  try {
    // claude_to_etx.shを実行（xdotool方式で転送・実行・GitHub結果取得）
    const result = await executeCommand(CLAUDE_TO_ETX_SCRIPT, [scriptPath]);

    // 一時ファイル削除
    fs.unlinkSync(scriptPath);

    return {
      content: [
        {
          type: "text",
          text: `Script executed on ETX with GitHub result collection:\n\n` +
                `Description: ${args.description || 'N/A'}\n\n` +
                `Result:\n${result.stdout}\n` +
                (result.stderr ? `\nWarnings:\n${result.stderr}` : '')
        }
      ]
    };
  } catch (error) {
    // エラー時も一時ファイル削除
    if (fs.existsSync(scriptPath)) {
      fs.unlinkSync(scriptPath);
    }
    throw error;
  }
```

---

## テスト計画

### Phase 1: 基本テスト

#### Test 1: 簡単なタスク実行
```bash
# テストスクリプト作成
cat > /tmp/test_github_integration.sh << 'EOF'
#!/bin/bash
echo "=== GitHub Integration Test ==="
echo "Hostname: $(hostname)"
echo "Date: $(date)"
echo "User: $(whoami)"
echo "Test completed successfully"
EOF

# 実行
./scripts/claude_to_etx.sh /tmp/test_github_integration.sh
```

**期待される結果**:
1. ETX Xtermでスクリプトが実行される
2. 結果が`$HOME/.etx_tmp/test_github_integration_TIMESTAMP_result.txt`に保存される
3. 結果がGitHubにpushされる
4. ローカルでGitHubから結果を取得して表示

#### Test 2: エラーハンドリング
```bash
# エラーを含むテストスクリプト
cat > /tmp/test_error.sh << 'EOF'
#!/bin/bash
echo "Before error"
exit 1
echo "After error (should not appear)"
EOF

./scripts/claude_to_etx.sh /tmp/test_error.sh
```

**期待される結果**:
- Status: FAILED が記録される
- エラーコードが記録される
- GitHub経由で結果が正常に取得される

#### Test 3: 長時間実行タスク
```bash
# 30秒間のテスト
cat > /tmp/test_long_running.sh << 'EOF'
#!/bin/bash
echo "Starting long running task..."
for i in {1..10}; do
    echo "Progress: $i/10"
    sleep 3
done
echo "Task completed"
EOF

./scripts/claude_to_etx.sh /tmp/test_long_running.sh
```

**期待される結果**:
- ポーリングが正常に動作
- タスク完了後に結果が取得される

---

## 前提条件と事前準備

### 1. GitHub リポジトリの準備

**リポジトリ**: `tier4/gion-automation`

**必要な設定**:
```bash
# リポジトリが存在しない場合は作成
# GitHubでリポジトリを作成: https://github.com/tier4/gion-automation

# ローカル環境での初回クローン確認
cd ~/palladium-automation/workspace
git clone https://github.com/tier4/gion-automation.git etx_results
cd etx_results
mkdir -p results
git add results/.gitkeep
git commit -m "Initial commit: create results directory"
git push origin main
```

### 2. ETX環境でのGitHub認証設定

**ETX Xtermで実行**:
```bash
# Git設定確認
git config --global user.name
git config --global user.email

# 設定されていない場合
git config --global user.name "ETX Automation"
git config --global user.email "etx@automation.local"

# GitHub認証確認（SSHキーまたはPersonal Access Token）
# 1. SSHキー方式
ssh -T git@github.com

# 2. HTTPS + Personal Access Token方式
git clone https://github.com/tier4/gion-automation.git
# トークン入力プロンプトが表示される
```

### 3. ローカル環境のGitHub認証設定

```bash
# 同様にGitHub認証を設定
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"

# リポジトリへのアクセス確認
cd ~/palladium-automation/workspace/etx_results
git pull origin main
```

---

## 実装スケジュール

### Week 1: コア機能実装
- Day 1-2: `etx_automation.sh` の拡張（`script-with-github`コマンド追加）
- Day 3-4: `claude_to_etx.sh` の修正（xdotool方式への移行）
- Day 5: 基本テスト実施

### Week 2: 統合と最適化
- Day 1-2: MCPサーバーの更新
- Day 3: エラーハンドリング改善
- Day 4-5: 包括的なテスト実施

### Week 3: ドキュメント整備
- Day 1-2: README、setup.md、plan.md更新
- Day 3: トラブルシューティングガイド作成
- Day 4: 使用例集作成
- Day 5: 最終レビューと統合テスト

---

## リスクと対策

### Risk 1: GitHub認証の問題
**リスク**: ETX環境でGitHub認証が正しく設定されていない

**対策**:
- 事前チェックスクリプトを作成
- ラッパースクリプトに認証確認処理を追加
- トラブルシューティングガイドに詳細手順を記載

### Risk 2: ネットワーク遅延
**リスク**: GitHub経由の結果取得に時間がかかる

**対策**:
- ポーリング間隔を調整可能に（環境変数）
- タイムアウト時間を延長可能に
- 進捗表示を改善

### Risk 3: xdotool転送の安定性
**リスク**: 大きなスクリプトの転送が失敗する

**対策**:
- 転送後のファイル確認処理を追加
- リトライロジックの実装
- チャンク分割転送の検討

### Risk 4: 複数タスクの同時実行
**リスク**: 複数のタスクが同時に実行されると結果が混在する

**対策**:
- タイムスタンプ + プロセスIDでユニークなファイル名を生成済み
- ディレクトリ構造を改善（タスクIDごとのサブディレクトリ）

---

## 成功基準

### 機能要件
- [ ] タスクスクリプトとラッパースクリプトの両方をxdotoolで転送可能
- [ ] ETX環境でタスクが正常に実行される
- [ ] 実行結果がGitHubに正常にpushされる
- [ ] ローカル環境でGitHubから結果を取得できる
- [ ] エラー時も結果が正常に記録される

### 性能要件
- [ ] スクリプト転送時間: 15秒以内（100行程度のスクリプト）
- [ ] GitHub結果取得時間: タスク完了後30秒以内
- [ ] 全体ワークフロー: 1分以内（簡単なタスクの場合）

### 品質要件
- [ ] エラーハンドリングが適切に実装されている
- [ ] ログ出力が充実している
- [ ] タイムアウト処理が適切
- [ ] 複数ユーザーが同時に使用可能

---

## 次のステップ

1. **GitHub リポジトリの確認**
   - `tier4/gion-automation` が利用可能か確認
   - アクセス権限の確認

2. **ETX GitHub認証の確認**
   - ETX Xtermでgit pushが可能か確認

3. **実装開始**
   - Phase 1から順次実装

4. **テスト実施**
   - 基本テスト → 統合テスト → 負荷テスト

5. **ドキュメント更新**
   - 全ドキュメントに新機能を反映
