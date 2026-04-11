= 開発環境構築

== nix-shell による開発環境

`nix-shell` はプロジェクト固有の開発環境を一時的に構築するコマンドである。必要なツールやライブラリを含むシェルを起動し、作業終了後にはクリーンに破棄できる。

=== 基本的な使い方

```bash
# パッケージを指定して一時シェルを起動
nix-shell -p python3 python3Packages.requests nodejs

# シェル内でツールが利用可能
python3 --version
node --version

# シェルから抜ける
exit
```

=== shell.nix による環境定義

プロジェクトルートに `shell.nix` を配置することで、チーム全員が同一の開発環境を利用できる。

```nix
# shell.nix
{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    python3
    python3Packages.requests
    python3Packages.flask
    nodejs
    nodePackages.npm
    postgresql
    redis
  ];

  shellHook = ''
    echo "開発環境が準備されました"
    export DATABASE_URL="postgresql://localhost/myapp"
    export FLASK_ENV="development"
  '';
}
```

```bash
# shell.nix があるディレクトリで実行
nix-shell
```

`shellHook` にはシェル起動時に実行するコマンドを記述できる。環境変数の設定やサービスの起動などに活用する。

== nix develop による開発環境（Flakes対応）

Flakesを使用する場合は、`nix develop` コマンドで開発環境を構築する。

```nix
# flake.nix
{
  description = "My Python project";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          python3
          python3Packages.requests
          python3Packages.flask
          nodePackages.pyright
        ];

        shellHook = ''
          echo "Python開発環境が準備されました"
        '';
      };
    };
}
```

```bash
# 開発環境に入る
nix develop

# 特定の devShell を指定
nix develop .#myShell
```

== 言語別の開発環境例

=== Rust 開発環境

```nix
# shell.nix
{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    rustc
    cargo
    rustfmt
    clippy
    rust-analyzer
    pkg-config
    openssl
  ];

  RUST_SRC_PATH = "${pkgs.rust.packages.stable.rustPlatform.rustLibSrc}";
}
```

=== Go 開発環境

```nix
# shell.nix
{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    go
    gopls
    gotools
    go-tools
    delve
  ];

  shellHook = ''
    export GOPATH=$HOME/go
    export PATH=$GOPATH/bin:$PATH
  '';
}
```

=== Node.js 開発環境

```nix
# shell.nix
{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    nodejs_20
    nodePackages.npm
    nodePackages.typescript
    nodePackages.typescript-language-server
  ];
}
```

== direnv との連携

`direnv` と `nix-direnv` を組み合わせることで、ディレクトリに入るだけで自動的にNix開発環境を有効化できる。

=== セットアップ

```nix
# home.nix（home-manager を使用する場合）
{
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
```

=== プロジェクトでの使用

プロジェクトルートに `.envrc` ファイルを作成する。

```bash
# .envrc（shell.nix を使用する場合）
use nix

# .envrc（flake.nix を使用する場合）
use flake
```

```bash
# direnv を許可
direnv allow
```

これにより、プロジェクトディレクトリに `cd` するだけで自動的に開発環境が有効化され、離れると無効化される。エディタやIDEとの連携も自動で行われるため、非常に快適な開発体験が得られる。
