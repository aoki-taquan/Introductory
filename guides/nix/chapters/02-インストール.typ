= インストール

== システム要件

Nixは以下の環境で動作する。

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header(
    [*項目*], [*要件*],
  ),
  [OS], [Linux（x86_64, aarch64）、macOS（x86_64, aarch64）],
  [ディスク容量], [最低 1GB（Nix Store 用に 10GB 以上推奨）],
  [メモリ], [最低 512MB（ビルド時は 2GB 以上推奨）],
  [権限], [root権限またはsudo権限（マルチユーザーインストール時）],
)

== インストール方法

Nixには2つのインストールモードがある。

#table(
  columns: (1fr, 1fr, 1fr),
  align: left,
  table.header(
    [*項目*], [*シングルユーザー*], [*マルチユーザー（推奨）*],
  ),
  [Nix Store の所有者], [現在のユーザー], [root],
  [ビルドの分離], [なし], [専用ビルドユーザーで分離],
  [セキュリティ], [低], [高],
  [セットアップの容易さ], [簡単], [やや複雑（自動化されている）],
  [推奨環境], [テスト・試用], [本番・チーム開発],
)

=== マルチユーザーインストール（推奨）

公式のインストールスクリプトを使用する。

```bash
sh <(curl -L https://nixos.org/nix/install) --daemon
```

インストールが完了したら、シェルを再起動するか以下を実行する。

```bash
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
```

=== シングルユーザーインストール

```bash
sh <(curl -L https://nixos.org/nix/install) --no-daemon
```

シェルを再起動するか以下を実行する。

```bash
. ~/.nix-profile/etc/profile.d/nix.sh
```

== インストールの確認

インストールが正しく完了したか確認する。

```bash
nix --version
```

以下のように表示されれば成功である。

```
nix (Nix) 2.24.x
```

簡単なテストとして、`hello` パッケージを実行してみる。

```bash
nix-shell -p hello --run hello
```

`Hello, world!` と表示されれば、Nixは正常に動作している。

== Nixの実験的機能を有効にする

Flakesや新しい `nix` コマンド体系を使用するには、実験的機能を有効にする必要がある。`~/.config/nix/nix.conf` を作成または編集する。

```bash
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
```

これにより `nix build`、`nix run`、`nix develop` などの新しいコマンドと Flakes が利用可能になる。

== アンインストール

=== Linux（マルチユーザー）

```bash
sudo systemctl stop nix-daemon.service
sudo systemctl disable nix-daemon.socket nix-daemon.service
sudo rm -rf /nix /etc/nix ~/.nix-profile ~/.nix-defexpr ~/.nix-channels
```

さらに、`/etc/bashrc` や `/etc/zshrc` から Nix 関連の行を削除する。

=== macOS

```bash
sudo rm -rf /nix
sudo rm -rf /etc/nix
rm -rf ~/.nix-profile ~/.nix-defexpr ~/.nix-channels
```

`/etc/bashrc`、`/etc/zshrc`、`/etc/synthetic.conf`、`/etc/fstab` から Nix 関連の設定を削除する。
