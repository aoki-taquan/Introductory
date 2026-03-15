= IDE 連携

== VS Code 拡張機能

Claude Code は VS Code の拡張機能として利用できます。
VS Code のターミナル内で `claude` を実行するか、
拡張機能をインストールして統合環境を利用します。

=== インストール

VS Code の拡張機能マーケットプレイスで "Claude Code" を検索してインストールします。

=== 主な機能

- VS Code のターミナルパネル内での対話
- エディタで開いているファイルのコンテキスト共有
- ステータスバーでの状態表示
- コマンドパレットからの操作

== JetBrains プラグイン

IntelliJ IDEA、WebStorm、PyCharm などの JetBrains IDE でも利用可能です。

=== インストール

JetBrains IDE のプラグインマーケットプレイスから
"Claude Code" をインストールします。

=== 使い方

IDE のターミナルパネルで `claude` を実行するか、
プラグインが提供するパネルから直接操作します。

== ターミナルからの利用

IDE を使わない場合でも、任意のターミナルエミュレータから利用できます。
tmux や screen と組み合わせると、バックグラウンドで長時間のタスクを
実行させることも可能です：

```bash
# tmux セッション内で実行
tmux new-session -s claude
claude
```
