= コマンドと設定

== スラッシュコマンド一覧

Claude Code では `/` で始まるスラッシュコマンドが利用できます。
`/` を入力するとコマンドメニューが表示されます。

=== 基本コマンド

#table(
  columns: (auto, 1fr),
  align: (left, left),
  table.header([*コマンド*], [*説明*]),
  [`/help`], [ヘルプを表示],
  [`/exit`], [Claude Code を終了],
  [`/clear`], [会話履歴をクリア],
  [`/compact`], [会話を要約して圧縮],
  [`/context`], [現在のコンテキスト使用量を表示],
  [`/status`], [アカウントとセッション情報を表示],
  [`/cost`], [トークン使用量とコストを表示],
)

=== モデルと設定

#table(
  columns: (auto, 1fr),
  align: (left, left),
  table.header([*コマンド*], [*説明*]),
  [`/model`], [モデルを切り替え],
  [`/effort`], [推論の深さを調整（low/medium/high/max）],
  [`/permissions`], [権限設定を管理],
  [`/config`], [設定を変更],
  [`/terminal-setup`], [ターミナルのキーボードショートカットを設定],
  [`/vim`], [Vim モードの有効/無効],
  [`/theme`], [出力テーマをカスタマイズ],
  [`/statusline`], [ステータスラインの表示設定],
)

=== プロジェクトと会話

#table(
  columns: (auto, 1fr),
  align: (left, left),
  table.header([*コマンド*], [*説明*]),
  [`/init`], [CLAUDE.md を初期化・再生成],
  [`/memory`], [CLAUDE.md と自動メモリを表示・編集],
  [`/resume`], [過去の会話を選択して再開],
  [`/rename`], [現在のセッション名を変更],
  [`/add-dir`], [セッション中に作業ディレクトリを追加],
  [`/btw`], [履歴に残らないサイドクエスチョン],
)

=== 高度な機能

#table(
  columns: (auto, 1fr),
  align: (left, left),
  table.header([*コマンド*], [*説明*]),
  [`/agents`], [サブエージェントの作成・管理],
  [`/mcp`], [MCP サーバーの管理],
  [`/hooks`], [フックの確認・管理],
  [`/ide`], [IDE に接続（VS Code, JetBrains）],
  [`/desktop`], [セッションを Claude Desktop に引き渡し],
  [`/teleport`], [Web セッションをターミナルに移行],
)

=== ビルトインスキル

#table(
  columns: (auto, 1fr),
  align: (left, left),
  table.header([*コマンド*], [*説明*]),
  [`/batch <指示>`], [大規模な並列変更を実行],
  [`/simplify`], [直近の変更をレビュー・改善],
  [`/debug`], [問題のトラブルシューティング],
  [`/loop <間隔> <プロンプト>`], [プロンプトを定期実行],
)

== CLAUDE.md による設定

`CLAUDE.md` はプロジェクトのルートに置く設定ファイルです。
Claude Code が作業する際の規約や手順を自然言語で記述します：

```markdown
# CLAUDE.md

## プロジェクト概要
TypeScript + React のフロントエンドアプリケーション。

## ビルド・テスト
- ビルド: npm run build
- テスト: npm test
- リント: npm run lint

## 規約
- 関数名はキャメルケース
- コンポーネントは関数コンポーネントで書く
- テストは __tests__/ に配置
```

`/init` コマンドで Claude に自動生成させることもできます。

== CLAUDE.md の配置場所とスコープ

#table(
  columns: (auto, 1fr),
  align: (left, left),
  table.header([*場所*], [*スコープ*]),
  [`./CLAUDE.md`], [プロジェクト共有（Git 管理推奨）],
  [`.claude/CLAUDE.md`], [プロジェクトの個人設定],
  [`~/.claude/CLAUDE.md`], [全プロジェクト共通の個人設定],
  [`/etc/claude-code/CLAUDE.md`], [組織全体（管理者設定）],
)

== 自動メモリ

Claude Code はセッション中に学んだことを自動的に記憶します。

- デフォルトで有効
- `~/.claude/projects/<project>/memory/` に保存
- セッション開始時に最初の200行が読み込まれる
- `/memory` コマンドで確認・編集可能

== 設定ファイル

`.claude/settings.json` でプロジェクトレベルの設定を管理します：

```json
{
  "model": "sonnet",
  "effortLevel": "high",
  "permissions": {
    "allow": ["Read", "Bash(npm run *)"],
    "deny": ["Bash(rm *)"]
  }
}
```

=== 設定の優先順位（高い順）

+ 管理ポリシー（組織設定）
+ CLI 引数（`--allowedTools` など）
+ プロジェクトローカル（`.claude/settings.local.json`）
+ プロジェクト共有（`.claude/settings.json`）
+ ユーザー設定（`~/.claude/settings.json`）

== 環境変数

Claude Code の動作に影響する主な環境変数：

#table(
  columns: (auto, 1fr),
  align: (left, left),
  table.header([*変数*], [*説明*]),
  [`ANTHROPIC_API_KEY`], [API キー],
  [`CLAUDE_CODE_USE_BEDROCK`], [Amazon Bedrock を使用],
  [`CLAUDE_CODE_USE_VERTEX`], [Google Vertex AI を使用],
  [`ANTHROPIC_MODEL`], [デフォルトモデルを指定],
  [`CLAUDE_CODE_MAX_TURNS`], [最大ターン数を制限],
)
