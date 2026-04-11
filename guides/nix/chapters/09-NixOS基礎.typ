= NixOS基礎

== NixOSとは

NixOSはNixパッケージマネージャを基盤としたLinuxディストリビューションである。OS全体の構成——カーネル、サービス、ユーザー、ネットワーク——をすべて1つの設定ファイルで宣言的に管理できる。

NixOSの主な特徴は以下の通りである。

- *宣言的なシステム構成*: `/etc/nixos/configuration.nix` でシステム全体を定義
- *アトミックなアップグレードとロールバック*: 失敗したアップグレードからブートローダーで復旧可能
- *再現性*: 同じ設定ファイルから同じシステムを構築できる
- *テスト容易性*: 仮想マシンでシステム構成をテストできる

== configuration.nix の基本構造

```nix
# /etc/nixos/configuration.nix
{ config, pkgs, ... }:

{
  # ブートローダー
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # ネットワーク
  networking.hostName = "my-nixos";
  networking.networkmanager.enable = true;

  # タイムゾーン
  time.timeZone = "Asia/Tokyo";

  # ロケール
  i18n.defaultLocale = "ja_JP.UTF-8";

  # システムパッケージ
  environment.systemPackages = with pkgs; [
    vim
    git
    firefox
    wget
    curl
  ];

  # SSH サーバー
  services.openssh.enable = true;

  # ファイアウォール
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 80 443 ];
  };

  # ユーザー
  users.users.myuser = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    shell = pkgs.zsh;
  };

  # NixOS のバージョン（変更しないこと）
  system.stateVersion = "24.11";
}
```

== システムの再構築

設定を変更したら、以下のコマンドで適用する。

```bash
# 設定を適用してアクティブ化
sudo nixos-rebuild switch

# テスト（再起動後は元に戻る）
sudo nixos-rebuild test

# ビルドのみ（適用しない）
sudo nixos-rebuild build

# ブートエントリに追加するが、現在のセッションには適用しない
sudo nixos-rebuild boot
```

== サービス管理

NixOSではsystemdサービスを宣言的に管理する。

```nix
# Nginx の有効化
services.nginx = {
  enable = true;
  virtualHosts."example.com" = {
    root = "/var/www/example.com";
    locations."/" = {
      tryFiles = "$uri $uri/ =404";
    };
  };
};

# PostgreSQL の有効化
services.postgresql = {
  enable = true;
  package = pkgs.postgresql_16;
  authentication = ''
    local all all trust
    host all all 127.0.0.1/32 trust
  '';
};

# Docker の有効化
virtualisation.docker.enable = true;
users.users.myuser.extraGroups = [ "docker" ];
```

NixOSのオプション検索サイト（search.nixos.org/options）で利用可能な全オプションを確認できる。

== 世代管理とロールバック

NixOSは `nixos-rebuild switch` のたびに新しいシステム世代を作成する。

```bash
# システム世代の一覧
sudo nix-env -p /nix/var/nix/profiles/system --list-generations

# 1つ前の世代にロールバック
sudo nixos-rebuild switch --rollback

# 特定の世代に切り替え
sudo nix-env -p /nix/var/nix/profiles/system --switch-generation 42
sudo /nix/var/nix/profiles/system/bin/switch-to-configuration switch
```

ブートローダーにも各世代のエントリが表示されるため、起動時にも以前のシステム状態を選択できる。

== NixOS モジュールシステム

NixOSの設定はモジュールシステムで構成されている。設定ファイルを分割して管理できる。

```nix
# /etc/nixos/configuration.nix
{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix  # ハードウェア設定（自動生成）
    ./networking.nix              # ネットワーク設定
    ./services.nix                # サービス設定
    ./users.nix                   # ユーザー設定
  ];

  # 共通設定
  system.stateVersion = "24.11";
}
```

```nix
# /etc/nixos/services.nix
{ config, pkgs, ... }:

{
  services.openssh.enable = true;
  services.nginx.enable = true;
}
```

== Flakes で NixOS を管理

FlakesでNixOSの構成を管理することで、再現性をさらに向上させることができる。

```nix
# flake.nix
{
  description = "My NixOS Configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    home-manager = {
      url = "github:nix-community/home-manager/release-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }: {
    nixosConfigurations.my-nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.myuser = import ./home.nix;
        }
      ];
    };
  };
}
```

```bash
# Flakes を使ったシステム再構築
sudo nixos-rebuild switch --flake .#my-nixos
```
