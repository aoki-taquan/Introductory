= インストール

== 動作要件

Claude Code を利用するには以下が必要です：

- *OS*：macOS 10.15 以降、Ubuntu 20.04+ / Debian 10+ などの Linux
- *Node.js*：18 以上
- *Anthropic アカウント*：API キーまたは Claude の有料プラン（Max / Team / Enterprise）

== npm でインストール

もっとも一般的なインストール方法です：

```bash
npm install -g @anthropic-ai/claude-code
```

インストール後、任意のディレクトリで `claude` コマンドを実行します：

```bash
cd your-project
claude
```

初回起動時に認証が求められます。ブラウザが開くので、Anthropic アカウントでログインしてください。

== 認証方法

Claude Code は複数の認証方法に対応しています：

- *Anthropic アカウント（デフォルト）*：`claude` 起動時にブラウザ認証
- *API キー*：環境変数 `ANTHROPIC_API_KEY` を設定
- *Amazon Bedrock*：`CLAUDE_CODE_USE_BEDROCK=1` を設定
- *Google Vertex AI*：`CLAUDE_CODE_USE_VERTEX=1` を設定

API キーを使う場合は以下のように設定します：

```bash
export ANTHROPIC_API_KEY="sk-ant-..."
claude
```

== アップデート

最新版へのアップデートは以下のコマンドで行います：

```bash
npm update -g @anthropic-ai/claude-code
```

== Claude Code on the Web

ブラウザ上で Claude Code を利用する方法もあります。claude.ai にアクセスし、
Claude Code を有効にすると、Web 上のターミナル環境で同様の操作が可能です。
ローカル環境のセットアップが不要で、すぐに試すことができます。
