= ネットワーク

== ネットワークの基本構成

Proxmox VE のネットワークは Linux の標準的なネットワーク機能を使用しています。
デフォルトでは以下のような構成になっています：

- *物理 NIC*（`eno1`、`enp0s3` など）：実際のネットワークインターフェース
- *Linux Bridge*（`vmbr0`）：VM やコンテナが接続する仮想スイッチ

```
物理ネットワーク ─── eno1 ─── vmbr0 ─┬─ VM 100
                                       ├─ VM 101
                                       ├─ CT 200
                                       └─ ホスト管理
```

== ブリッジの設定

=== Web UI から

+ ノード → System → Network
+ 「Create」→ 「Linux Bridge」を選択
+ 設定項目を入力して適用

=== 設定ファイル

ネットワーク設定は `/etc/network/interfaces` で管理されます。

```bash
# /etc/network/interfaces の例
auto lo
iface lo inet loopback

# 物理 NIC
auto eno1
iface eno1 inet manual

# メインブリッジ
auto vmbr0
iface vmbr0 inet static
    address 192.168.1.100/24
    gateway 192.168.1.1
    bridge-ports eno1
    bridge-stp off
    bridge-fd 0
```

設定変更後は以下のコマンドで適用します：

```bash
ifreload -a
```

== VLAN

VLAN を使用してネットワークを論理的に分離できます。

=== VLAN Aware ブリッジ

ブリッジを VLAN aware に設定すると、VM ごとに VLAN タグを指定できます。

```bash
# /etc/network/interfaces
auto vmbr0
iface vmbr0 inet static
    address 192.168.1.100/24
    gateway 192.168.1.1
    bridge-ports eno1
    bridge-stp off
    bridge-fd 0
    bridge-vlan-aware yes
    bridge-vids 2-4094
```

VM のネットワーク設定で VLAN Tag を指定：

```bash
# VM に VLAN 100 を設定
qm set <vmid> --net0 virtio,bridge=vmbr0,tag=100
```

== ボンディング

複数の NIC を束ねて冗長性と帯域幅を向上させます。

```bash
# /etc/network/interfaces
auto bond0
iface bond0 inet manual
    bond-slaves eno1 eno2
    bond-miimon 100
    bond-mode 802.3ad       # LACP
    bond-xmit-hash-policy layer3+4

auto vmbr0
iface vmbr0 inet static
    address 192.168.1.100/24
    gateway 192.168.1.1
    bridge-ports bond0
    bridge-stp off
    bridge-fd 0
```

主なボンディングモード：

- *balance-rr (0)*：ラウンドロビン
- *active-backup (1)*：アクティブ/スタンバイ（スイッチ設定不要）
- *802.3ad (4)*：LACP（スイッチ側の設定も必要）

== ファイアウォール

Proxmox VE には統合ファイアウォールが搭載されています。
データセンター、ノード、VM/コンテナの 3 階層で設定できます。

=== ファイアウォールの有効化

```bash
# データセンターレベルで有効化
# /etc/pve/firewall/cluster.fw
[OPTIONS]
enable: 1

# VM レベルで有効化
# /etc/pve/firewall/<vmid>.fw
[OPTIONS]
enable: 1
```

=== ルールの追加

Web UI で「Firewall」タブからルールを追加できます。

```bash
# 設定ファイルの例（/etc/pve/firewall/<vmid>.fw）
[RULES]
IN ACCEPT -source 192.168.1.0/24 -p tcp -dport 22
IN ACCEPT -p tcp -dport 80
IN ACCEPT -p tcp -dport 443
IN DROP
```

=== セキュリティグループ

よく使うルールセットをグループ化して再利用できます。

```bash
# /etc/pve/firewall/cluster.fw
[group web-server]
IN ACCEPT -p tcp -dport 80
IN ACCEPT -p tcp -dport 443

[group ssh-access]
IN ACCEPT -source 192.168.1.0/24 -p tcp -dport 22
```

== SDN（Software Defined Networking）

Proxmox VE 7 以降では SDN 機能が利用可能です（8.x で正式サポート）。
VXLAN や EVPN を使用した高度なネットワーク構成が可能です。

=== SDN の有効化

Web UI の「Datacenter」→「SDN」から設定できます。

主な概念：
- *Zone*：ネットワーク分離の単位（Simple、VLAN、VXLAN、EVPN）
- *VNet*：仮想ネットワーク
- *Subnet*：VNet 内のサブネット定義
