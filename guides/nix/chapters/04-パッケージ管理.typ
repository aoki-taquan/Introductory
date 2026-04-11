= パッケージ管理

== パッケージの検索

=== コマンドラインでの検索

```bash
# 旧コマンド
nix-env -qaP 'firefox'

# 新コマンド（experimental-features 有効時）
nix search nixpkgs firefox
```

`nix search` コマンドはパッケージ名と説明文の両方を検索対象とする。

```bash
# 正規表現による検索
nix search nixpkgs 'python3.*Packages\.numpy'
```

=== Webでの検索

Nixpkgsのパッケージは以下のWebサイトからも検索できる。

- *search.nixos.org*: 公式のパッケージ検索サイト

== パッケージのインストール

=== 命令的なインストール（nix-env）

`nix-env` はユーザープロファイルにパッケージをインストールする従来のコマンドである。

```bash
# パッケージのインストール
nix-env -iA nixpkgs.firefox

# 複数パッケージの一括インストール
nix-env -iA nixpkgs.git nixpkgs.vim nixpkgs.tmux
```

=== 一時的な利用（nix-shell / nix shell）

パッケージをプロファイルにインストールせず、一時的に使用することもできる。

```bash
# 旧コマンド: パッケージを含む一時シェルを起動
nix-shell -p python3 nodejs

# 新コマンド: パッケージを含む一時シェルを起動
nix shell nixpkgs#python3 nixpkgs#nodejs

# コマンドを1回だけ実行
nix run nixpkgs#cowsay -- "Hello, Nix!"
```

この方法はシステムを汚さずにツールを試したい場合に便利である。

== パッケージの削除

```bash
# パッケージの削除
nix-env -e firefox

# 不要なパッケージのガベージコレクション
nix-collect-garbage

# 古い世代も含めてクリーンアップ（30日以上前の世代を削除）
nix-collect-garbage --delete-older-than 30d
```

== インストール済みパッケージの管理

```bash
# インストール済みパッケージの一覧
nix-env -q

# 詳細情報付きで一覧
nix-env -q --description

# パッケージのアップグレード
nix-env -u            # すべてのパッケージをアップグレード
nix-env -uA nixpkgs.firefox  # 特定のパッケージをアップグレード
```

== 宣言的なパッケージ管理

命令的な `nix-env` の代わりに、設定ファイルで管理する宣言的な方法が推奨される。

=== home-manager による管理

home-manager を使うと、ユーザー環境を宣言的に管理できる。

```nix
# ~/.config/home-manager/home.nix
{ config, pkgs, ... }:

{
  home.username = "myuser";
  home.homeDirectory = "/home/myuser";
  home.stateVersion = "24.11";

  home.packages = with pkgs; [
    firefox
    git
    vim
    tmux
    ripgrep
    fd
    jq
  ];

  programs.home-manager.enable = true;
}
```

```bash
# 設定を適用
home-manager switch
```

この方法であれば、環境の構成をGitで管理し、別のマシンでも同一の環境を再現できる。

== バイナリキャッシュ

Nixはデフォルトで `cache.nixos.org` のバイナリキャッシュを使用する。ビルド済みの成果物がキャッシュに存在すれば、ソースからビルドする代わりにダウンロードされる。

```bash
# キャッシュの設定確認
nix show-config | grep substituters

# カスタムキャッシュの追加（nix.conf）
# substituters = https://cache.nixos.org https://my-cache.example.com
# trusted-public-keys = cache.nixos.org-1:... my-cache-1:...
```

バイナリキャッシュにより、大半のパッケージはダウンロードするだけで利用でき、ビルド時間を大幅に短縮できる。
