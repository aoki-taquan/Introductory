= IDE 連携

== VS Code 拡張機能

=== インストール

VS Code のコマンドパレット（`Cmd+Shift+X` / `Ctrl+Shift+X`）で
"Claude Code" を検索してインストールします。Cursor IDE にも対応しています。

=== 主な機能

- *インライン diff ビューア*：変更内容を IDE 内で確認
- *ファイル参照*：`@` でファイルやフォルダを行番号付きで参照
- *コマンドパレット統合*：IDE のコマンドパレットから操作
- *マルチタブ*：複数の会話を同時に管理
- *プランレビュー*：実行前にプランを確認
- *権限モード切替*：UI から権限モードを変更
- *MCP サーバー管理*：`/mcp` コマンドで管理
- *会話の再開*：過去の会話を選択して再開

=== キーボードショートカット

#table(
  columns: (auto, 1fr),
  align: (left, left),
  table.header([*ショートカット*], [*動作*]),
  [`Cmd+Esc` / `Ctrl+Esc`], [エディタと Claude のフォーカスを切替],
  [`Option+K` / `Alt+K`], [`@` 参照を行番号付きで挿入],
  [`Cmd+Shift+Esc` / `Ctrl+Shift+Esc`], [新しいタブで開く],
  [`Cmd+N` / `Ctrl+N`], [新しい会話を開始],
)

== JetBrains プラグイン

=== 対応 IDE

IntelliJ IDEA、PyCharm、WebStorm、PhpStorm、GoLand、
Android Studio などの JetBrains IDE に対応しています。

=== インストール

JetBrains IDE のプラグインマーケットプレイスから
"Claude Code" をインストールします。

=== 主な機能

- *クイック起動*：`Cmd+Esc` / `Ctrl+Esc`
- *IDE diff ビューア統合*：変更差分を IDE 内で確認
- *選択コンテキスト共有*：選択したコードを Claude に送信
- *ファイル参照*：`Cmd+Option+K` / `Alt+Ctrl+K`
- *診断エラー共有*：IDE のエラーを Claude に直接共有

== Claude Desktop 連携

`/desktop` コマンドで現在のセッションを Claude Desktop アプリに引き渡せます。
逆に、Web セッションからターミナルへの移行は `/teleport` を使います。

== ターミナルからの利用

IDE を使わない場合でも、任意のターミナルエミュレータから利用できます。
tmux や screen と組み合わせると、バックグラウンドで長時間のタスクを
実行させることも可能です：

```bash
tmux new-session -s claude
claude
```

== リモートコントロール

別のデバイス（スマートフォンやブラウザ）からターミナルセッションを操作できます：

```bash
# リモートコントロールサーバーを起動
claude remote-control --name "My Session"

# 別のデバイスから接続
claude --remote-control
```
