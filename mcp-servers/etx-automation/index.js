#!/usr/bin/env node

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";
import { spawn } from 'child_process';
import { promises as fs } from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

// ESモジュールで__dirnameを取得
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// プロジェクトルートを取得
const PROJECT_ROOT = path.resolve(__dirname, '../..');
const AUTOMATION_SCRIPT = path.join(PROJECT_ROOT, 'scripts/etx_automation.sh');
const CLAUDE_TO_ETX_SCRIPT = path.join(PROJECT_ROOT, 'scripts/claude_to_etx.sh');
const TASK_DIR = path.join(PROJECT_ROOT, '.claude/etx_tasks');

// MCPサーバーの作成
const server = new Server({
  name: "etx-automation",
  version: "1.0.0"
}, {
  capabilities: {
    tools: {}
  }
});

// ディレクトリの作成
await fs.mkdir(TASK_DIR, { recursive: true });

// コマンド実行ヘルパー
function executeCommand(command, args, options = {}) {
  return new Promise((resolve, reject) => {
    const proc = spawn(command, args, {
      cwd: options.cwd || PROJECT_ROOT,
      env: { ...process.env, ...options.env }
    });

    let stdout = '';
    let stderr = '';

    proc.stdout.on('data', (data) => {
      stdout += data.toString();
      if (options.onStdout) {
        options.onStdout(data.toString());
      }
    });

    proc.stderr.on('data', (data) => {
      stderr += data.toString();
      if (options.onStderr) {
        options.onStderr(data.toString());
      }
    });

    proc.on('error', (error) => {
      reject(new Error(`Failed to execute command: ${error.message}`));
    });

    proc.on('close', (code) => {
      if (code === 0) {
        resolve({ stdout, stderr, exitCode: code });
      } else {
        reject(new Error(`Command failed with exit code ${code}\n${stderr}`));
      }
    });
  });
}

// ツールのリストを返す
server.setRequestHandler(ListToolsRequestSchema, async () => {
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
              description: "The bash command to execute on ETX"
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
              description: "The complete bash script content to execute"
            },
            description: {
              type: "string",
              description: "A brief description of what this script does"
            }
          },
          required: ["script_content"]
        }
      },
      {
        name: "activate_etx_window",
        description: "Activate the ETX terminal window (bring it to the front)",
        inputSchema: {
          type: "object",
          properties: {}
        }
      },
      {
        name: "list_windows",
        description: "List all available windows on the local system",
        inputSchema: {
          type: "object",
          properties: {}
        }
      },
      {
        name: "test_etx_connection",
        description: "Test the connection to ETX server",
        inputSchema: {
          type: "object",
          properties: {}
        }
      }
    ]
  };
});

// ツール呼び出しハンドラー
server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;

  try {
    // execute_on_etx: ETXで単一コマンド実行
    if (name === "execute_on_etx") {
      if (!args.command) {
        throw new Error("Command is required");
      }

      const result = await executeCommand(AUTOMATION_SCRIPT, ['exec', args.command]);

      return {
        content: [{
          type: "text",
          text: `Command executed on ETX: ${args.command}\n\n` +
                `Output:\n${result.stdout}\n` +
                (result.stderr ? `\nErrors/Warnings:\n${result.stderr}` : '')
        }]
      };
    }

    // run_script_on_etx: スクリプト転送・実行・結果回収
    if (name === "run_script_on_etx") {
      if (!args.script_content) {
        throw new Error("Script content is required");
      }

      // 一時スクリプトファイルを作成
      const timestamp = Date.now();
      const scriptPath = path.join(TASK_DIR, `task_${timestamp}.sh`);

      await fs.writeFile(scriptPath, args.script_content, { mode: 0o755 });

      try {
        const result = await executeCommand(CLAUDE_TO_ETX_SCRIPT, [scriptPath]);

        return {
          content: [{
            type: "text",
            text: `Script executed on ETX\n\n` +
                  `Description: ${args.description || 'N/A'}\n\n` +
                  `Result:\n${result.stdout}\n` +
                  (result.stderr ? `\nErrors/Warnings:\n${result.stderr}` : '')
          }]
        };
      } finally {
        // スクリプトファイルを保持（デバッグ用）
      }
    }

    // activate_etx_window: ETXウィンドウのアクティブ化
    if (name === "activate_etx_window") {
      await executeCommand(AUTOMATION_SCRIPT, ['activate']);

      return {
        content: [{
          type: "text",
          text: "ETX window activated successfully"
        }]
      };
    }

    // list_windows: ウィンドウ一覧表示
    if (name === "list_windows") {
      const result = await executeCommand(AUTOMATION_SCRIPT, ['list']);

      return {
        content: [{
          type: "text",
          text: `Available windows:\n\n${result.stdout}`
        }]
      };
    }

    // test_etx_connection: 接続テスト
    if (name === "test_etx_connection") {
      const result = await executeCommand(AUTOMATION_SCRIPT, ['test']);

      return {
        content: [{
          type: "text",
          text: `ETX Connection Test:\n\n${result.stdout}\n` +
                (result.stderr ? `\n${result.stderr}` : '')
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

// サーバー起動
const transport = new StdioServerTransport();
await server.connect(transport);

console.error('ETX Automation MCP Server started');
console.error(`Project Root: ${PROJECT_ROOT}`);
console.error(`Automation Script: ${AUTOMATION_SCRIPT}`);
console.error(`Task Directory: ${TASK_DIR}`);
