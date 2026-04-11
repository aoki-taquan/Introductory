= Nix言語基礎

== Nix言語の概要

Nix言語は、パッケージやシステム構成を記述するために設計された*純粋関数型*の*遅延評価*言語である。汎用プログラミング言語ではなく、ビルドの記述に特化したドメイン固有言語（DSL）である。

Nix言語の特徴は以下の通りである。

- *純粋*: 同じ入力に対して常に同じ結果を返す
- *遅延評価*: 値は実際に必要になるまで評価されない
- *動的型付け*: 型は実行時に検査される

`nix repl` コマンドで対話的にNix言語を試すことができる。

```bash
nix repl
```

== 基本的なデータ型

=== 数値と文字列

```nix
# 整数
42

# 文字列（ダブルクォート）
"hello, world"

# 複数行文字列（2つのシングルクォート）
''
  This is a
  multi-line string.
''

# 文字列補間
let name = "Nix"; in "Hello, ${name}!"
# => "Hello, Nix!"
```

=== パス

Nix言語にはパスのリテラルがある。

```nix
# 相対パス
./src/main.c

# 絶対パス
/etc/nixos/configuration.nix

# ホームディレクトリ
~/.config/nix/nix.conf
```

パスは文字列とは異なるデータ型であり、ファイルシステムの参照として扱われる。

=== 真偽値とnull

```nix
true
false
null
```

=== リスト

```nix
# リスト（要素はスペースで区切る、カンマは不要）
[ 1 2 3 ]

# 異なる型の混在が可能
[ 1 "hello" true ./path ]

# リストの結合
[ 1 2 ] ++ [ 3 4 ]
# => [ 1 2 3 4 ]
```

=== アトリビュートセット（Attribute Set）

アトリビュートセットはNix言語で最も重要なデータ構造である。他の言語における辞書やマップに相当する。

```nix
# 基本的なアトリビュートセット
{
  name = "my-package";
  version = "1.0.0";
  src = ./src;
}

# ネストしたアクセス
let config = {
  server = {
    host = "localhost";
    port = 8080;
  };
};
in config.server.port
# => 8080

# 再帰的アトリビュートセット（rec）
rec {
  x = 1;
  y = x + 1;
}
# => { x = 1; y = 2; }
```

== 関数

Nix言語の関数はすべて無名関数（ラムダ）であり、引数を1つだけ取る。

```nix
# 基本的な関数
x: x + 1

# 関数の適用
let increment = x: x + 1;
in increment 5
# => 6

# 複数引数（カリー化）
a: b: a + b

let add = a: b: a + b;
in add 3 4
# => 7
```

=== アトリビュートセットを引数に取る関数

Nixで最も一般的なパターンである。

```nix
# 基本形
{ name, version }: "Package: ${name}-${version}"

# デフォルト値
{ name, version ? "0.1.0" }: "Package: ${name}-${version}"

# 残りの引数を許容（...）
{ name, version, ... }: "Package: ${name}-${version}"
```

== let式とwith式

```nix
# let式: ローカル束縛
let
  x = 1;
  y = 2;
in x + y
# => 3

# with式: アトリビュートセットのスコープ導入
let pkgs = { git = "git-2.43"; vim = "vim-9.1"; };
in with pkgs; [ git vim ]
# => [ "git-2.43" "vim-9.1" ]
```

== if式

```nix
if 3 > 2 then "yes" else "no"
# => "yes"
```

Nix言語では `if` は式であり、常に値を返す。`else` は省略できない。

== inherit キーワード

`inherit` は変数をアトリビュートセットに簡潔に取り込むための構文糖衣である。

```nix
let
  name = "hello";
  version = "1.0";
in {
  inherit name version;
  # 以下と同等:
  # name = name;
  # version = version;
}
```

== import

他のNixファイルを読み込むには `import` を使用する。

```nix
# ファイルを読み込み・評価
import ./config.nix

# 引数付きで読み込み
import ./package.nix { inherit pkgs; }
```

== builtins

Nixには多数の組み込み関数（builtins）が用意されている。

```nix
# 代表的な builtins
builtins.length [ 1 2 3 ]          # => 3
builtins.map (x: x * 2) [ 1 2 3 ]  # => [ 2 4 6 ]
builtins.filter (x: x > 2) [ 1 2 3 4 ]  # => [ 3 4 ]
builtins.attrNames { a = 1; b = 2; }    # => [ "a" "b" ]
builtins.hasAttr "a" { a = 1; }          # => true
builtins.readFile ./README.md
builtins.toJSON { name = "test"; }
```

`nix repl` で `builtins.` と入力してタブ補完すると、利用可能な組み込み関数の一覧を確認できる。
