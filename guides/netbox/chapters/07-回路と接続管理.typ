= 回路と接続管理

== ケーブル管理

NetBox では物理的なケーブル接続を管理できます。

=== ケーブルの作成

デバイスのインターフェース詳細画面から「Connect」ボタンで接続を作成します。

=== ケーブルのフィールド

#table(
  columns: (auto, auto),
  inset: 8pt,
  align: left,
  table.header(
    [*フィールド*], [*説明*],
  ),
  [Side A], [接続元（デバイス・インターフェース）],
  [Side B], [接続先（デバイス・インターフェース）],
  [Type], [ケーブル種別（CAT6、CAT6A、Fiber SMF など）],
  [Status], [Connected / Planned / Decommissioning],
  [Label], [ケーブルラベル・識別番号],
  [Color], [ケーブルの色],
  [Length], [長さ（m / ft など）],
  [Description], [説明],
)

=== 接続可能なオブジェクト

ケーブルで接続できるのはインターフェースだけでなく、以下も対象です：

- Console Port / Console Server Port
- Power Port / Power Outlet
- Front Port / Rear Port（パッチパネル）

=== パッチパネルの管理

パッチパネルはデバイスタイプとして登録し、
Front Port と Rear Port をテンプレートで定義します。

ケーブルパスの追跡（Cable Trace）機能で、
パッチパネルを経由した接続経路を視覚的に確認できます。

== Wireless（ワイヤレス LAN）

無線 LAN インフラを管理します。

=== Wireless LAN Group

ワイヤレス LAN グループを作成します。

例：`Office-WiFi`、`Guest-WiFi`

=== Wireless LAN

#table(
  columns: (auto, auto),
  inset: 8pt,
  align: left,
  table.header(
    [*フィールド*], [*説明*],
  ),
  [SSID], [ネットワーク名],
  [Group], [ワイヤレス LAN グループ],
  [Status], [Active / Reserved / Disabled],
  [Auth Type], [認証方式（Open、WEP、WPA Personal など）],
  [Auth Cipher], [暗号化方式（AES、TKIP）],
  [Auth PSK], [事前共有鍵],
  [VLAN], [関連 VLAN],
)

== 回路（Circuits）管理

WAN 回線や通信事業者との契約情報を管理します。

=== Provider（プロバイダー）

通信事業者・ISP を登録します。

Circuits > Providers から作成します。

例：NTT、KDDI、SoftBank、IIJ、AWS Direct Connect

=== Provider Network

プロバイダーが管理するネットワーク（クラウド側など）を登録します。

=== Circuit Type（回線タイプ）

回線の種類を定義します。

Circuits > Circuit Types から作成します。

例：Internet（インターネット回線）、MPLS、Dark Fiber、SD-WAN

=== Circuit（回線）

実際の WAN 回線を管理します。

#table(
  columns: (auto, auto),
  inset: 8pt,
  align: left,
  table.header(
    [*フィールド*], [*説明*],
  ),
  [CID], [回線 ID・契約番号],
  [Provider], [通信事業者],
  [Type], [回線タイプ],
  [Status], [Active / Planned / Provisioning など],
  [Tenant], [利用テナント],
  [Commit Rate（Kbps）], [契約帯域],
  [Description], [説明],
)

=== Circuit Termination（回線終端）

回線の接続先（自拠点のインターフェース）を登録します。

回線は Side A・Side Z の 2 つの終端を持ちます。

例：
```
Circuit: CID-001234
  Termination A: Tokyo-DC / core-rt-01 / GigabitEthernet0/0
  Termination Z: Provider Network（ISP 側）
```

== 電源管理

=== Power Panel（電源パネル）

データセンターの電源パネル（分電盤）を管理します。

Devices > Power Panels から作成します。

=== Power Feed（電源フィード）

電源パネルから各ラックへの電源供給を管理します。

#table(
  columns: (auto, auto),
  inset: 8pt,
  align: left,
  table.header(
    [*フィールド*], [*説明*],
  ),
  [Name], [フィード名（例：Feed-A、Feed-B）],
  [Power Panel], [電源パネル],
  [Rack], [接続ラック],
  [Status], [Active / Planned など],
  [Type], [Primary / Redundant],
  [Supply], [AC / DC],
  [Phase], [Single-phase / Three-phase],
  [Voltage], [電圧（例：100、200）],
  [Amperage], [電流（A）],
)

デバイスの Power Port を Power Feed に接続することで、
電源経路を追跡できます。
