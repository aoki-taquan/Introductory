= 基本概念

== Nix Store

Nix Storeは、Nixが管理するすべてのパッケージやビルド成果物を格納する中央リポジトリである。デフォルトでは `/nix/store` に配置される。

各パッケージは以下のようなパスに格納される。

```
/nix/store/<ハッシュ>-<パッケージ名>-<バージョン>/
```

例えば、GNU Hello パッケージは以下のようになる。

```
/nix/store/qy93dp4a3rqyn2mz63fbxjg228hffwyw-hello-2.12.1/
```

ハッシュはパッケージのビルドに使用されたすべての入力（ソースコード、依存関係、ビルドスクリプト、コンパイラ）から計算される。入力が1ビットでも異なれば、異なるハッシュが生成される。

=== Nix Store の特性

- *不変（Immutable）*: Store内のパスは作成後に変更されない
- *コンテンツアドレス*: パスはその内容のハッシュに基づく
- *共有*: 同一の成果物は一度だけ格納される（重複排除）
- *ガベージコレクション*: 不要になったパスは `nix-collect-garbage` で回収できる

== デリベーション（Derivation）

デリベーションはNixにおけるビルドの基本単位である。「何をどうビルドするか」を記述した設計図のようなものである。

デリベーションには以下の情報が含まれる。

- *ビルドに必要な入力*（ソースコード、依存パッケージ）
- *ビルドスクリプト*（ビルドの手順）
- *出力先*（Nix Store 内のパス）
- *ビルド環境の設定*（環境変数など）

```nix
# 概念的な例
derivation {
  name = "my-package";
  builder = "${bash}/bin/bash";
  src = ./src;
  buildInputs = [ gcc make ];
}
```

デリベーションの重要な性質は*純粋性*である。同じ入力からは常に同じ出力が得られるよう、ビルドはネットワークアクセスのないサンドボックス環境で実行される。

== プロファイルと世代

Nixは*プロファイル*を使って、ユーザーの環境（インストール済みパッケージの集合）を管理する。

```
~/.nix-profile -> /nix/var/nix/profiles/per-user/<user>/profile
```

パッケージをインストールまたは削除するたびに、新しい*世代（Generation）*が作成される。

```bash
# 世代の一覧を確認
nix-env --list-generations

# 出力例:
#   1   2024-01-15 10:00:00
#   2   2024-01-16 14:30:00   (current)
```

世代管理により、いつでも以前の状態に戻すことができる。

```bash
# 1つ前の世代に戻す
nix-env --rollback

# 特定の世代に切り替え
nix-env --switch-generation 1
```

== チャネル

チャネルはNixpkgsリポジトリの特定のスナップショットを指す名前付き参照である。

```bash
# 現在のチャネルを確認
nix-channel --list

# チャネルの追加
nix-channel --add https://nixos.org/channels/nixpkgs-unstable nixpkgs

# チャネルの更新
nix-channel --update
```

主なチャネルは以下の通りである。

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header(
    [*チャネル*], [*説明*],
  ),
  [nixpkgs-unstable], [最新のパッケージ。テスト済みだが安定性は保証されない],
  [nixos-24.11], [NixOS 24.11 のリリースチャネル。安定版],
  [nixos-unstable], [NixOS 向けの最新チャネル],
)

Flakesを使用する場合、チャネルの代わりに `flake.lock` で依存関係のバージョンを固定する。

== クロージャ（Closure）

パッケージのクロージャとは、そのパッケージが動作するために必要なすべての依存関係を含む完全な集合である。

```bash
# パッケージのクロージャを確認
nix-store -qR $(which hello)
```

この出力には、`hello` の実行に必要なすべてのライブラリやランタイム依存が含まれる。クロージャの概念により、Nixはパッケージの完全な可搬性を実現している。
