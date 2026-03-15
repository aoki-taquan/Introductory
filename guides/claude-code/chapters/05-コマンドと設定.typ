= コマンドと設定

== スラッシュコマンド一覧

Claude Code では `/` で始まるスラッシュコマンドが利用できます：

#table(
  columns: (auto, 1fr),
  align: (left, left),
  table.header([*コマンド*], [*説明*]),
  [`/help`], [ヘルプを表示],
  [`/exit`], [Claude Code を終了],
  [`/clear`], [会話履歴をクリア],
  [`/compact`], [会話を要約して圧縮],
  [`/model`], [使用するモデルを切り替え],
  [`/permissions`], [権限設定を管理],
  [`/status`], [現在のステータスを表示],
  [`/cost`], [セッションのトークン使用量とコストを表示],
  [`/doctor`], [インストール状態を診断],
  [`/config`], [設定を変更],
  [`/mcp`], [MCP サーバーの状態を確認],
  [`/review`], [コードレビューを実行],
  [`/init`], [CLAUDE.md を初期化],
)

== CLAUDE.md による設定

`CLAUDE.md` はプロジェクトのルートに置く設定ファイルです。
Claude Code が作業する際の規約や手順を自然言語で記述します：

```markdown
# CLAUDE.md

## プロジェクト概要
TypeScript + React のフロントエンドアプリケーション。

## ビルド
npm run build

## テスト
npm test

## 規約
- 関数名はキャメルケース
- コンポーネントは関数コンポーネントで書く
```

`/init` コマンドで Claude に自動生成させることもできます。

== CLAUDE.md の配置場所

CLAUDE.md は複数の場所に配置でき、それぞれスコープが異なります：

- *プロジェクトルート*（`./CLAUDE.md`）：チーム共有の設定
- *`.claude/` ディレクトリ内*（`.claude/CLAUDE.md`）：個人設定（`.gitignore` 推奨）
- *ホームディレクトリ*（`~/.claude/CLAUDE.md`）：全プロジェクト共通の個人設定

== 設定ファイル

`/config` コマンドまたは設定ファイルで動作をカスタマイズできます。
主な設定項目：

- *権限モード*：`allowedTools` で自動許可するツールを指定
- *テーマ*：ターミナルのカラーテーマ
- *通知*：タスク完了時の通知設定

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
