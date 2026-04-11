= Flakes

== Flakesとは

FlakesはNixプロジェクトの依存関係と出力を標準化する仕組みである。従来のNixでは、チャネルやNIX_PATHなど環境に依存する要素が再現性を損なう原因となっていた。Flakesはこの問題を解決し、完全に再現可能なNix式を実現する。

Flakesの主な特徴は以下の通りである。

- *ロックファイル*（`flake.lock`）による依存関係の完全な固定
- *標準化された構造*による統一的なプロジェクト管理
- *純粋な評価*: 環境変数に依存しない
- *構成可能性*: Flakes同士を容易に組み合わせられる

== Flakesの有効化

Flakesは現在も実験的機能であるため、明示的に有効化する必要がある。

```bash
# ~/.config/nix/nix.conf
experimental-features = nix-command flakes
```

== flake.nix の構造

`flake.nix` はFlakeのエントリーポイントであり、以下の3つの主要な属性を持つ。

```nix
{
  description = "プロジェクトの説明";

  inputs = {
    # 依存する他の Flake
  };

  outputs = { self, ... }@inputs: {
    # このFlakeが提供する成果物
  };
}
```

=== inputs（入力）

```nix
inputs = {
  # Nixpkgs（最も一般的な入力）
  nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";

  # 別のFlake
  home-manager = {
    url = "github:nix-community/home-manager/release-24.11";
    inputs.nixpkgs.follows = "nixpkgs";  # nixpkgsを共有
  };

  # Git リポジトリ
  my-lib.url = "git+https://example.com/my-lib.git";

  # ローカルパス
  my-utils.url = "path:./utils";
};
```

`follows` を使うと、間接的な依存関係のバージョンを統一できる。これによりビルド時間の短縮とストアの節約ができる。

=== outputs（出力）

```nix
outputs = { self, nixpkgs, ... }:
  let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
  in {
    # パッケージ
    packages.${system}.default = pkgs.callPackage ./package.nix {};
    packages.${system}.my-tool = pkgs.callPackage ./my-tool.nix {};

    # 開発シェル
    devShells.${system}.default = pkgs.mkShell {
      buildInputs = [ pkgs.go pkgs.gopls ];
    };

    # NixOS モジュール
    nixosModules.default = import ./module.nix;

    # オーバーレイ
    overlays.default = final: prev: {
      my-tool = final.callPackage ./my-tool.nix {};
    };
  };
```

== flake.lock

`flake.lock` はすべての入力の正確なリビジョンを記録するファイルである。Gitにコミットして共有することで、全員が同一のバージョンを使用できる。

```bash
# ロックファイルの更新（すべての入力）
nix flake update

# 特定の入力のみ更新
nix flake update nixpkgs

# ロックファイルの情報を表示
nix flake metadata
```

== Flakeの操作

```bash
# Flakeの初期化
nix flake init

# テンプレートから初期化
nix flake init -t templates#rust

# Flakeの情報を表示
nix flake show
nix flake metadata

# パッケージのビルド
nix build .#my-tool

# パッケージの実行
nix run .#my-tool

# 開発環境に入る
nix develop

# Flake の入力を確認
nix flake metadata
```

== 複数システム対応

複数のアーキテクチャに対応するには、`flake-utils` を使用すると便利である。

```nix
{
  description = "Cross-platform project";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let pkgs = nixpkgs.legacyPackages.${system};
      in {
        packages.default = pkgs.callPackage ./package.nix {};

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [ go gopls ];
        };
      }
    );
}
```

`eachDefaultSystem` は `x86_64-linux`、`aarch64-linux`、`x86_64-darwin`、`aarch64-darwin` の4つのシステムに対して自動的に出力を生成する。

== 実践例: Webアプリケーション

```nix
{
  description = "My Web Application";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let pkgs = nixpkgs.legacyPackages.${system};
      in {
        packages.default = pkgs.buildGoModule {
          pname = "my-webapp";
          version = "0.1.0";
          src = ./.;
          vendorHash = "sha256-...";
        };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            go
            gopls
            nodejs
            postgresql
            redis
          ];

          shellHook = ''
            echo "Web App 開発環境が準備されました"
            export DATABASE_URL="postgresql://localhost/myapp"
          '';
        };
      }
    );
}
```
