# Serena MCP セットアップガイド

このプロジェクトでは、**Serena MCP**を使用してVerilog/SystemVerilogコードの解析を行います。

## 前提条件

- Serena MCPが `/opt/eda/serena-verilog/current/` にインストールされていること
- `uv` ツールが `/opt/eda/uv/current/bin/uv` にインストールされていること
- `verible` が利用可能であること（オプション）

## Claude Code (CLI) - 推奨

Claude Code CLIを使用する場合は、`claude-serena`エイリアスまたは`claude mcp add`コマンドでSerena MCPを追加します。

### セットアップ手順

1. **プロジェクトディレクトリに移動**:
```bash
cd /home/khenmi/palladium-automation
```

2. **Serena MCPを追加**:
```bash
# 方法1: エイリアスを使用（~/.bashrcに設定済みの場合）
claude-serena

# 方法2: 手動で追加
claude mcp add serena -- /opt/eda/uv/current/bin/uv run --directory /opt/eda/serena-verilog/current/ serena start-mcp-server --context ide-assistant --project $(pwd) --enable-web-dashboard false
```

3. **確認**:
```bash
claude mcp list
# 出力: serena: /opt/eda/uv/current/bin/uv run ... - ✓ Connected
```

### 設定の保存先

設定は`~/.claude.json`ファイルのプロジェクトセクションに自動的に保存されます：

```json
{
  "projects": {
    "/home/khenmi/palladium-automation": {
      "mcpServers": {
        "serena": {
          "type": "stdio",
          "command": "/opt/eda/uv/current/bin/uv",
          "args": [
            "run",
            "--directory",
            "/opt/eda/serena-verilog/current/",
            "serena",
            "start-mcp-server",
            "--context",
            "ide-assistant",
            "--project",
            "/home/khenmi/palladium-automation",
            "--enable-web-dashboard",
            "false"
          ],
          "env": {}
        }
      }
    }
  }
}
```

### Serena MCPの管理

```bash
# リスト表示
claude mcp list

# サーバーの削除
claude mcp remove serena

# 再追加
claude-serena
```

### Serena MCPの機能

Serena MCPが有効になると、以下の機能が利用可能になります：

- **Verilogファイル検索**: `mcp__serena__find_file`
- **シンボル解析**: `mcp__serena__get_symbols_overview`, `mcp__serena__find_symbol`
- **パターン検索**: `mcp__serena__search_for_pattern`
- **コード編集**: `mcp__serena__replace_symbol_body`, `mcp__serena__insert_after_symbol`
- **メモリ管理**: `mcp__serena__write_memory`, `mcp__serena__read_memory`

Claude Codeが自動的にこれらのツールを使用して、hornetプロジェクトのVerilog/SystemVerilogコードを解析します。

## 重要な注意事項

- **プロジェクトルート**: Serena MCPは`--project`で指定したディレクトリをプロジェクトルートとして認識します
- **hornetディレクトリ**: `palladium-automation/hornet/`内のVerilog/SystemVerilogファイルを解析可能
- **`.serena/project.yml`**: Serenaの設定ファイル（言語: verilog、ignored_pathsなど）
- **メモリファイル**: `.serena/memories/`に自動的にプロジェクト情報が保存されます

## トラブルシューティング

### Serena MCPが接続できない

```bash
# Serenaのインストール確認
ls -la /opt/eda/serena-verilog/current/

# uvの確認
/opt/eda/uv/current/bin/uv --version

# Serena MCPの手動起動テスト
cd /home/khenmi/palladium-automation
/opt/eda/uv/current/bin/uv run --directory /opt/eda/serena-verilog/current/ serena start-mcp-server --help
```

### Verilogファイルが見つからない

```bash
# hornetプロジェクトが存在するか確認
ls -la /home/khenmi/palladium-automation/hornet/

# hornetがない場合はクローン
cd /home/khenmi/palladium-automation
git clone https://github.com/tier4/hornet.git
```
