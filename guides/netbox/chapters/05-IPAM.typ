= IPAM（IP アドレス管理）

IPAM（IP Address Management）は NetBox の中核機能です。
IP アドレス空間を階層的・可視的に管理します。

== IPAM の構造

```
RIR（地域インターネットレジストリ）
  └── Aggregate（割り当てブロック）
        └── Prefix（プレフィックス）
              └── IP Range（IP 範囲）
              └── IP Address（個別 IP）
```

== RIR（Regional Internet Registry）

IPAM > RIRs からインターネットレジストリを登録します。

代表的な RIR：
- APNIC（アジア太平洋）
- ARIN（北米）
- RIPE NCC（欧州・中東）
- LACNIC（中南米）
- AFRINIC（アフリカ）
- RFC 1918（プライベートアドレス）

== Aggregate（集約プレフィックス）

自組織に割り当てられた最上位のアドレスブロックを登録します。

例：
- `10.0.0.0/8`（プライベート）
- `192.168.0.0/16`（プライベート）
- `203.0.113.0/24`（インターネットルーティング可能）

== VRF（Virtual Routing and Forwarding）

VRF を使うことで、同じ IP アドレス空間を複数テナントや用途で分離管理できます。

=== VRF の作成

IPAM > VRFs から作成します。

#table(
  columns: (auto, auto),
  inset: 8pt,
  align: left,
  table.header(
    [*フィールド*], [*説明*],
  ),
  [Name], [VRF 名（例：Production、Management）],
  [RD], [Route Distinguisher（例：65001:100）],
  [Enforce Unique], [重複 IP の登録を禁止するか],
  [Description], [説明],
)

VRF の「Global」は VRF なし（グローバルルーティングテーブル）を意味します。

== Prefix（プレフィックス）

プレフィックスはサブネットやアドレスブロックを管理します。

=== 主要フィールド

#table(
  columns: (auto, auto),
  inset: 8pt,
  align: left,
  table.header(
    [*フィールド*], [*説明*],
  ),
  [Prefix], [CIDR 表記（例：192.168.1.0/24）],
  [VRF], [所属 VRF],
  [Status], [Active / Reserved / Deprecated / Container],
  [Role], [用途（例：Infrastructure、Loopback、Management）],
  [Site], [関連するサイト],
  [VLAN], [関連する VLAN],
  [Is a pool], [IP プールとして扱う（DHCP 範囲など）],
  [Mark Utilized], [すべての IP が使用済みとみなすか],
  [Description], [説明],
)

=== ステータスの意味

- *Active*：現在使用中
- *Reserved*：予約済み（将来の使用のために確保）
- *Deprecated*：廃止予定
- *Container*：子プレフィックスを含む集約コンテナ

=== プレフィックスの可視化

プレフィックス一覧では使用状況がプログレスバーで表示されます。
詳細画面では子プレフィックスと IP アドレスの一覧が確認できます。

=== 利用可能な IP の検索

プレフィックス詳細画面の「Available IPs」タブで、
未割り当ての IP アドレスを一覧表示し、すぐに割り当てることができます。

== VLAN

=== VLAN グループ

サイトやロケーション単位でVLAN グループを作成し、その中で VLAN を管理します。

IPAM > VLAN Groups から作成します。

=== VLAN の管理

IPAM > VLANs から VLAN を作成します。

#table(
  columns: (auto, auto),
  inset: 8pt,
  align: left,
  table.header(
    [*フィールド*], [*説明*],
  ),
  [VID], [VLAN ID（1〜4094）],
  [Name], [VLAN 名（例：Management、Production）],
  [Site], [所属サイト],
  [Group], [VLAN グループ],
  [Status], [Active / Reserved / Deprecated],
  [Role], [用途（例：User Access、Transit）],
  [Tenant], [所属テナント（任意）],
)

== IP Address（IP アドレス）

個々の IP アドレスを管理します。

=== 主要フィールド

#table(
  columns: (auto, auto),
  inset: 8pt,
  align: left,
  table.header(
    [*フィールド*], [*説明*],
  ),
  [Address], [IP/プレフィックス長（例：192.168.1.1/24）],
  [VRF], [所属 VRF],
  [Status], [Active / Reserved / DHCP / SLAAC など],
  [Role], [Loopback / Secondary / Anycast / VIP など],
  [DNS Name], [対応する DNS 名],
  [Assigned Object], [割り当て先（インターフェース）],
  [NAT（Inside）], [NAT 変換前のアドレス],
  [Description], [説明],
)

=== インターフェースへの割り当て

IP アドレスを機器のインターフェースに割り当てることで、
どの機器のどのインターフェースがその IP を持っているかを管理できます。

```
Assigned Object: core-sw-01 > GigabitEthernet0/0
```

割り当てた IP は、デバイスの「Primary IP」として設定することもできます。

== IP Range（IP 範囲）

連続した IP アドレスの範囲を管理します。
DHCP スコープや特定用途の IP 範囲の管理に便利です。

#table(
  columns: (auto, auto),
  inset: 8pt,
  align: left,
  table.header(
    [*フィールド*], [*説明*],
  ),
  [Start Address], [開始 IP（例：192.168.1.100/24）],
  [End Address], [終了 IP（例：192.168.1.200/24）],
  [VRF], [所属 VRF],
  [Status], [Active / Reserved など],
  [Role], [用途（例：DHCP Pool）],
  [Size], [範囲内の IP 数（自動計算）],
)

== IPAM のベストプラクティス

=== プレフィックスの役割定義

用途別のロールを作成し、プレフィックスに割り当てます：

- `Infrastructure`：ネットワーク機器間の接続
- `Loopback`：ルーターの Loopback アドレス
- `Management`：管理用アドレス帯
- `Server`：サーバーセグメント
- `Client`：クライアントセグメント
- `Transit`：WAN 回線の接続先

=== 階層的なプレフィックス設計例

```
10.0.0.0/8          [Container] 全プライベート
  10.0.0.0/16       [Container] 東京DC
    10.0.1.0/24     [Active]    東京DC サーバーセグメント
    10.0.2.0/24     [Active]    東京DC 管理セグメント
  10.1.0.0/16       [Container] 大阪DC
    10.1.1.0/24     [Active]    大阪DC サーバーセグメント
```
