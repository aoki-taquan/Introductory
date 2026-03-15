= MCP（Model Context Protocol）

== MCP とは

MCP（Model Context Protocol）は、AI モデルが外部のツールやデータソースと
連携するための標準プロトコルです。Claude Code は MCP クライアントとして動作し、
MCP サーバーが提供するツールを利用できます。

== MCP サーバーの設定

MCP サーバーは設定ファイルで定義します。
プロジェクトローカルの設定は `.claude/mcp.json` に記述します：

```json
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": [
        "-y",
        "@anthropic-ai/mcp-filesystem",
        "/path/to/directory"
      ]
    }
  }
}
```

グローバル設定は `~/.claude/mcp.json` に配置します。

== MCP サーバーの追加

`claude mcp add` コマンドで対話的にサーバーを追加できます：

```bash
# ローカル（プロジェクト）スコープで追加
claude mcp add my-server -s local -- npx my-mcp-server

# グローバルスコープで追加
claude mcp add my-server -s global -- npx my-mcp-server
```

== MCP サーバーの管理

```bash
# サーバー一覧を表示
claude mcp list

# サーバーの詳細を表示
claude mcp get my-server

# サーバーを削除
claude mcp remove my-server
```

対話モード内では `/mcp` コマンドでサーバーの状態を確認できます。

== 活用例

MCP サーバーを活用すると、以下のような連携が可能になります：

- *データベース*：SQL クエリの実行、スキーマの確認
- *Web 検索*：最新の技術ドキュメントの参照
- *外部 API*：Slack、GitHub Issues などとの連携
- *ファイルシステム*：特定ディレクトリへのアクセス制御
