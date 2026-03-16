= パッケージ管理

== パッケージ管理の概要

Linuxでは、ソフトウェアの導入・更新・削除を「パッケージマネージャ」で一元管理する。ディストリビューションによって使用するパッケージマネージャが異なる。

#table(
  columns: (1fr, 1fr, 1fr),
  [*系統*], [*パッケージ形式*], [*パッケージマネージャ*],
  [Debian / Ubuntu], [`.deb`], [`apt`（`dpkg`）],
  [RHEL / Rocky Linux / Fedora], [`.rpm`], [`dnf`（`rpm`）],
  [Arch Linux], [`.pkg.tar.zst`], [`pacman`],
  [openSUSE], [`.rpm`], [`zypper`],
)

== APT（Debian / Ubuntu系）

APT（Advanced Package Tool）はDebian系で標準のパッケージマネージャである。

=== パッケージの検索・情報確認

```bash
# パッケージリストの更新
sudo apt update

# パッケージの検索
apt search nginx

# パッケージの詳細情報
apt show nginx

# インストール済みパッケージの一覧
apt list --installed
```

=== パッケージのインストール・削除

```bash
# インストール
sudo apt install nginx

# 複数パッケージの同時インストール
sudo apt install nginx curl vim

# パッケージの削除
sudo apt remove nginx              # 設定ファイルは残る
sudo apt purge nginx               # 設定ファイルも削除

# 不要な依存パッケージの削除
sudo apt autoremove
```

=== システムの更新

```bash
# パッケージリストの更新 + アップグレード
sudo apt update && sudo apt upgrade -y

# ディストリビューションのアップグレード（カーネル等も含む）
sudo apt full-upgrade -y
```

== DNF（RHEL / Rocky Linux / Fedora系）

DNFはRed Hat系で標準のパッケージマネージャである。

```bash
# パッケージの検索
dnf search nginx

# インストール
sudo dnf install nginx

# 削除
sudo dnf remove nginx

# システムの更新
sudo dnf update -y

# パッケージグループのインストール
sudo dnf groupinstall "Development Tools"
```

== リポジトリの管理

パッケージはリポジトリ（パッケージの配布元）からダウンロードされる。公式リポジトリに含まれないソフトウェアを利用する場合は、サードパーティのリポジトリを追加する。

=== APTリポジトリの追加

```bash
# リポジトリの追加（例: Dockerの公式リポジトリ）
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) \
  signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
```

=== DNFリポジトリの追加

```bash
# EPELリポジトリの追加
sudo dnf install epel-release

# リポジトリの一覧表示
dnf repolist
```

== Snapとflatpak

従来のパッケージマネージャに加え、ディストリビューション非依存のパッケージ形式も普及している。

#table(
  columns: (1fr, 3fr),
  [*形式*], [*説明*],
  [Snap], [Canonical（Ubuntu）が推進。`snap install` で導入。依存関係を自己完結型で管理],
  [Flatpak], [Red Hat等が推進。デスクトップアプリ向け。サンドボックス環境で動作],
)

```bash
# Snapの利用例
sudo snap install code --classic       # VS Code

# Flatpakの利用例
flatpak install flathub org.gimp.GIMP
```
