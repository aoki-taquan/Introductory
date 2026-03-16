= モデルと設定

== 利用可能なモデル

vibe-local は Ollama 経由でローカルモデルを利用します。
`localhost:11434` に対して OpenAI Chat API 互換のリクエストを送信します。

=== 推奨モデル

#table(
  columns: (auto, auto, auto, 1fr),
  align: (left, left, left, left),
  table.header([*モデル名*], [*必要 RAM*], [*用途*], [*特徴*]),
  [`qwen3-coder:30b`], [96GB], [高精度コード生成], [最高品質、大規模プロジェクト向け],
  [`qwen3:8b`], [16GB], [標準開発作業], [バランス重視、推奨],
  [`qwen3:1.7b`], [8GB], [軽量タスク], [低スペック環境向け],
)

=== サイドカーモデル

vibe-local は、権限確認や初期化などの軽量タスクに「サイドカーモデル」を使います。
メインモデルより軽いモデルが自動選択されるため、リソースの節約になります。

== モデルの変更

=== 起動時に指定

```bash
vibe-local --model qwen3:8b
```

=== 設定ファイルで変更

```bash
# 設定ファイルを開く
nano ~/.config/vibe-local/config
```

設定ファイルの例：

```ini
model=qwen3:8b
sidecar_model=qwen3:1.7b
```

== 設定ファイル

設定ファイルは `~/.config/vibe-local/config` に保存されています。

=== 主な設定項目

#table(
  columns: (auto, 1fr),
  align: (left, left),
  table.header([*設定項目*], [*説明*]),
  [`model`], [使用するメインモデル名],
  [`sidecar_model`], [サイドカータスク用モデル名],
  [`ollama_host`], [Ollama のホスト URL（デフォルト: localhost:11434）],
)

== 環境変数

デバッグや動作調整に使える環境変数：

#table(
  columns: (auto, 1fr),
  align: (left, left),
  table.header([*環境変数*], [*説明*]),
  [`VIBE_LOCAL_DEBUG=1`], [デバッグモードを有効化（詳細ログを出力）],
  [`VIBE_DEBUG_TUI=1`], [TUI（ターミナル UI）のデバッグ情報を表示],
  [`VIBE_NO_SCROLL=1`], [スクロール領域機能を無効化（ターミナル互換性問題の解決）],
)

使い方の例：

```bash
VIBE_LOCAL_DEBUG=1 vibe-local
```

== Ollama の設定

=== Ollama サーバーの起動確認

```bash
ollama serve
```

通常は自動起動しますが、問題がある場合は手動で起動します。

=== インストール済みモデルの確認

```bash
ollama list
```

=== モデルの追加ダウンロード

```bash
ollama pull qwen3:8b
ollama pull qwen3:1.7b
```

=== Ollama のホスト変更

デフォルト以外のホストで Ollama を動かす場合、設定ファイルで変更します：

```ini
ollama_host=http://192.168.1.100:11434
```

== セッションデータの保存場所

セッション履歴は JSONL 形式で保存されます：

```
~/.config/vibe-local/sessions/
```

古いセッションデータを削除することで、ディスク容量を節約できます。

== ターミナル表示の調整

vibe-local は DECSTBM（スクロール領域制御）を使って
固定フッターを表示します。ターミナルの互換性問題が発生した場合は：

```bash
VIBE_NO_SCROLL=1 vibe-local
```

これにより、スクロール領域機能が無効になります。
