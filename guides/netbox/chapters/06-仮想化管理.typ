= 仮想化管理

NetBox では仮想マシンやコンテナのインフラ情報も管理できます。

== 管理構造

```
Cluster Type（クラスタータイプ）
  └── Cluster（クラスター）
        └── Virtual Machine（仮想マシン）
              └── VM Interface（仮想インターフェース）
                    └── IP Address（IP アドレス）
```

== Cluster Type（クラスタータイプ）

仮想化プラットフォームの種類を定義します。

Virtualization > Cluster Types から作成します。

例：
- VMware vSphere
- Proxmox VE
- OpenStack
- Kubernetes
- KVM / libvirt

== Cluster（クラスター）

仮想化ホストのグループ（クラスター）を管理します。

=== 主要フィールド

#table(
  columns: (auto, auto),
  inset: 8pt,
  align: left,
  table.header(
    [*フィールド*], [*説明*],
  ),
  [Name], [クラスター名（例：vsphere-prod-01）],
  [Type], [クラスタータイプ（例：VMware vSphere）],
  [Group], [クラスターグループ（任意）],
  [Site], [設置サイト],
  [Status], [Active / Planned / Staged など],
  [Description], [説明],
)

=== クラスターへのホスト割り当て

クラスター詳細画面の「Devices」タブから、
物理ホストサーバー（Device）をクラスターのメンバーとして割り当てます。

== Virtual Machine（仮想マシン）

仮想マシンの情報を管理します。

=== 主要フィールド

#table(
  columns: (auto, auto),
  inset: 8pt,
  align: left,
  table.header(
    [*フィールド*], [*説明*],
  ),
  [Name], [VM 名（例：web-server-01）],
  [Status], [Active / Staged / Offline など],
  [Cluster], [所属クラスター],
  [Device], [稼働する物理ホスト（任意）],
  [Role], [役割（例：Web Server、DB Server）],
  [Platform], [OS プラットフォーム（例：Ubuntu 22.04）],
  [Primary IPv4], [主要 IPv4 アドレス],
  [Primary IPv6], [主要 IPv6 アドレス],
  [vCPUs], [仮想 CPU 数],
  [Memory（MB）], [メモリ量（MB）],
  [Disk（GB）], [ディスク容量（GB）],
  [Tenant], [所属テナント],
)

=== VM インターフェースの管理

仮想マシンの詳細画面の「Interfaces」タブから仮想 NIC を管理します。

VLAN のタグ付け（Tagged / Untagged）も設定できます。

=== IP アドレスの割り当て

VM インターフェースに IP アドレスを割り当てます。
割り当て方法は物理デバイスと同様です。

== テナント（Tenant）管理

テナント機能を使うことで、VM やネットワークリソースを
組織・部署・顧客単位で管理できます。

=== テナントグループの作成

Organization > Tenant Groups から作成します。

例：
```
Tenant Group: Business Units
  Tenant: Sales
  Tenant: Engineering
  Tenant: Operations
```

=== テナントの割り当て

多くのオブジェクト（VM、デバイス、プレフィックス、VLAN など）に
テナントを割り当てることができます。

テナントフィルタを使うと、特定テナントのリソースのみを一覧表示できます。

== 仮想化管理の活用例

=== クラウド環境との併用

NetBox は物理環境だけでなく、クラウド環境の論理リソースも管理できます：

- AWS VPC → Prefix + VRF
- EC2 インスタンス → Virtual Machine
- Security Group → Tag + カスタムフィールド
- ELB → IP Address（VIP ロール）

=== Ansible / Terraform との連携

NetBox の API を使って、Ansible のインベントリソースや
Terraform のデータソースとして活用できます。

```python
# Ansible dynamic inventory の例（netbox_inventory プラグイン）
# inventory/netbox.yml
plugin: netbox.netbox.nb_inventory
api_endpoint: http://netbox.example.com
token: your-api-token
group_by:
  - site
  - role
  - platform
```
