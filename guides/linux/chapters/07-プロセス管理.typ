= プロセス管理

== プロセスとは

プロセスとは、実行中のプログラムのインスタンスである。各プロセスにはPID（Process ID）が割り当てられ、カーネルによって管理される。

== プロセスの確認

```bash
# 現在のシェルのプロセスを表示
ps

# 全プロセスを詳細表示
ps aux

# 特定のプロセスを検索
ps aux | grep nginx

# プロセスツリーの表示
pstree

# リアルタイムのプロセスモニタ
top

# より高機能なモニタ（インストールが必要な場合あり）
htop
```

=== psコマンドの出力の見方

```
USER       PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
root         1  0.0  0.1 169392 13284 ?        Ss   Mar15   0:02 /sbin/init
```

#table(
  columns: (1fr, 3fr),
  [*フィールド*], [*説明*],
  [USER], [プロセスの実行ユーザー],
  [PID], [プロセスID],
  [%CPU], [CPU使用率],
  [%MEM], [メモリ使用率],
  [VSZ], [仮想メモリサイズ],
  [RSS], [物理メモリ使用量],
  [STAT], [プロセスの状態（S:スリープ、R:実行中、Z:ゾンビ、T:停止）],
  [COMMAND], [実行コマンド],
)

== シグナルとプロセスの制御

シグナルはプロセスに送られる通知で、プロセスの動作を制御するために使用する。

```bash
# プロセスの終了
kill PID              # SIGTERM（正常終了要求）
kill -9 PID           # SIGKILL（強制終了）
kill -HUP PID         # SIGHUP（設定の再読み込み）

# プロセス名で終了
killall nginx
pkill -f "python app.py"
```

主要なシグナル:

#table(
  columns: (1fr, 1fr, 2fr),
  [*シグナル*], [*番号*], [*説明*],
  [SIGHUP], [1], [ハングアップ。設定再読み込みに使われることが多い],
  [SIGINT], [2], [`Ctrl+C` で送られる割り込みシグナル],
  [SIGTERM], [15], [正常終了要求（デフォルト）],
  [SIGKILL], [9], [強制終了（プロセスは無視できない）],
  [SIGSTOP], [19], [プロセスの一時停止],
  [SIGCONT], [18], [停止したプロセスの再開],
)

== ジョブ管理

シェルでは、フォアグラウンドとバックグラウンドでジョブを管理できる。

```bash
# バックグラウンドで実行
long_running_command &

# 実行中のジョブ一覧
jobs

# フォアグラウンドのジョブをバックグラウンドへ
# Ctrl+Z で一時停止してから
bg

# バックグラウンドのジョブをフォアグラウンドへ
fg %1

# ターミナル切断後も継続して実行
nohup long_running_command &
```

== リソースの監視

```bash
# メモリ使用量
free -h

# CPU情報
lscpu
cat /proc/cpuinfo

# ディスクI/Oの監視
iostat -x 1

# システム全体の負荷
uptime

# 詳細なリソース監視
vmstat 1 5            # 1秒間隔で5回表示
```

== cronによるタスクスケジューリング

cronはLinux標準のタスクスケジューラであり、定期的なジョブの実行に使用する。

```bash
# 現在のcrontabを表示
crontab -l

# crontabを編集
crontab -e
```

crontabの書式:

```
分 時 日 月 曜日 コマンド
```

```bash
# 毎日午前3時にバックアップスクリプトを実行
0 3 * * * /home/user/backup.sh

# 5分ごとにヘルスチェック
*/5 * * * * /usr/local/bin/healthcheck.sh

# 毎週月曜の午前9時にレポートを送信
0 9 * * 1 /home/user/report.sh

# 毎月1日の午前0時にログをローテーション
0 0 1 * * /usr/sbin/logrotate /etc/logrotate.conf
```

systemdベースのシステムではsystemd timerも利用できる。
