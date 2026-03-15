= 監視と通知

== 組み込みの監視機能

=== Web UI のダッシュボード

ノードを選択すると「Summary」画面で以下をリアルタイム監視できます：

- CPU 使用率（ホスト全体およびゲストごと）
- メモリ使用量
- ネットワークトラフィック
- ディスク I/O
- ストレージ使用率

=== コマンドラインでの確認

```bash
# ノードのリソース状況
pvesh get /nodes/<ノード名>/status

# 全 VM/CT のリソース情報
pvesh get /cluster/resources --type vm

# ストレージの使用状況
pvesm status

# ZFS プールの状態
zpool status
zpool list

# ディスクの S.M.A.R.T. 情報
smartctl -a /dev/sda
```

== 通知システム

Proxmox VE 8.1 以降では、新しい通知システムが搭載されています。
Web UI の「Datacenter」→「Notifications」から設定します。

=== 通知の仕組み

通知は以下の 3 つの要素で構成されます：

- *Target（送信先）*：メール、Gotify、Webhook など通知の送り先
- *Matcher（条件）*：どのイベントをどの Target に送るかのルール
- *Event（イベント）*：バックアップ完了、フェンシング発生などのトリガー

=== メール通知の設定

==== Sendmail（デフォルト）

Proxmox VE には Postfix がインストールされています。

```bash
# Postfix の設定（リレーサーバー経由で送信）
cat >> /etc/postfix/main.cf << EOF
relayhost = [smtp.example.com]:587
smtp_use_tls = yes
smtp_sasl_auth_enable = yes
smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd
smtp_sasl_security_options = noanonymous
EOF

# SMTP 認証情報の設定
echo "[smtp.example.com]:587 user@example.com:password" \
  > /etc/postfix/sasl_passwd
chmod 600 /etc/postfix/sasl_passwd
postmap /etc/postfix/sasl_passwd

# Postfix の再起動
systemctl restart postfix

# テストメールの送信
echo "Test" | mail -s "PVE Test" admin@example.com
```

==== SMTP Target の作成（Web UI）

+ 「Datacenter」→「Notifications」→「Add」→「SMTP」
+ サーバー情報を入力：
  - *Server*：SMTP サーバーのアドレス
  - *Port*：587（TLS）または 465（SSL）
  - *Username / Password*：認証情報
  - *Mail From*：送信元アドレス
  - *Recipients*：宛先アドレス

=== Matcher の設定

Matcher でどのイベントをどの Target に送るか定義します。

```
# /etc/pve/notifications.cfg の例
matcher: backup-notify
  target smtp-target
  mode all
  match-severity info,warning,error
  match-field exact:type=vzdump

matcher: ha-notify
  target smtp-target
  mode all
  match-severity warning,error
  match-field exact:type=fencing
```

主なイベントタイプ：

- `vzdump`：バックアップジョブの結果
- `replication`：レプリケーションの結果
- `fencing`：HA フェンシングの発生
- `package-updates`：パッケージ更新の通知

== 外部監視ツールとの連携

=== Prometheus + Grafana

Proxmox VE のメトリクスを Prometheus で収集し、Grafana で可視化できます。

==== PVE Exporter のセットアップ

```bash
# 監視サーバー側で pve-exporter をインストール
pip install prometheus-pve-exporter

# 設定ファイルの作成
cat > /etc/pve-exporter.yml << EOF
default:
  user: monitor@pve
  token_name: prometheus
  token_value: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  verify_ssl: false
EOF

# 起動
pve_exporter /etc/pve-exporter.yml
```

==== Proxmox 側の準備

```bash
# 監視用ユーザーの作成
pveum user add monitor@pve
pveum acl modify / --users monitor@pve --roles PVEAuditor

# API トークンの作成
pveum user token add monitor@pve prometheus --privsep 0
```

==== Prometheus の設定

```yaml
# prometheus.yml に追加
scrape_configs:
  - job_name: 'proxmox'
    static_configs:
      - targets: ['<exporter-host>:9221']
    metrics_path: /pve
    params:
      target: ['<proxmox-host>']
```

=== SNMP

```bash
# SNMP の有効化
apt install snmpd
systemctl enable --now snmpd
```

== ヘルスチェックのベストプラクティス

定期的に確認すべき項目：

- *ストレージ*：`zpool status` で degraded がないか
- *ディスク健全性*：`smartctl` で S.M.A.R.T. エラーがないか
- *クラスタ*：`pvecm status` で全ノードがオンラインか
- *バックアップ*：直近のバックアップジョブが成功しているか
- *更新*：セキュリティアップデートが適用されているか
- *証明書*：SSL 証明書の有効期限

```bash
# 簡易ヘルスチェックスクリプトの例
#!/bin/bash
echo "=== ノード状態 ==="
pvesh get /nodes --output-format text

echo "=== ストレージ状態 ==="
pvesm status

echo "=== ZFS 状態 ==="
zpool status -x

echo "=== 失敗タスク（直近24h）==="
pvesh get /cluster/tasks --errors 1 --limit 10
```
