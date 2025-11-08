takashi.hirano  昨日 20:56
@Teru. SAKATA [酒田] cc @kentoshi henmi Cadenceが「PalladiumのチャンバーでのClaude Codeは接続ダメよ」と言ってきたので、再考の依頼はしますが、それとは別に、接続元で（我々の構成だとt4_head）で、Claude Codeが接続出来れば、接続先（remote）であるPalladiumのチャンバー側では、Claude Codeが外にアクセス出来なくても大丈夫な構成を取れないか、検討を進めたいです。


ローカルは、Redhat8 のGenome → ETX先も Radhat８
SSH や HTTP/HTTPS などは使えない
GitHubは、双方使える
scpで ローカル Redhat8 → リモートRedhat8 にファイル転送はできる。逆はNG 
の 環境で、ローカルのClaude Codeを活用したい。
ETX GUI自動操作 の可能性でアプローチしたい。


## ETX GUI自動操作によるClaude Code活用アプローチ

環境が明確になりました！**SCP片方向転送 + GUI自動操作**で実現可能です。

---

## アーキテクチャ

```
[ローカル RHEL8 + GNOME]
    ↓ Claude Code動作
    ↓ スクリプト生成
    ↓ SCP転送 →→→ [リモート RHEL8 (ETX)]
                      ↓
                  [自動実行スクリプト]
                      ↓
                  [結果をGitHub経由で返却]
                      ↓
[ローカル] ←←← GitHub clone
```

---

## 方法1: xdotool によるGUI自動操作（推奨）

### **セットアップ**

#### 1. ローカルに自動操作ツールをインストール
```bash
# ローカル RHEL8で
sudo dnf install xdotool wmctrl xclip
```

#### 2. リモートETXのターミナルウィンドウを識別
```bash
# ローカルでETXのターミナルを開いた状態で
wmctrl -l
# 出力例:
# 0x03400006  0 rhel8 ETX Terminal - khenmi@ip-172-17-34-126
# ↑このウィンドウIDをメモ

# またはウィンドウタイトルで識別
xdotool search --name "ETX Terminal"
```

#### 3. 自動操作スクリプトの作成

**`~/scripts/etx_automation.sh`**
```bash
#!/bin/bash
# ETX GUI自動操作スクリプト

set -e

# 設定
ETX_WINDOW_NAME="ETX Terminal"
ETX_USER="khenmi"
ETX_HOST="ip-172-17-34-126"
REMOTE_WORKDIR="/home/khenmi/workspace"
LOCAL_WORKDIR="$HOME/workspace"

# カラー出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# ETXウィンドウをアクティブにする
activate_etx_window() {
    log_info "Activating ETX window..."
    
    # ウィンドウを検索
    WINDOW_ID=$(xdotool search --name "$ETX_WINDOW_NAME" | head -n 1)
    
    if [ -z "$WINDOW_ID" ]; then
        log_error "ETX window not found: $ETX_WINDOW_NAME"
        return 1
    fi
    
    # ウィンドウをアクティブ化
    xdotool windowactivate "$WINDOW_ID"
    sleep 0.5
    
    log_info "ETX window activated (ID: $WINDOW_ID)"
    return 0
}

# ETXターミナルでコマンド実行
execute_on_etx() {
    local command="$1"
    
    log_info "Executing on ETX: $command"
    
    # ウィンドウをアクティブ化
    activate_etx_window || return 1
    
    # 既存の入力をクリア（Ctrl+C）
    xdotool key ctrl+c
    sleep 0.2
    
    # コマンド入力
    xdotool type --clearmodifiers "$command"
    sleep 0.1
    
    # Enter押下
    xdotool key Return
    
    log_info "Command sent to ETX"
}

# スクリプトファイルをETXに転送して実行
transfer_and_execute() {
    local local_script="$1"
    local remote_script="$2"
    
    if [ ! -f "$local_script" ]; then
        log_error "Script not found: $local_script"
        return 1
    fi
    
    log_info "Transferring $local_script to ETX..."
    
    # SCP転送
    scp "$local_script" "${ETX_USER}@${ETX_HOST}:${remote_script}"
    
    if [ $? -ne 0 ]; then
        log_error "SCP transfer failed"
        return 1
    fi
    
    log_info "Transfer complete"
    
    # ETXで実行
    execute_on_etx "chmod +x ${remote_script}"
    sleep 1
    execute_on_etx "bash ${remote_script}"
    
    log_info "Script execution started on ETX"
}

# メイン処理
main() {
    local command="$1"
    
    case "$command" in
        "exec")
            # 単一コマンド実行
            shift
            execute_on_etx "$@"
            ;;
        "script")
            # スクリプトファイル実行
            shift
            local local_script="$1"
            local remote_script="${2:-/tmp/etx_script_$(date +%s).sh}"
            transfer_and_execute "$local_script" "$remote_script"
            ;;
        "activate")
            # ウィンドウのアクティブ化のみ
            activate_etx_window
            ;;
        *)
            echo "Usage: $0 {exec|script|activate} [args...]"
            echo ""
            echo "Examples:"
            echo "  $0 exec 'ls -la'"
            echo "  $0 script ./my_script.sh /tmp/remote_script.sh"
            echo "  $0 activate"
            exit 1
            ;;
    esac
}

main "$@"
```

