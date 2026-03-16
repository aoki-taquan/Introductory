= インストール

== 動作要件

vibe-local を利用するには以下が必要です：

#table(
  columns: (auto, 1fr),
  align: (left, left),
  table.header([*項目*], [*要件*]),
  [OS], [macOS（Apple Silicon M1+）、Windows 10/11、Linux],
  [Python], [Python 3.8 以降],
  [RAM], [4GB 以上（使用モデルにより異なる）],
  [GPU], [NVIDIA GPU 推奨（Windows/Linux）],
  [Ollama], [別途インストール必要],
)

=== モデル別メモリ要件

詳細は「モデルと設定」章を参照してください。目安として、最低 4GB の RAM があれば軽量モデルで動作します。

== インストール手順

=== ステップ 1：ターミナルを開く

- *Mac*：`Cmd+Space` → 「ターミナル」を検索して起動
- *Windows*：PowerShell を管理者として起動

=== ステップ 2：インストールスクリプトを実行

==== Mac / Linux / WSL

```bash
curl -fsSL https://raw.githubusercontent.com/ochyai/vibe-local/main/install.sh | bash
```

==== Windows PowerShell

```powershell
Invoke-Expression (Invoke-RestMethod -Uri https://raw.githubusercontent.com/ochyai/vibe-local/main/install.ps1)
```

インストールスクリプトは以下を自動的に行います：

- Ollama のインストール（未インストールの場合）
- デフォルトモデル（`qwen3:8b`）のダウンロード
- `vibe-local` コマンドのセットアップ

=== ステップ 3：新しいターミナルで起動

インストール後、新しいターミナルウィンドウを開いて起動します：

```bash
vibe-local
```

== Ollama の手動インストール

インストールスクリプトは通常 Ollama を自動インストールします。
ネットワーク制限や権限の問題でスクリプトが失敗した場合、
または Ollama を手動で管理したい場合は以下の手順に従います。

=== macOS / Linux

```bash
curl -fsSL https://ollama.ai/install.sh | sh
```

=== Windows

Ollama 公式サイト（https://ollama.ai）からインストーラをダウンロードして実行します。

=== モデルの取得

```bash
# 標準モデル（16GB RAM 推奨）
ollama pull qwen3:8b

# 軽量モデル（8GB RAM）
ollama pull qwen3:1.7b

# 高精度モデル（96GB RAM）
ollama pull qwen3-coder:30b
```

== インストールの確認

```bash
# Ollama の動作確認
ollama list

# vibe-local の起動確認
vibe-local --help
```

== 設定ファイルの場所

初回起動後、設定ファイルが以下に作成されます：

```
~/.config/vibe-local/config
```

モデルの変更や詳細設定はこのファイルで行います（詳細は「モデルと設定」章を参照）。
