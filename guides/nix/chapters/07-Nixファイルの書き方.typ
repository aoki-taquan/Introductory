= Nixファイルの書き方

== パッケージの定義（default.nix）

Nixでパッケージを定義する基本的な方法は、`mkDerivation` 関数を使用することである。

=== 基本的な構造

```nix
# default.nix
{ pkgs ? import <nixpkgs> {} }:

pkgs.stdenv.mkDerivation {
  pname = "my-app";
  version = "1.0.0";

  src = ./.;

  buildInputs = [ pkgs.zlib pkgs.openssl ];
  nativeBuildInputs = [ pkgs.cmake pkgs.pkg-config ];

  buildPhase = ''
    cmake .
    make
  '';

  installPhase = ''
    mkdir -p $out/bin
    cp my-app $out/bin/
  '';
}
```

=== 主要な属性

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header(
    [*属性*], [*説明*],
  ),
  [`pname`], [パッケージ名],
  [`version`], [バージョン],
  [`src`], [ソースコード（パス、fetchurl、fetchFromGitHub など）],
  [`buildInputs`], [実行時に必要な依存パッケージ],
  [`nativeBuildInputs`], [ビルド時のみ必要なツール],
  [`buildPhase`], [ビルド手順],
  [`installPhase`], [インストール手順（`$out` がインストール先）],
  [`checkPhase`], [テスト手順],
  [`meta`], [パッケージのメタ情報（説明、ライセンスなど）],
)

== ソースの取得

=== GitHubからの取得

```nix
{ pkgs ? import <nixpkgs> {} }:

pkgs.stdenv.mkDerivation {
  pname = "example";
  version = "1.2.3";

  src = pkgs.fetchFromGitHub {
    owner = "example";
    repo = "example-repo";
    rev = "v1.2.3";
    sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };

  # ...
}
```

ハッシュが不明な場合は、仮の値を入れてビルドを実行すると、正しいハッシュがエラーメッセージに表示される。

```bash
# ハッシュを事前に計算
nix-prefetch-url --unpack https://github.com/example/repo/archive/v1.2.3.tar.gz
```

=== URLからの取得

```nix
src = pkgs.fetchurl {
  url = "https://example.com/source-1.0.tar.gz";
  sha256 = "sha256-...";
};
```

== 言語固有のビルダー

=== Python パッケージ

```nix
{ pkgs ? import <nixpkgs> {} }:

pkgs.python3Packages.buildPythonApplication {
  pname = "my-python-app";
  version = "1.0.0";
  src = ./.;

  propagatedBuildInputs = with pkgs.python3Packages; [
    requests
    flask
    sqlalchemy
  ];

  checkInputs = with pkgs.python3Packages; [
    pytest
  ];

  checkPhase = ''
    pytest tests/
  '';
}
```

=== Rust パッケージ

```nix
{ pkgs ? import <nixpkgs> {} }:

pkgs.rustPlatform.buildRustPackage {
  pname = "my-rust-app";
  version = "1.0.0";
  src = ./.;

  cargoLock = {
    lockFile = ./Cargo.lock;
  };

  nativeBuildInputs = [ pkgs.pkg-config ];
  buildInputs = [ pkgs.openssl ];
}
```

=== Go パッケージ

```nix
{ pkgs ? import <nixpkgs> {} }:

pkgs.buildGoModule {
  pname = "my-go-app";
  version = "1.0.0";
  src = ./.;

  vendorHash = "sha256-...";

  # テストをスキップする場合
  doCheck = false;
}
```

== オーバーレイ（Overlay）

オーバーレイを使うと、既存のNixpkgsパッケージを変更したり、新しいパッケージを追加したりできる。

```nix
# overlay.nix
final: prev: {
  # 既存パッケージのオーバーライド
  vim = prev.vim.override {
    pythonSupport = true;
  };

  # 新しいパッケージの追加
  my-tool = final.callPackage ./my-tool.nix {};
}
```

```nix
# オーバーレイの適用
let
  pkgs = import <nixpkgs> {
    overlays = [ (import ./overlay.nix) ];
  };
in pkgs.vim  # Python サポートが有効化された vim
```

== overrideとoverrideAttrs

既存パッケージの一部を変更するには `override` や `overrideAttrs` を使用する。

```nix
# override: 関数引数の変更
pkgs.ffmpeg.override {
  withVpx = true;
  withX264 = true;
}

# overrideAttrs: デリベーション属性の変更
pkgs.hello.overrideAttrs (oldAttrs: {
  version = "2.13";
  src = pkgs.fetchurl {
    url = "https://ftp.gnu.org/gnu/hello/hello-2.13.tar.gz";
    sha256 = "sha256-...";
  };
  patches = [ ./my-fix.patch ];
})
```

`override` は高水準の設定変更に、`overrideAttrs` は低水準のビルド属性の変更に適している。
