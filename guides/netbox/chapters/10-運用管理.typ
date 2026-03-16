= 運用管理

== バックアップとリストア

=== データベースのバックアップ

定期的なバックアップを設定します。

```bash
#!/bin/bash
# backup_netbox.sh

BACKUP_DIR="/opt/backups/netbox"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p "$BACKUP_DIR"

# データベースのダンプ
docker compose -f /opt/netbox-docker/docker-compose.yml \
  exec -T postgres pg_dump -U netbox netbox | \
  gzip > "$BACKUP_DIR/netbox_db_$DATE.sql.gz"

# メディアファイル（画像・添付ファイル）のバックアップ
docker compose -f /opt/netbox-docker/docker-compose.yml \
  exec netbox tar -czf - /opt/netbox/netbox/media/ | \
  cat > "$BACKUP_DIR/netbox_media_$DATE.tar.gz"

# 古いバックアップを削除（30 日以上前）
find "$BACKUP_DIR" -mtime +30 -delete

echo "Backup completed: $DATE"
```

cron に登録：

```bash
# 毎日 2:00 にバックアップ
0 2 * * * /opt/scripts/backup_netbox.sh >> /var/log/netbox_backup.log 2>&1
```

=== リストア

```bash
# データベースのリストア
gunzip < netbox_db_20240101_020000.sql.gz | \
  docker compose exec -T postgres psql -U netbox netbox

# メディアファイルのリストア
cat netbox_media_20240101_020000.tar.gz | \
  docker compose exec -T netbox tar -xzf - -C /
```

== アップグレード

=== アップグレード前の確認

+ リリースノートを確認（破壊的変更がないか）
+ 現在のバージョンを確認
+ バックアップを取得
+ ステージング環境でテスト

```bash
# 現在のバージョン確認
docker compose exec netbox python /opt/netbox/netbox/manage.py version
```

=== アップグレード手順（netbox-docker）

```bash
cd /opt/netbox-docker

# リリースブランチを更新
git pull

# 新しいイメージを取得
docker compose pull

# 再起動
docker compose up -d

# マイグレーションの実行（自動で行われるが確認）
docker compose exec netbox python /opt/netbox/netbox/manage.py migrate

# ログ確認
docker compose logs -f netbox
```

== パフォーマンスチューニング

=== データベースの最適化

```bash
# VACUUM（不要データの解放）
docker compose exec postgres psql -U netbox -c "VACUUM ANALYZE;"

# インデックス統計の更新
docker compose exec postgres psql -U netbox -c "ANALYZE;"
```

=== Redis キャッシュ

NetBox は Redis をキャッシュとジョブキューに使用しています。

```bash
# Redis の状態確認
docker compose exec redis redis-cli info | grep -E "used_memory|connected_clients"
```

=== Workers の設定

バックグラウンドジョブ（Webhook、スクリプト実行など）は `rqworker` が処理します。

```yaml
# docker-compose.override.yml
services:
  netbox-worker:
    deploy:
      replicas: 2  # ワーカー数を増加
```

== 監視

=== ヘルスチェックエンドポイント

```
GET /api/status/
```

```json
{
  "django-version": "4.2.x",
  "installed-apps": {...},
  "netbox-version": "4.x.x",
  "plugins": [],
  "python-version": "3.11.x"
}
```

=== アクセスログ

```bash
# Nginx アクセスログ（コンテナ内）
docker compose logs nginx

# NetBox アプリログ
docker compose logs netbox | grep ERROR
```

=== Prometheus / Grafana との連携

`django-prometheus` を導入することで、
メトリクスを Prometheus で収集し Grafana で可視化できます。

== プラグイン

NetBox はプラグインによる機能拡張をサポートしています。

=== 主要なプラグイン

#table(
  columns: (auto, auto),
  inset: 8pt,
  align: left,
  table.header(
    [*プラグイン*], [*機能*],
  ),
  [netbox-bgp], [BGP ピア・セッション管理],
  [netbox-topology-views], [ネットワークトポロジー図の生成],
  [netbox-floorplan-plugin], [フロアプラン・ラック配置図],
  [netbox-secrets], [機密情報（パスワード等）の暗号化管理],
  [netbox-dns], [DNS ゾーン・レコード管理],
  [netbox-acls], [ACL 管理],
)

=== プラグインのインストール（Docker）

`configuration/plugins.py` に設定を追加します：

```python
PLUGINS = ['netbox_bgp']

PLUGINS_CONFIG = {
    'netbox_bgp': {
        'device_ext_page': 'right',
    }
}
```

`local_requirements.txt` にパッケージを追加します：

```
netbox-bgp
```

コンテナを再ビルドします：

```bash
docker compose build
docker compose up -d
```

== セキュリティのベストプラクティス

=== 本番環境向けの設定

```python
# configuration.py

# HTTPS 強制
SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True

# デバッグ無効
DEBUG = False

# 許可するホストを明示
ALLOWED_HOSTS = ['netbox.example.com']

# ログイン必須
LOGIN_REQUIRED = True

# セッションタイムアウト（30分）
LOGIN_TIMEOUT = 1800

# SECRET_KEY は環境変数から取得
import os
SECRET_KEY = os.environ.get('SECRET_KEY')
```

=== LDAP / SSO 連携

Active Directory や LDAP との認証連携が可能です。

```bash
pip install django-auth-ldap
```

```python
# ldap_config.py
import ldap
from django_auth_ldap.config import LDAPSearch, GroupOfNamesType

AUTH_LDAP_SERVER_URI = "ldap://ldap.example.com"
AUTH_LDAP_BIND_DN = "cn=netbox,ou=service,dc=example,dc=com"
AUTH_LDAP_BIND_PASSWORD = "password"

AUTH_LDAP_USER_SEARCH = LDAPSearch(
    "ou=users,dc=example,dc=com",
    ldap.SCOPE_SUBTREE,
    "(uid=%(user)s)"
)
```

=== 定期的なセキュリティタスク

- API トークンの定期的なローテーション
- 不要なユーザー・トークンの削除
- アクセスログの定期的なレビュー
- NetBox および依存パッケージの定期的なアップデート
- 脆弱性情報の購読（GitHub Security Advisories）

== よくあるトラブルと対処法

=== DB 接続エラー

```bash
# PostgreSQL コンテナの状態確認
docker compose ps postgres
docker compose logs postgres
```

=== マイグレーションの失敗

```bash
# マイグレーション状態の確認
docker compose exec netbox python manage.py showmigrations | grep "\[ \]"

# マイグレーションの再実行
docker compose exec netbox python manage.py migrate
```

=== パフォーマンス低下

```bash
# 遅いクエリの特定
docker compose exec postgres psql -U netbox -c \
  "SELECT query, mean_exec_time, calls FROM pg_stat_statements ORDER BY mean_exec_time DESC LIMIT 10;"
```
