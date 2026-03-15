= インストール

== 動作要件

Claude Code を利用するには以下が必要です：

- *OS*：macOS 13.0 以降、Ubuntu 20.04+ / Debian 10+、Windows 10/11
- *メモリ*：4GB 以上の RAM
- *ネットワーク*：インターネット接続（必須）
- *Anthropic アカウント*：Max、Team、Enterprise、または Console アカウント

== ネイティブインストール（推奨）

自動アップデート機能付きのネイティブインストーラが推奨です：

=== macOS / Linux

```bash
curl -fsSL https://claude.ai/install.sh | bash
```

=== Windows（PowerShell）

```powershell
irm https://claude.ai/install.ps1 | iex
```

=== Windows（コマンドプロンプト）

```cmd
curl -fsSL https://claude.ai/install.cmd -o install.cmd && install.cmd && del install.cmd
```

== その他のインストール方法

=== Homebrew（macOS）

```bash
brew install --cask claude-code
```

手動アップデートが必要です（`brew upgrade --cask claude-code`）。

=== WinGet（Windows）

```powershell
winget install Anthropic.ClaudeCode
```

=== npm（非推奨）

```bash
npm install -g @anthropic-ai/claude-code
```

npm 経由は非推奨になりました。ネイティブインストーラへの移行を推奨します。

== インストールの確認

```bash
claude --version
```

問題がある場合は診断コマンドを実行します：

```bash
claude doctor
```

== 認証

初回起動時に認証が必要です：

```bash
claude
```

ブラウザが開くので Anthropic アカウントでログインします。

=== 認証方法の種類

#table(
  columns: (auto, 1fr),
  align: (left, left),
  table.header([*方法*], [*説明*]),
  [Anthropic アカウント], [デフォルト。ブラウザ認証],
  [API キー], [`ANTHROPIC_API_KEY` 環境変数を設定],
  [Amazon Bedrock], [`CLAUDE_CODE_USE_BEDROCK=1` を設定],
  [Google Vertex AI], [`CLAUDE_CODE_USE_VERTEX=1` を設定],
  [SSO], [`claude auth login --sso` で組織の SSO を利用],
)

API キーを使う場合：

```bash
export ANTHROPIC_API_KEY="sk-ant-..."
claude
```

=== 認証コマンド

```bash
claude auth login     # ログイン
claude auth logout    # ログアウト
claude auth status    # 認証状態を確認
```

== アップデート

ネイティブインストールの場合は自動アップデートされます。
手動で更新する場合：

```bash
claude update
```

== Claude Code on the Web

ブラウザ上で Claude Code を利用する方法もあります。
claude.ai にアクセスし、Claude Code を有効にすると、
Web 上のターミナル環境で同様の操作が可能です。

- ローカル環境のセットアップが不要
- すぐに試すことができる
- `/teleport` でターミナルセッションに移行可能
