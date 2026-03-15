= ストレージ

== ストレージの概念

Proxmox VE では、ストレージをコンテンツタイプで分類して管理します。

=== コンテンツタイプ

- *images*：VM のディスクイメージ
- *rootdir*：コンテナのルートディレクトリ
- *iso*：ISO イメージファイル
- *vztmpl*：コンテナテンプレート
- *backup*：バックアップファイル
- *snippets*：スニペット（cloud-init 設定など）

== ストレージの種類

=== ローカルストレージ

==== LVM

Proxmox VE のデフォルトインストールで使用されるストレージです。

```bash
# LVM の状態確認
lvs
vgs

# LVM ストレージの追加
pvesm add lvm <名前> --vgname <VG名> --content images,rootdir
```

==== LVM-Thin

シンプロビジョニングに対応した LVM です。スナップショットが可能で、
実際に使用された分だけディスクを消費します。

```bash
pvesm add lvmthin <名前> --vgname <VG名> --thinpool <プール名> \
  --content images,rootdir
```

==== ZFS

ZFS は高機能なファイルシステム兼ボリュームマネージャーです。

主な特徴：
- *データ整合性*：チェックサムによるデータ破損検出
- *スナップショット*：瞬時に作成、ほぼゼロコスト
- *圧縮*：透過的なデータ圧縮
- *RAID*：ソフトウェア RAID（mirror、raidz、raidz2、raidz3）
- *重複排除*：同一データのデデュプリケーション（1 TB あたり約 5 GB の RAM が必要。通常は無効推奨）

```bash
# ZFS プールの作成（ミラー：2 台で冗長化）
zpool create -f mypool mirror /dev/sda /dev/sdb

# RAIDZ1（RAID5 相当：3 台以上、1 台障害耐性）
zpool create -f mypool raidz /dev/sda /dev/sdb /dev/sdc

# RAIDZ2（RAID6 相当：4 台以上、2 台障害耐性、推奨）
zpool create -f mypool raidz2 /dev/sda /dev/sdb /dev/sdc /dev/sdd

# ZFS ストレージの追加
pvesm add zfspool <名前> --pool <プール名> --content images,rootdir

# ZFS プールの状態確認
zpool status
zpool list

# ZFS データセットの確認
zfs list
```

==== Directory

通常のディレクトリをストレージとして利用します。

```bash
# ディレクトリストレージの追加
pvesm add dir <名前> --path /mnt/data --content iso,vztmpl,backup
```

=== 共有ストレージ

==== NFS

ネットワーク経由でファイルを共有するプロトコルです。

```bash
# NFS ストレージの追加
pvesm add nfs <名前> \
  --server <NFSサーバーIP> \
  --export /share/path \
  --content iso,vztmpl,backup,images
```

==== CIFS/SMB

Windows ファイル共有プロトコルです。

```bash
pvesm add cifs <名前> \
  --server <サーバーIP> \
  --share <共有名> \
  --username <ユーザー> \
  --content backup,iso,vztmpl
```

==== iSCSI

ブロックデバイスをネットワーク経由で提供するプロトコルです。

```bash
pvesm add iscsi <名前> \
  --portal <サーバーIP> \
  --target <IQN>
```

==== Ceph (RBD)

分散ストレージシステムです。Proxmox VE に統合されており、
Web UI からクラスタの構築・管理が可能です。

```bash
pvesm add rbd <名前> \
  --monhost <モニターIP> \
  --pool <プール名> \
  --content images,rootdir
```

== ストレージの管理

```bash
# ストレージ一覧の確認
pvesm status

# ストレージの詳細
pvesm list <ストレージ名>

# ストレージの削除
pvesm remove <ストレージ名>
```

== 推奨構成例

=== 単一ノード構成

- *OS*：ZFS mirror（SSD x 2）
- *VM/CT ディスク*：ZFS（同上またはデータ用プール）
- *ISO・テンプレート*：local ディレクトリ
- *バックアップ*：NFS または外部 HDD

=== クラスタ構成

- *OS*：各ノードのローカル SSD
- *VM/CT ディスク*：Ceph RBD または共有ストレージ
- *ISO・テンプレート*：NFS（共有）
- *バックアップ*：Proxmox Backup Server