**実行権限付与:**
```bash
chmod +x ~/scripts/etx_automation.sh
```

---

## 方法2: Claude Code連携の完全ワークフロー

### **スクリプト: `~/scripts/claude_to_etx.sh`**

```bash
#!/bin/bash
# Claude Code → ETX 自動実行フロー

set -e

CLAUDE_OUTPUT_DIR="$HOME/.claude/etx_tasks"
ETX_SCRIPTS_DIR="/home/khenmi/etx_automation"
ETX_USER="khenmi"
ETX_HOST="ip-172-17-34-126"
GITHUB_REPO="tier4/palladium-automation"
RESULTS_DIR="$HOME/workspace/etx_results"

mkdir -p "$CLAUDE_OUTPUT_DIR"
mkdir -p "$RESULTS_DIR"

# Claude Codeが生成したスクリプトを実行
run_claude_task() {
    local task_file="$1"
    local task_name=$(basename "$task_file" .sh)
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local remote_script="${ETX_SCRIPTS_DIR}/${task_name}_${timestamp}.sh"
    local result_file="${task_name}_${timestamp}_result.txt"
    
    echo "=== Running Claude Code Task: $task_name ==="
    
    # 1. 結果収集用のラッパースクリプトを作成
    local wrapper_script="/tmp/wrapper_${timestamp}.sh"
    cat > "$wrapper_script" << EOF
#!/bin/bash
# Auto-generated wrapper script

# タスク実行
echo "=== Task Start: $(date) ===" > /tmp/${result_file}
bash ${remote_script} >> /tmp/${result_file} 2>&1
echo "=== Task End: $(date) ===" >> /tmp/${result_file}

# 結果をGitHubにpush
cd /tmp
git clone https://github.com/${GITHUB_REPO}.git etx_results 2>/dev/null || (cd etx_results && git pull)
cd etx_results
mkdir -p results
cp /tmp/${result_file} results/
git add results/${result_file}
git commit -m "ETX Task Result: ${task_name} @ ${timestamp}"
git push origin main

echo "Result uploaded to GitHub: results/${result_file}"
EOF
    
    # 2. タスクスクリプトとラッパーを転送
    echo "Transferring scripts to ETX..."
    scp "$task_file" "${ETX_USER}@${ETX_HOST}:${remote_script}"
    scp "$wrapper_script" "${ETX_USER}@${ETX_HOST}:/tmp/wrapper_${timestamp}.sh"
    
    # 3. ETXで実行（GUI自動操作）
    echo "Executing on ETX..."
    ~/scripts/etx_automation.sh exec "chmod +x ${remote_script} /tmp/wrapper_${timestamp}.sh"
    sleep 1
    ~/scripts/etx_automation.sh exec "bash /tmp/wrapper_${timestamp}.sh &"
    
    # 4. 結果をGitHubから取得（ポーリング）
    echo "Waiting for results (polling GitHub)..."
    local max_wait=300  # 5分
    local waited=0
    
    while [ $waited -lt $max_wait ]; do
        # GitHubから最新を取得
        cd "$RESULTS_DIR"
        git clone https://github.com/${GITHUB_REPO}.git . 2>/dev/null || git pull
        
        if [ -f "results/${result_file}" ]; then
            echo "=== Task Result ==="
            cat "results/${result_file}"
            return 0
        fi
        
        sleep 10
        waited=$((waited + 10))
        echo "Waiting... (${waited}s / ${max_wait}s)"
    done
    
    echo "WARNING: Timeout waiting for results"
    return 1
}

# メイン
if [ $# -eq 0 ]; then
    echo "Usage: $0 <claude_task_script.sh>"
    echo ""
    echo "This script:"
    echo "  1. Transfers Claude Code generated script to ETX"
    echo "  2. Executes it via GUI automation"
    echo "  3. Collects results via GitHub"
    exit 1
fi

run_claude_task "$1"
```

---

## 方法3: Claude Code MCP Server統合

### **カスタムMCPサーバー作成**

