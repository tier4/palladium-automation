# MCP Server セットアップガイド

このプロジェクトでは、Claude Code (CLI) と Claude Desktop (デスクトップアプリ) で異なる設定方法を使用します。

## Claude Code (CLI) - 推奨

Claude Code CLIを使用する場合は、`claude mcp add`コマンドでMCPサーバーを追加します。

### セットアップ手順

1. **プロジェクトディレクトリに移動**:
```bash
cd /home/khenmi/palladium-automation
```

2. **MCPサーバーを追加**:
```bash
claude mcp add --transport stdio etx-automation -- node /home/khenmi/palladium-automation/mcp-servers/etx-automation/index.js
```

3. **確認**:
```bash
claude mcp list
# 出力: etx-automation: node /home/khenmi/palladium-automation/mcp-servers/etx-automation/index.js - ✓ Connected
```

### 設定の保存先

設定は`~/.claude.json`ファイルのプロジェクトセクションに自動的に保存されます：

```json
{
  "projects": {
    "/home/khenmi/palladium-automation": {
      "mcpServers": {
        "etx-automation": {
          "type": "stdio",
          "command": "node",
          "args": [
            "/home/khenmi/palladium-automation/mcp-servers/etx-automation/index.js"
          ],
          "env": {}
        }
      }
    }
  }
}
```

### MCPサーバーの管理

```bash
# リスト表示
claude mcp list

# サーバーの削除
claude mcp remove etx-automation

# サーバーの詳細確認
claude mcp get etx-automation
```

## Claude Desktop (デスクトップアプリ)

Claude Desktopアプリケーションを使用する場合は、設定ファイルを手動で編集します。

### セットアップ手順

1. **設定ファイルを作成**:
```bash
mkdir -p ~/.config/Claude
cp /home/khenmi/palladium-automation/docs/claude_desktop_config.json.example.desktop ~/.config/Claude/claude_desktop_config.json
```

2. **設定ファイルを編集**:
```bash
nano ~/.config/Claude/claude_desktop_config.json
```

内容:
```json
{
  "mcpServers": {
    "etx-automation": {
      "command": "node",
      "args": ["/home/khenmi/palladium-automation/mcp-servers/etx-automation/index.js"],
      "env": {
        "DEBUG": "0"
      }
    }
  }
}
```

3. **Claude Desktopを再起動**

## 重要な注意事項

- **Claude Code (CLI)**: `~/.claude.json`を使用（プロジェクトごと）
- **Claude Desktop**: `~/.config/Claude/claude_desktop_config.json`を使用（グローバル）
- パスは環境に合わせて調整してください
- 両方の環境で使用する場合は、それぞれ個別に設定が必要です
