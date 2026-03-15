= クラスタ

== クラスタとは

Proxmox VE クラスタは、複数のノードを統合管理する仕組みです。
Corosync と pmxcfs を使用して、設定の同期とクラスタ通信を行います。

=== クラスタの利点

- *一元管理*：すべてのノードを 1 つの Web UI から操作
- *ライブマイグレーション*：稼働中の VM を別ノードに無停止移動
- *高可用性（HA）*：ノード障害時に VM を自動フェイルオーバー
- *共有設定*：ユーザー、権限、ストレージ設定の共有

=== クラスタの要件

- 全ノードが同じバージョンの Proxmox VE
- 専用のクラスタネットワーク（推奨）
- 全ノード間で名前解決が可能
- 最低 3 ノード（クォーラム確保のため、2 ノードも可能だが非推奨）

== クラスタの構築

=== 最初のノードでクラスタを作成

```bash
# クラスタの作成
pvecm create <クラスタ名>

# 例
pvecm create my-cluster

# クラスタの状態確認
pvecm status
```

=== 他のノードの参加

```bash
# 2 台目以降のノードで実行
pvecm add <最初のノードのIP>

# 例
pvecm add 192.168.1.100
```

=== クラスタの確認

```bash
# クラスタの状態
pvecm status

# ノード一覧
pvecm nodes

# Corosync の状態確認
systemctl status corosync
```

== ライブマイグレーション

稼働中の VM を別ノードに無停止で移動できます。

=== 前提条件

- 全ノードからアクセス可能な共有ストレージ（またはローカルストレージ間のコピー）
- 互換性のある CPU（同じベンダー推奨）
- 十分なネットワーク帯域

=== マイグレーションの実行

```bash
# オンラインマイグレーション（共有ストレージ使用時）
qm migrate <vmid> <移動先ノード> --online

# ローカルストレージ間のマイグレーション
qm migrate <vmid> <移動先ノード> --online --with-local-disks

# コンテナのマイグレーション
pct migrate <ctid> <移動先ノード> --online
```

== 高可用性（HA）

HA を設定すると、ノード障害時に VM/CT が自動的に別ノードで再起動されます。

=== HA の設定

```bash
# HA リソースの追加
ha-manager add vm:<vmid>

# 優先ノードの設定
ha-manager set vm:<vmid> --group <HAグループ>

# HA の状態確認
ha-manager status
```

=== HA グループ

HA グループでフェイルオーバー先のノードと優先順位を定義します。

```bash
# HA グループの作成
ha-manager groupadd prefer-node1 --nodes node1,node2,node3 \
  --nofailback 0 --restricted 0

# restricted: 1 にすると、グループ内のノードでのみ実行
# nofailback: 0 にすると、元のノード復旧時に自動で戻る
```

Web UI では「Datacenter」→「HA」→「Groups」→「Create」から作成できます。

=== HA の状態とリソース管理

```bash
# HA リソースの状態確認
ha-manager status

# リソースの状態変更
ha-manager set vm:<vmid> --state started    # 起動状態を維持
ha-manager set vm:<vmid> --state stopped    # 停止状態を維持
ha-manager set vm:<vmid> --state disabled   # HA 管理から一時除外
ha-manager set vm:<vmid> --state ignored    # HA の監視対象外

# HA リソースの削除
ha-manager remove vm:<vmid>
```

=== フェンシング

HA が正しく機能するためには、フェンシング（障害ノードの強制停止）が重要です。
フェンシングにより、障害ノード上のリソースが安全に別ノードで起動できることを保証します。

Proxmox VE はデフォルトで Linux ソフトウェア watchdog を使用します。
ハードウェア watchdog（IPMI など）を使用するとより信頼性が向上します。

```bash
# watchdog の状態確認
systemctl status watchdog-mux

# ハードウェア watchdog の設定（/etc/default/pve-ha-manager）
# WATCHDOG_MODULE=ipmi_watchdog
```

== クォーラムの仕組み

クラスタが正常に動作するには過半数のノード（クォーラム）が通信可能である必要があります。
クォーラムを失うと、クラスタファイルシステムが読み取り専用になり、
VM/CT の起動・停止・マイグレーションが不可能になります。

#table(
  columns: (auto, auto, auto),
  inset: 8pt,
  align: left,
  table.header(
    [*ノード数*], [*クォーラム*], [*許容障害数*],
  ),
  [2], [2（全台必要）], [0（HA 不可）],
  [3], [2], [1],
  [4], [3], [1],
  [5], [3], [2],
)

== 2 ノードクラスタ

2 ノード構成ではクォーラムの問題が発生するため、特別な対策が必要です。

=== QDevice の導入（推奨）

QDevice は外部の軽量サーバーに第三の投票権を持たせ、
2 ノードでも安全なクォーラムを実現します。

```bash
# QDevice サーバー側の準備（Debian/Ubuntu）
apt install corosync-qnetd

# Proxmox ノード側から QDevice をセットアップ
pvecm qdevice setup <QDeviceサーバーIP>

# QDevice の状態確認
pvecm qdevice status
```

QDevice サーバーは低スペックで十分です（Raspberry Pi でも可）。
Proxmox VE 自体をインストールする必要はありません。

=== QDevice なしの場合

QDevice を使わない場合は、手動でクォーラムを調整します。

```bash
# 1 ノードがダウンした時に残りのノードで強制的にクォーラムを確保
pvecm expected 1
```

ただし、スプリットブレイン（両ノードが独立稼働）のリスクがあるため、
可能な限り QDevice の導入を推奨します。

== クラスタのトラブルシューティング

=== クラスタの健全性確認

```bash
# クラスタの状態
pvecm status

# 全ノードの接続状況
pvecm nodes

# Corosync のリングステータス
corosync-cfgtool -s

# クラスタファイルシステムの状態
pmxcfs -l
```

=== よくある問題

==== ノードがオフライン表示される

```bash
# Corosync と pve-cluster の再起動
systemctl restart corosync
systemctl restart pve-cluster

# ネットワーク接続の確認
ping <他ノードのIP>

# Corosync の通信ポート確認（UDP 5405-5412）
ss -ulnp | grep corosync
```

==== クォーラム喪失からの復旧

```bash
# 残存ノードで期待投票数を調整
pvecm expected 1

# クラスタファイルシステムが復旧するまで待機
pvecm status
```

==== スプリットブレインの解消

+ 両方のノードの VM を確認し、どちらを正とするか決定
+ 一方のノードを停止
+ 稼働ノードでクォーラムを確保
+ 停止ノードを再起動してクラスタに再参加

== クラスタからのノード削除

```bash
# 1. ノード上の VM/CT を他ノードにマイグレーション
qm migrate <vmid> <移動先ノード> --online

# 2. HA リソースを削除
ha-manager remove vm:<vmid>

# 3. 残りのノードから削除を実行
pvecm delnode <ノード名>

# 4. 残りのノードで設定をクリーンアップ
rm -rf /etc/pve/nodes/<ノード名>
```

削除するノード自体はクラスタから切り離された後、
Proxmox VE を再インストールするか `pvecm updatecerts` でリセットします。
