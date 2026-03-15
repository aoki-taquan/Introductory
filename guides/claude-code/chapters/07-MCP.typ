= MCP（Model Context Protocol）

== MCP とは

MCP（Model Context Protocol）は、AI モデルが外部のツールやデータソースと
連携するための標準プロトコルです。Claude Code は MCP クライアントとして動作し、
MCP サーバーが提供するツールを利用できます。

== MCP サーバーの追加

=== HTTP サーバー（推奨）

```bash
claude mcp add --transport http <名前> <URL>
```

例：Notion との連携

```bash
claude mcp add --transport http notion https://mcp.notion.com/mcp
```

=== Stdio サーバー（ローカル実行）

```bash
claude mcp add --transport stdio <名前> -- <コマンド> [引数]
```

例：Airtable との連携

```bash
claude mcp add --transport stdio airtable \
  --env AIRTABLE_API_KEY=YOUR_KEY \
  -- npx -y airtable-mcp-server
```

=== SSE サーバー（非推奨）

```bash
claude mcp add --transport sse <名前> <URL>
```

== サーバーのスコープ

MCP サーバーには3つのスコープがあります：

#table(
  columns: (auto, 1fr),
  align: (left, left),
  table.header([*スコープ*], [*説明*]),
  [Local], [自分だけ、現在のプロジェクトのみ（`~/.claude.json`）],
  [Project], [チーム共有（`.mcp.json` をリポジトリに含める）],
  [User], [自分の全プロジェクト（`~/.claude.json`）],
)

スコープの指定：

```bash
claude mcp add my-server -s local -- npx my-server
claude mcp add my-server -s project -- npx my-server
claude mcp add my-server -s global -- npx my-server
```

== サーバーの管理

```bash
# サーバー一覧を表示
claude mcp list

# サーバーの詳細を表示
claude mcp get my-server

# サーバーを削除
claude mcp remove my-server
```

対話モード内では `/mcp` コマンドでサーバーの状態を確認・管理できます。

== 活用例

MCP サーバーを活用すると以下のような連携が可能になります：

- *GitHub*：コードレビュー、PR 管理
- *Jira / Linear*：イシュートラッキング
- *データベース*：PostgreSQL、BigQuery へのクエリ
- *Sentry*：エラーモニタリング
- *Slack*：メッセージの送受信
- *Playwright*：ブラウザ自動操作
- *Notion*：ドキュメント管理
