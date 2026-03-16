= インストール

== システム要件

NetBox を動作させるための要件は以下の通りです。

=== Docker を使ったインストール（推奨）

本書では Docker Compose を使ったインストール方法を解説します。
最もシンプルで再現性が高い方法です。

- *OS*：Linux（Ubuntu 22.04 / Debian 12 推奨）、macOS、Windows（WSL2）
- *CPU*：2 コア以上
- *メモリ*：4 GB 以上（推奨 8 GB）
- *ストレージ*：20 GB 以上
- *Docker*：24.0 以上
- *Docker Compose*：2.0 以上

=== ベアメタル・仮想マシンへのインストール

Python 3.10 以上、PostgreSQL 14 以上、Redis 7.0 以上が必要です。
本書では Docker Compose 方式を推奨します。

== Docker のインストール

=== Ubuntu / Debian

```bash
# 古いバージョンのアンインストール
sudo apt remove docker docker-engine docker.io containerd runc

# 必要パッケージのインストール
sudo apt update
sudo apt install -y ca-certificates curl gnupg

# Docker の公式 GPG キーを追加
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# リポジトリの追加
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Docker のインストール
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin

# 現在のユーザーを docker グループに追加（再ログイン後に有効）
sudo usermod -aG docker $USER
```

== netbox-docker を使ったインストール

NetBox 公式が提供する `netbox-docker` を使うと、簡単に Docker 環境を構築できます。

=== リポジトリのクローン

```bash
git clone -b release https://github.com/netbox-community/netbox-docker.git
cd netbox-docker
```

=== docker-compose.override.yml の作成

```bash
tee docker-compose.override.yml <<EOF
services:
  netbox:
    ports:
      - 8000:8080
EOF
```

=== 起動

```bash
docker compose pull
docker compose up -d
```

初回起動時はイメージのダウンロードと DB の初期化が行われます。
完了まで数分かかる場合があります。

=== 起動確認

```bash
docker compose ps
```

すべてのサービスが `running` または `healthy` になっていれば成功です。

```
NAME                   STATUS
netbox-docker-netbox   running (healthy)
netbox-docker-postgres  running (healthy)
netbox-docker-redis    running (healthy)
```

== 初期設定

=== Web UI へのアクセス

ブラウザで以下の URL にアクセスします：

```
http://<サーバーのIPアドレス>:8000
```

デフォルトの管理者アカウントは以下の通りです：

- *ユーザー名*：`admin`
- *パスワード*：`admin`

ログイン後、速やかにパスワードを変更してください。

=== スーパーユーザーの作成

```bash
docker compose exec netbox /opt/netbox/netbox/manage.py createsuperuser
```

=== タイムゾーンの設定

`docker-compose.override.yml` に環境変数を追加します：

```yaml
services:
  netbox:
    environment:
      - TIME_ZONE=Asia/Tokyo
```

変更後に再起動します：

```bash
docker compose up -d
```

== 設定ファイルのカスタマイズ

=== configuration.py の主要な設定

`env/netbox.env` または `configuration/configuration.py` で主要な設定を変更できます。

```python
# ログイン不要でのAPIアクセスを制限
LOGIN_REQUIRED = True

# セッションのタイムアウト（秒）
LOGIN_TIMEOUT = 1800

# ページあたりの表示件数
PAGINATE_COUNT = 50

# 許可するホスト名
ALLOWED_HOSTS = ['netbox.example.com', '192.168.1.10']
```

== アップグレード

```bash
cd netbox-docker
git pull
docker compose pull
docker compose up -d
```

== バックアップ

=== データベースのバックアップ

```bash
docker compose exec postgres pg_dump -U netbox netbox > netbox_backup.sql
```

=== リストア

```bash
docker compose exec -T postgres psql -U netbox netbox < netbox_backup.sql
```
