= DCIM（データセンターインフラ管理）

DCIM（Data Center Infrastructure Management）は、NetBox のコア機能の一つです。
物理的なネットワークインフラを階層的に管理します。

== 管理階層の概要

NetBox の DCIM は以下の階層構造で管理します：

```
Region（地域）
  └── Site Group（サイトグループ）
        └── Site（サイト）
              └── Location（ロケーション）
                    └── Rack（ラック）
                          └── Device（デバイス）
                                └── Interface / Port
```

== Region（地域）

Organization > Regions から地域を管理します。

地域は階層化できます（例：日本 > 東日本 > 東京）。

=== 作成例

```
Name: Japan
Slug: japan
```

```
Name: Tokyo
Slug: tokyo
Parent: Japan
```

== Site（サイト）

サイトはデータセンター、オフィスなどの物理的な拠点を表します。

=== 主要フィールド

#table(
  columns: (auto, auto),
  inset: 8pt,
  align: left,
  table.header(
    [*フィールド*], [*説明*],
  ),
  [Name], [サイト名（例：Tokyo-DC1）],
  [Slug], [URL 用の識別子（例：tokyo-dc1）],
  [Status], [Active / Planned / Retired など],
  [Region], [所属するリージョン],
  [Facility], [施設名・住所],
  [ASN], [BGP ASN番号],
  [Time zone], [タイムゾーン],
  [Description], [説明],
)

== Location（ロケーション）

サイト内の部屋やフロアなどの区画を表します。

例：1F サーバールーム、2F 機器室

== Rack（ラック）

物理的なラックキャビネットを管理します。

=== 主要フィールド

#table(
  columns: (auto, auto),
  inset: 8pt,
  align: left,
  table.header(
    [*フィールド*], [*説明*],
  ),
  [Name], [ラック名（例：Rack-01）],
  [Site], [設置サイト],
  [Location], [設置ロケーション（任意）],
  [Status], [Active / Planned など],
  [Role], [ラックの用途（例：Network, Server）],
  [Type], [ラックのタイプ（2-post, 4-post, Wall frame など）],
  [Width], [幅（19インチ、23インチ）],
  [U Height], [高さ（U数）],
  [Desc Units], [ユニット番号の方向（上から/下から）],
)

=== ラックビュー

ラックの詳細画面では、インタラクティブなラック図が表示されます。
各 U に配置されたデバイスが視覚的に確認できます。

== Device Type（デバイスタイプ）

デバイスタイプはメーカーとモデルの組み合わせを定義するテンプレートです。

=== メーカー（Manufacturer）の登録

Devices > Manufacturers から登録します。

例：Cisco、Juniper、Arista、HPE

=== デバイスタイプの登録

Devices > Device Types から登録します。

#table(
  columns: (auto, auto),
  inset: 8pt,
  align: left,
  table.header(
    [*フィールド*], [*説明*],
  ),
  [Manufacturer], [メーカー（例：Cisco）],
  [Model], [モデル名（例：Catalyst 9300-48P）],
  [Slug], [識別子（例：catalyst-9300-48p）],
  [U Height], [搭載 U 数（例：1）],
  [Is full depth], [全奥行き占有か否か],
  [Front Image], [前面写真（任意）],
  [Rear Image], [背面写真（任意）],
)

=== コンポーネントテンプレート

デバイスタイプにはインターフェースやポートのテンプレートを定義できます。
新しいデバイスを作成するとテンプレートが自動適用されます。

- *Interfaces*：GigabitEthernet0/0、TenGigabitEthernet1/0/1 など
- *Console Ports*：コンソールポート
- *Power Ports*：電源ポート
- *Module Bays*：モジュールベイ（スタック・ラインカード）

=== コミュニティライブラリの活用

`netbox-community/devicetype-library` リポジトリに多数のデバイスタイプが登録されています。
YAML 形式でインポートできます。

```bash
git clone https://github.com/netbox-community/devicetype-library.git
```

== Device Role（デバイスロール）

デバイスロールは機器の役割を定義します。

例：Router、Switch、Firewall、Server、PDU、Patch Panel

Devices > Device Roles から作成します。

== Device（デバイス）

実際のネットワーク機器を登録します。

=== 主要フィールド

#table(
  columns: (auto, auto),
  inset: 8pt,
  align: left,
  table.header(
    [*フィールド*], [*説明*],
  ),
  [Name], [ホスト名（例：core-sw-01）],
  [Device Role], [役割（例：Core Switch）],
  [Device Type], [機種（例：Cisco Catalyst 9300）],
  [Site], [設置サイト],
  [Rack], [設置ラック],
  [Position], [ラック内の U 位置],
  [Face], [前面/背面],
  [Status], [Active / Staged / Offline など],
  [Platform], [OS プラットフォーム（例：Cisco IOS-XE）],
  [Serial Number], [シリアル番号],
  [Asset Tag], [資産タグ],
  [Primary IPv4], [主要 IPv4 アドレス],
  [Primary IPv6], [主要 IPv6 アドレス],
)

=== インターフェースの管理

デバイス詳細画面の「Interfaces」タブから各インターフェースを管理します。

インターフェースの種別：
- Physical（物理）：1000BASE-T、10GBASE-SR など
- Virtual（仮想）：VLAN サブインターフェース、Loopback など
- LAG（Link Aggregation）：ポートチャネル、LACP

=== ケーブルの接続

インターフェースの詳細画面から「Connect」ボタンで対向機器のポートと接続を登録します。
接続情報はケーブルとして記録されます。

== Platform（プラットフォーム）

デバイスの OS・プラットフォームを定義します。

例：Cisco IOS-XE、Juniper Junos、Arista EOS、Linux

NAPALM や Nornir などの自動化ツールと連携する場合に使用します。
