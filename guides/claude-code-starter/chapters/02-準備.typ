= 準備

== 必要なもの

Claude Code を使い始めるために必要なものは2つだけです：

+ *Anthropic アカウント*（Claude.ai Max プランなど）
+ *ターミナル*（最初から入っています）

== ターミナルとは

Claude Code はターミナルから操作します。ターミナルとは、コンピュータに文字でコマンドを入力する画面です。
黒い（または暗い）背景に文字が並んでいるあれです。

難しそうに見えますが、使うのは「コマンドを打って Enter を押す」だけです。

=== ターミナルの開き方

#table(
  columns: (auto, 1fr),
  align: (left, left),
  table.header([*OS*], [*開き方*]),
  [macOS], [`Cmd+Space` → 「ターミナル」と入力 → Enter],
  [Windows], [`Win+R` → `powershell` と入力 → Enter],
  [Linux], [`Ctrl+Alt+T` またはアプリ一覧から「端末」],
)

開くと `$` や `%` や `>` で終わる行が表示されます。これが「入力待ち」の状態です。

=== 基本的なターミナル操作

Claude Code を使うために最低限知っておくべきことだけ覚えましょう。

*フォルダを移動する（cd）：*
```bash
cd Desktop           # Desktop フォルダに移動
cd my-project        # my-project フォルダに移動
cd ..                # 一つ上のフォルダに移動
```

*現在地を確認する（pwd）：*
```bash
pwd
```

*フォルダの中身を見る（ls）：*
```bash
ls
```

これだけで Claude Code は使えます。

== アカウントの準備

Claude Code を使うには Anthropic のアカウントが必要です。

現在対応しているプランは以下の通りです：

- *Claude.ai Max プラン*（個人向け、月額課金）
- *Team / Enterprise プラン*（チーム・法人向け）
- *Anthropic Console アカウント*（API 利用者向け）

ChatGPT Plus のような感覚で、有料プランへの加入が必要です。
まだの方は claude.ai から登録してください。

== インストール

ターミナルを開いて、以下のコマンドをコピペして Enter を押します。

=== macOS / Linux

```bash
curl -fsSL https://claude.ai/install.sh | bash
```

=== Windows（PowerShell）

```powershell
irm https://claude.ai/install.ps1 | iex
```

コマンドを実行するとインストールが自動で始まります。
1〜2分ほど待てば完了します。

=== インストール完了の確認

```bash
claude --version
```

バージョン番号が表示されれば成功です。

== ログイン

インストールできたら、Claude Code を起動してみます：

```bash
claude
```

初回起動時にブラウザが自動的に開きます。
Anthropic アカウントでログインすれば準備完了です。
ChatGPT にログインするのと同じ感覚です。

== ブラウザ版（インストール不要）

「まず試してみたい」という場合は、ブラウザ版があります。
claude.ai にアクセスして Claude Code を有効にすると、
インストールなしで同じように使えます。

慣れてきたらローカルにインストールすることをおすすめします。
