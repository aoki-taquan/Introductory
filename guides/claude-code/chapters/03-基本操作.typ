= 基本操作

== 起動と終了

プロジェクトディレクトリで `claude` を実行すると対話モードが始まります：

```bash
cd your-project
claude
```

初回起動時には初期プロンプトを指定することもできます：

```bash
claude "このプロジェクトの構成を説明して"
```

終了するには以下のいずれかを使います：

- `/exit` と入力
- `Ctrl+C` を2回押す
- `Ctrl+D`（EOF）を送信

== プロンプトの送信

起動後、自然言語でプロンプトを入力します：

```
> このプロジェクトの構成を説明して
```

=== 複数行の入力

複数行のプロンプトを書きたい場合：

#table(
  columns: (auto, 1fr),
  align: (left, left),
  table.header([*方法*], [*対応ターミナル*]),
  [`Shift+Enter`], [iTerm2, WezTerm, Ghostty, Kitty],
  [`Option+Enter`], [macOS デフォルト],
  [`\` + `Enter`], [すべてのターミナル],
  [`Ctrl+J`], [すべてのターミナル],
)

=== ファイル参照

`@` でファイルやフォルダを参照できます（オートコンプリート対応）：

```
> @src/auth.ts のバグを修正して
```

=== ダイレクト Bash モード

`!` で始めるとシェルコマンドを直接実行できます：

```
> !npm test
```

== ワンショットモード

対話モードに入らず、単発でコマンドを実行できます：

```bash
claude -p "このリポジトリのREADMEを要約して"
```

`-p`（`--print`）フラグを使うと結果を標準出力に表示して終了します。
パイプとの組み合わせも可能です：

```bash
cat error.log | claude -p "このエラーの原因を分析して"
```

出力形式を指定できます：

```bash
claude -p "テストを実行して" --output-format json
```

== 会話の管理

=== 会話の再開

前回の会話を再開するには `--continue`（`-c`）フラグを使います：

```bash
claude -c
```

=== セッションの選択

過去の会話を一覧から選んで再開する場合は `--resume` を使います：

```bash
claude --resume
```

=== セッションの命名

セッションに名前を付けると後で見つけやすくなります：

```bash
claude -n "auth-refactor"
```

=== サイドクエスチョン

本筋の会話を汚さずに質問したい場合は `/btw` を使います：

```
/btw TypeScript の enum と const enum の違いは？
```

== コンテキストの管理

Claude Code は会話が長くなるとコンテキストウィンドウの上限に近づきます。

- *自動圧縮*：古いメッセージは自動的に要約・圧縮される
- *手動圧縮*：`/compact` コマンドで圧縮
- *クリア*：`/clear` で会話をリセット
- *コンテキスト確認*：`/context` で現在の使用量を確認
- *巻き戻し*：`Esc` を2回押すとコードや会話を巻き戻せる

== モデルの選択

`/model` コマンドまたは起動時フラグでモデルを切り替えられます：

#table(
  columns: (auto, auto, 1fr),
  align: (left, left, left),
  table.header([*エイリアス*], [*モデル*], [*用途*]),
  [`sonnet`], [Sonnet 4.6], [日常的なタスク、バランス重視],
  [`opus`], [Opus 4.6], [複雑な推論、高品質],
  [`haiku`], [Haiku 4], [軽いタスク、低コスト],
  [`sonnet[1m]`], [Sonnet + 1M コンテキスト], [大規模コードベース],
  [`opus[1m]`], [Opus + 1M コンテキスト], [複雑な大規模プロジェクト],
)

```bash
# 起動時に指定
claude --model opus

# セッション中に切り替え
/model sonnet
```

== 推論の深さ（Effort Level）

Claude がどの程度深く考えるかを調整できます：

- `low`：高速、簡単なタスク向け
- `medium`：標準
- `high`：複雑なタスク向け
- `max`：最大限の推論（Opus 4.6 のみ）

```bash
claude --effort high
```

セッション中は `/effort` コマンドで変更できます。
拡張思考のオン/オフは `Alt+T`（macOS: `Option+T`）で切り替えられます。
