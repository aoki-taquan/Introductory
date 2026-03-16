= サービス管理

== systemd

systemdは、現在の主要なLinuxディストリビューションで採用されているシステム・サービスマネージャである。サービスの起動・停止・監視をはじめ、ログ管理やタイマーなど多くの機能を提供する。

== サービスの操作

```bash
# サービスの状態確認
systemctl status nginx

# サービスの起動・停止・再起動
sudo systemctl start nginx
sudo systemctl stop nginx
sudo systemctl restart nginx

# 設定ファイルの再読み込み（プロセスは再起動しない）
sudo systemctl reload nginx

# 自動起動の有効化・無効化
sudo systemctl enable nginx          # 起動時に自動で開始
sudo systemctl disable nginx         # 自動起動を無効化
sudo systemctl enable --now nginx    # 有効化と同時に起動

# サービスの一覧
systemctl list-units --type=service
systemctl list-units --type=service --state=running
```

== ユニットファイル

systemdのサービスは「ユニットファイル」で定義される。ユニットファイルは通常 `/etc/systemd/system/` に配置する。

=== ユニットファイルの例

```ini
# /etc/systemd/system/myapp.service
[Unit]
Description=My Application
After=network.target
Wants=network-online.target

[Service]
Type=simple
User=appuser
Group=appuser
WorkingDirectory=/opt/myapp
ExecStart=/opt/myapp/bin/server
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

=== セクションの説明

#table(
  columns: (1fr, 1fr, 2fr),
  [*セクション*], [*キー*], [*説明*],
  [`[Unit]`], [`Description`], [サービスの説明],
  [`[Unit]`], [`After`], [このサービスより先に起動すべきユニット],
  [`[Unit]`], [`Wants`], [弱い依存関係（なくても起動する）],
  [`[Service]`], [`Type`], [サービスの起動タイプ（simple, forking, oneshot等）],
  [`[Service]`], [`ExecStart`], [起動コマンド],
  [`[Service]`], [`Restart`], [再起動ポリシー（on-failure, always等）],
  [`[Service]`], [`User`], [実行ユーザー],
  [`[Install]`], [`WantedBy`], [有効化時にどのターゲットに紐づけるか],
)

```bash
# ユニットファイルの変更後はデーモンをリロード
sudo systemctl daemon-reload

# サービスを起動
sudo systemctl start myapp
sudo systemctl enable myapp
```

== ログ管理（journalctl）

systemdのログはjournaldによって管理される。`journalctl` コマンドで閲覧する。

```bash
# 全ログの表示
journalctl

# 特定のサービスのログ
journalctl -u nginx

# リアルタイムでログを追跡
journalctl -u nginx -f

# 今日のログのみ
journalctl --since today

# 期間を指定
journalctl --since "2026-03-15" --until "2026-03-16"

# カーネルログ
journalctl -k

# ログの使用量確認
journalctl --disk-usage

# 古いログの削除
sudo journalctl --vacuum-time=7d     # 7日以上前のログを削除
sudo journalctl --vacuum-size=500M   # 500MB以下に削減
```

== ターゲット（ランレベル）

systemdでは従来のランレベルに代わり「ターゲット」でシステムの状態を管理する。

#table(
  columns: (1fr, 1fr, 2fr),
  [*ターゲット*], [*旧ランレベル*], [*説明*],
  [`poweroff.target`], [0], [システム停止],
  [`rescue.target`], [1], [シングルユーザーモード（レスキュー）],
  [`multi-user.target`], [3], [マルチユーザー（GUIなし）],
  [`graphical.target`], [5], [マルチユーザー（GUI付き）],
  [`reboot.target`], [6], [再起動],
)

```bash
# 現在のターゲットを確認
systemctl get-default

# デフォルトのターゲットを変更
sudo systemctl set-default multi-user.target

# システムの再起動・停止
sudo systemctl reboot
sudo systemctl poweroff
```

== systemd timer

cronの代替として、systemd timerを使用した定期実行も可能である。

```ini
# /etc/systemd/system/backup.timer
[Unit]
Description=Daily backup timer

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
```

```ini
# /etc/systemd/system/backup.service
[Unit]
Description=Backup service

[Service]
Type=oneshot
ExecStart=/home/user/backup.sh
```

```bash
# timerの有効化
sudo systemctl enable --now backup.timer

# timerの一覧
systemctl list-timers
```