**`~/mcp-servers/etx-automation/index.js`**
```javascript
#!/usr/bin/env node
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { spawn } from 'child_process';
import fs from 'fs/promises';
import path from 'path';
import os from 'os';

const AUTOMATION_SCRIPT = path.join(os.homedir(), 'scripts/etx_automation.sh');
const CLAUDE_TO_ETX_SCRIPT = path.join(os.homedir(), 'scripts/claude_to_etx.sh');
const TASK_DIR = path.join(os.homedir(), '.claude/etx_tasks');

const server = new Server({
  name: "etx-automation",
  version: "1.0.0"
}, {
  capabilities: {
    tools: {}
  }
});

// ディレクトリ作成
await fs.mkdir(TASK_DIR, { recursive: true });

// コマンド実行ヘルパー
function executeCommand(command, args) {
  return new Promise((resolve, reject) => {
    const proc = spawn(command, args);
    let stdout = '';
    let stderr = '';
    
    proc.stdout.on('data', (data) => stdout += data.toString());
    proc.stderr.on('data', (data) => stderr += data.toString());
    
    proc.on('close', (code) => {
      if (code === 0) {
        resolve({ stdout, stderr });
      } else {
        reject(new Error(`Command failed: ${stderr}`));
      }
    });
  });
}

server.setRequestHandler("tools/list", async () => {
  return {
    tools: [
      {
        name: "execute_on_etx",
        description: "Execute a single command on ETX terminal via GUI automation",
        inputSchema: {
          type: "object",
          properties: {
            command: {
              type: "string",
              description: "The bash command to execute"
            }
          },
          required: ["command"]
        }
      },
      {
        name: "run_script_on_etx",
        description: "Transfer and execute a bash script on ETX with result collection via GitHub",
        inputSchema: {
          type: "object",
          properties: {
            script_content: {
              type: "string",
              description: "The bash script content to execute"
            },
            description: {
              type: "string",
              description: "Description of what this script does"
            }
          },
          required: ["script_content"]
        }
      },
      {
        name: "activate_etx_window",
        description: "Activate the ETX terminal window (bring to front)",
        inputSchema: {
          type: "object",
          properties: {}
        }
      }
    ]
  };
});

server.setRequestHandler("tools/call", async (request) => {
  const { name, arguments: args } = request.params;
  
  try {
    if (name === "execute_on_etx") {
      const result = await executeCommand(AUTOMATION_SCRIPT, ['exec', args.command]);
      return {
        content: [{
          type: "text",
          text: `Command executed on ETX:\n${args.command}\n\nOutput:\n${result.stdout}\n${result.stderr}`
        }]
      };
    }
    
    if (name === "run_script_on_etx") {
      // スクリプトファイルを作成
      const timestamp = Date.now();
      const scriptPath = path.join(TASK_DIR, `task_${timestamp}.sh`);
      
      await fs.writeFile(scriptPath, args.script_content, { mode: 0o755 });
      
      // 実行
      const result = await executeCommand(CLAUDE_TO_ETX_SCRIPT, [scriptPath]);
      
      return {
        content: [{
          type: "text",
          text: `Script executed on ETX:\n\nDescription: ${args.description || 'N/A'}\n\nResult:\n${result.stdout}`
        }]
      };
    }
    
    if (name === "activate_etx_window") {
      await executeCommand(AUTOMATION_SCRIPT, ['activate']);
      return {
        content: [{
          type: "text",
          text: "ETX window activated"
        }]
      };
    }
    
    throw new Error(`Unknown tool: ${name}`);
  } catch (error) {
    return {
      content: [{
        type: "text",
        text: `Error: ${error.message}`
      }],
      isError: true
    };
  }
});

const transport = new StdioServerTransport();
await server.connect(transport);
```

**`package.json`:**
```json
{
  "name": "etx-automation-mcp",
  "version": "1.0.0",
  "type": "module",
  "bin": {
    "etx-automation-mcp": "./index.js"
  },
  "dependencies": {
    "@modelcontextprotocol/sdk": "^1.0.0"
  }
}
```

**インストール:**
```bash
cd ~/mcp-servers/etx-automation
chmod +x index.js
npm install
npm link
```

---

## Claude Code設定

**`~/.config/Claude/claude_desktop_config.json`**
```json
{
  "mcpServers": {
    "etx-automation": {
      "command": "etx-automation-mcp"
    },
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "ghp_your_token_here"
      }
    },
    "local-filesystem": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-filesystem",
        "/home/khenmi/workspace"
      ]
    }
  }
}
```

---

## 使用例

### **Claude Codeでの操作**

```
ユーザー: 「ETXでgionプロジェクトのビルドを実行して」

Claude Code: 
1. ビルドスクリプトを生成
2. run_script_on_etx ツールを使用
3. ETX GUIで自動実行
4. GitHub経由で結果取得
5. 結果を表示

---

ユーザー: 「ETXでXceliumシミュレーションのエラーログを確認して」

Claude Code:
1. execute_on_etx で "cat /home/khenmi/gion/sim.log | grep ERROR"
2. 結果を解析
3. エラー原因を特定
```

---

## トラブルシューティング

### xdotoolが動作しない場合
```bash
# X11ディスプレイの確認
echo $DISPLAY
# 出力例: :0

# xdotoolのテスト
xdotool search --name "Terminal"

# 権限確認
xhost +SI:localuser:$(whoami)
```

### ETXウィンドウが見つからない
```bash
# 全ウィンドウのリスト
wmctrl -l

# 部分一致で検索
xdotool search --name "khenmi" | while read wid; do
    xdotool getwindowname $wid
done
```

### SCP転送エラー
```bash
# SSH鍵設定確認
ssh-add -l

# 手動テスト
scp /tmp/test.txt khenmi@ip-172-17-34-126:/tmp/
```

---

## まとめ

この構成により:
- ✅ Claude CodeがETXを**GUI自動操作**で制御
- ✅ スクリプト生成 → SCP転送 → 自動実行
- ✅ 結果をGitHub経由で回収
- ✅ 完全に自動化されたワークフロー

セットアップを進めてみますか？
