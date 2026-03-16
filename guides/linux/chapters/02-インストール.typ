= インストール

== システム要件

Linuxは比較的軽量なOSであるが、快適に利用するための推奨スペックを以下に示す。

#table(
  columns: (1fr, 1fr, 1fr),
  [*項目*], [*最小要件*], [*推奨*],
  [CPU], [1 GHz 以上], [2コア以上],
  [メモリ], [512 MB], [2 GB 以上],
  [ストレージ], [10 GB], [25 GB 以上],
  [ネットワーク], [—], [インターネット接続],
)

サーバー用途の場合はGUI不要のため、より少ないリソースで動作する。

== インストール方法

Linuxをインストールする方法はいくつかある。

=== ISOイメージからのインストール

最も一般的な方法である。各ディストリビューションの公式サイトからISOイメージをダウンロードし、USBメモリやDVDに書き込んで起動する。

```bash
# USBメモリへの書き込み例（Linux環境）
sudo dd if=ubuntu-24.04-live-server-amd64.iso of=/dev/sdb bs=4M status=progress
sync
```

=== 仮想マシンへのインストール

学習目的であれば、仮想マシン上にインストールするのが手軽である。

- *VirtualBox*: 無料で利用できる仮想化ソフトウェア
- *VMware Workstation Player*: 個人利用は無料
- *Proxmox VE*: サーバー向け仮想化プラットフォーム
- *KVM / QEMU*: Linux標準の仮想化技術

=== クラウド環境

AWS、GCP、Azureなどのクラウドサービスでは、あらかじめLinuxがインストールされた仮想マシンをすぐに利用できる。

=== WSL（Windows Subsystem for Linux）

Windows上でLinux環境を利用する場合はWSLが便利である。

```powershell
# WSLのインストール（PowerShell管理者権限）
wsl --install

# 特定のディストリビューションを指定
wsl --install -d Ubuntu-24.04
```

== インストール後の初期設定

=== システムの更新

インストール直後はパッケージを最新の状態に更新する。

```bash
# Ubuntu / Debian系
sudo apt update && sudo apt upgrade -y

# RHEL / Rocky Linux系
sudo dnf update -y
```

=== タイムゾーンの設定

```bash
# 現在のタイムゾーンを確認
timedatectl

# 日本時間に設定
sudo timedatectl set-timezone Asia/Tokyo
```

=== ホスト名の設定

```bash
# 現在のホスト名を確認
hostnamectl

# ホスト名を変更
sudo hostnamectl set-hostname myserver
```

=== SSHサーバーの設定

リモートアクセスのためにSSHサーバーを有効にする。

```bash
# SSHサーバーのインストールと起動
sudo apt install -y openssh-server
sudo systemctl enable --now ssh

# ファイアウォールでSSHを許可（ufwの場合）
sudo ufw allow ssh
sudo ufw enable
```
