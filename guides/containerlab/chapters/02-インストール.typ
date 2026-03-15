= インストール

== 動作要件

Containerlab を利用するには以下が必要です：

- *OS*：Linux（Ubuntu 20.04+、Debian 10+、RHEL 8+、Fedora、Rocky Linux）
- *Docker*：Docker CE がインストール済みであること
- *権限*：`sudo` 権限（コンテナネットワーク操作に必要）
- *CPU*：x86_64 または ARM64
- *メモリ*：ラボ規模に依存（最低 4GB 推奨）

#table(
  columns: (auto, 1fr),
  align: (left, left),
  table.header([*プラットフォーム*], [*サポート状況*]),
  [Linux（ネイティブ）], [フルサポート。推奨環境],
  [Windows（WSL2）], [WSL2 + Docker で動作可能],
  [macOS], [Docker Desktop / Colima で基本機能のみ。vrnetlab 非対応],
)

== クイックセットアップ（推奨）

Docker と Containerlab を一括でインストールするスクリプトが用意されています：

```bash
curl -sL https://containerlab.dev/setup | sudo -E bash -s "all"
```

このコマンドは以下を実行します：
- Docker CE のインストール（未インストールの場合）
- Containerlab のインストール
- GitHub CLI のインストール

== インストールスクリプト

Docker が既にインストール済みの場合、Containerlab のみをインストールできます：

```bash
bash -c "$(curl -sL https://get.containerlab.dev)"
```

特定のバージョンを指定する場合：

```bash
bash -c "$(curl -sL https://get.containerlab.dev)" -- -v 0.60.0
```

== パッケージマネージャ

=== APT（Debian / Ubuntu）

```bash
echo "deb [trusted=yes] https://netdevops.fury.site/apt/ /" | \
  sudo tee /etc/apt/sources.list.d/netdevops.list
sudo apt update && sudo apt install containerlab
```

=== YUM / DNF（RHEL / Fedora）

```bash
sudo dnf config-manager addrepo \
  --set=baseurl="https://netdevops.fury.site/yum/"
sudo dnf install containerlab
```

== Docker コンテナとして実行

Containerlab 自体をコンテナとして実行することもできます：

```bash
docker pull ghcr.io/srl-labs/clab
```

== インストールの確認

```bash
containerlab version
```

バージョン情報が表示されれば正常にインストールされています。

== Docker の確認

Containerlab は Docker を必要とします。Docker が正しく動作しているか確認します：

```bash
docker info
```

Docker が起動していない場合：

```bash
sudo systemctl start docker
sudo systemctl enable docker
```

== アップデート

最新版へのアップデートは、インストールスクリプトを再実行するだけです：

```bash
bash -c "$(curl -sL https://get.containerlab.dev)"
```

パッケージマネージャ経由の場合は通常のアップデートコマンドを使用します：

```bash
sudo apt update && sudo apt upgrade containerlab  # Debian/Ubuntu
sudo dnf update containerlab                       # RHEL/Fedora
```
