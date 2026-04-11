= Tipsとベストプラクティス

== ディスク容量の管理

Nix Storeは使い続けるとディスク容量を大量に消費する。定期的なクリーンアップが重要である。

```bash
# ガベージコレクション（未参照のパスを削除）
nix-collect-garbage

# 古い世代を削除してからガベージコレクション
nix-collect-garbage --delete-older-than 14d

# Nix Store の最適化（ハードリンクによる重複排除）
nix store optimise

# 現在の Nix Store のサイズを確認
du -sh /nix/store
```

自動的にガベージコレクションを実行するには、NixOSで以下の設定を追加する。

```nix
# configuration.nix
nix.gc = {
  automatic = true;
  dates = "weekly";
  options = "--delete-older-than 30d";
};
```

== よく使うコマンド一覧

#table(
  columns: (1fr, 1fr),
  align: left,
  table.header(
    [*旧コマンド*], [*新コマンド（Flakes対応）*],
  ),
  [`nix-build`], [`nix build`],
  [`nix-shell -p pkg`], [`nix shell nixpkgs#pkg`],
  [`nix-shell`], [`nix develop`],
  [`nix-env -iA nixpkgs.pkg`], [`nix profile install nixpkgs#pkg`],
  [`nix-env -e pkg`], [`nix profile remove pkg`],
  [`nix-env -q`], [`nix profile list`],
  [`nix-channel --update`], [`nix flake update`],
  [`nix-env -qaP pkg`], [`nix search nixpkgs pkg`],
)

== デバッグ手法

=== ビルドエラーの調査

```bash
# 詳細なビルドログを表示
nix build .#my-package -L

# ビルドログを保持
nix build .#my-package --keep-failed

# 失敗したビルドのシェルに入る
nix develop .#my-package
# 手動でビルドステップを再現して問題を特定
```

=== Nix式の評価

```bash
# Nix式を評価して結果を表示
nix eval .#packages.x86_64-linux.default.name

# nix repl で対話的にデバッグ
nix repl
# nix-repl> :l <nixpkgs>
# nix-repl> python3.version
# => "3.12.x"
```

=== 依存関係の調査

```bash
# パッケージの依存ツリーを表示
nix-store -q --tree $(nix build .#my-package --print-out-paths)

# パッケージがなぜ依存されているか調査
nix why-depends .#my-package .#openssl
```

== セキュリティ

=== 信頼されたユーザーの設定

```nix
# nix.conf または configuration.nix
nix.settings.trusted-users = [ "root" "@wheel" ];
```

=== バイナリキャッシュの署名検証

```nix
nix.settings = {
  substituters = [
    "https://cache.nixos.org"
    "https://my-cache.example.com"
  ];
  trusted-public-keys = [
    "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    "my-cache-1:XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX="
  ];
};
```

== プロジェクト構成のベストプラクティス

推奨するプロジェクト構成は以下の通りである。

```
my-project/
├── flake.nix          # Flake定義
├── flake.lock         # ロックファイル（Git管理対象）
├── .envrc             # direnv設定
├── nix/
│   ├── default.nix    # パッケージ定義
│   ├── shell.nix      # 開発環境（Flake以前の互換用）
│   └── overlay.nix    # カスタムオーバーレイ
├── src/               # ソースコード
└── tests/             # テスト
```

=== .gitignore に追加すべきもの

```
result
result-*
```

`result` は `nix build` が作成するシンボリックリンクであり、Git管理対象にすべきでない。

== コミュニティリソース

Nixの学習やトラブルシューティングに役立つリソースを紹介する。

- *Nix公式マニュアル*: nixos.org/manual/nix
- *Nixpkgsマニュアル*: nixos.org/manual/nixpkgs
- *NixOS Wiki*: wiki.nixos.org
- *nix.dev*: Nixの入門チュートリアル
- *NixOS Discourse*: discourse.nixos.org（フォーラム）
- *Nixpkgs GitHub*: github.com/NixOS/nixpkgs
- *Zero to Nix*: zero-to-nix.com（対話的チュートリアル）
