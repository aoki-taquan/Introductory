= バックアップとリストア

== バックアップの種類

Proxmox VE では `vzdump` ツールを使用してバックアップを取得します。
3 つのバックアップモードがあります：

- *Snapshot*：稼働中の VM/CT をスナップショットベースでバックアップ（推奨）
- *Suspend*：メモリを保存して一時停止後にバックアップ（ダウンタイムあり）
- *Stop*：完全停止後にバックアップ（最も確実だがダウンタイムあり）

== バックアップの実行

=== Web UI から

+ VM/CT を選択 → 「Backup」タブ
+ 「Backup now」をクリック
+ モード、圧縮方式、ストレージを選択して実行

=== コマンドラインから

```bash
# 基本的なバックアップ
vzdump <vmid> --storage local --compress zstd --mode snapshot

# 全 VM/CT のバックアップ
vzdump --all --storage local --compress zstd --mode snapshot

# 複数指定
vzdump 100 101 200 --storage local --compress zstd
```

=== 圧縮方式

- *none*：無圧縮（高速だがサイズ大）
- *lzo*：軽量圧縮（バランス型）
- *gzip*：標準圧縮
- *zstd*：高圧縮率・高速（推奨）

== スケジュールバックアップ

=== Web UI から設定

+ データセンター → Backup
+ 「Add」をクリック
+ スケジュール、対象、ストレージ、モードを設定

=== 設定ファイル

スケジュールは `/etc/pve/jobs.cfg` で管理されます。

```
job: vzdump
  schedule daily
  all 1
  enabled 1
  storage local
  compress zstd
  mode snapshot
  mailnotification always
  mailto admin@example.com
```

== リストア（復元）

=== Web UI から

+ ストレージ → 「Backups」タブ
+ バックアップファイルを選択 → 「Restore」

=== コマンドラインから

```bash
# VM のリストア
qmrestore /var/lib/vz/dump/vzdump-qemu-100-*.vma.zst 100

# 別の VM ID でリストア
qmrestore /var/lib/vz/dump/vzdump-qemu-100-*.vma.zst 105

# コンテナのリストア
pct restore 200 /var/lib/vz/dump/vzdump-lxc-200-*.tar.zst

# ストレージを指定してリストア
qmrestore /var/lib/vz/dump/vzdump-qemu-100-*.vma.zst 100 \
  --storage local-lvm
```

== Proxmox Backup Server（PBS）

Proxmox Backup Server は Proxmox VE 専用のバックアップサーバーです。
vzdump よりも高度な機能を提供します。

=== 主な特徴

- *増分バックアップ*：変更されたデータのみを転送・保存
- *重複排除*：データストア全体で重複データを排除
- *暗号化*：クライアントサイドの暗号化
- *整合性検証*：自動的なバックアップの整合性チェック
- *高速リストア*：ファイルレベルのリストアも可能

=== PBS との連携設定

```bash
# PBS ストレージの追加
pvesm add pbs <名前> \
  --server <PBSサーバーIP> \
  --username <ユーザー>@pbs \
  --datastore <データストア名> \
  --fingerprint <フィンガープリント>
```

== バックアップの保持ポリシー

バックアップの自動削除ルールを設定できます。

```bash
# 保持設定の例
vzdump <vmid> --storage local \
  --prune-backups keep-daily=7,keep-weekly=4,keep-monthly=6
```

- *keep-last*：直近 N 個を保持
- *keep-daily*：日次で N 日分
- *keep-weekly*：週次で N 週分
- *keep-monthly*：月次で N ヶ月分
- *keep-yearly*：年次で N 年分
