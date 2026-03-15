= トポロジ定義の詳細

== トポロジファイルの全体構造

```yaml
name: <ラボ名>
prefix: <プレフィックス>
topology:
  defaults: {}
  kinds: {}
  nodes: {}
  links: []
```

== プレフィックスのカスタマイズ

コンテナ名のプレフィックスを変更できます：

#table(
  columns: (auto, auto, 1fr),
  align: (left, left, left),
  table.header([*設定*], [*例（ラボ名: lab, ノード: r1）*], [*説明*]),
  [未指定], [`clab-lab-r1`], [デフォルト],
  [`prefix: mylab`], [`mylab-lab-r1`], [カスタムプレフィックス],
  [`prefix: __lab-name`], [`lab-r1`], [プレフィックスなし],
  [`prefix: ""`], [`r1`], [ラボ名もプレフィックスも省略],
)

== ノードの詳細設定

=== startup-config

ノードの起動設定を外部ファイルから読み込めます：

```yaml
nodes:
  srl:
    kind: nokia_srlinux
    image: ghcr.io/nokia/srlinux:24.10
    startup-config: configs/srl-config.json
```

=== binds（ボリュームマウント）

ホストのファイルやディレクトリをコンテナにマウントします：

```yaml
nodes:
  linux1:
    kind: linux
    image: alpine:latest
    binds:
      - /host/path:/container/path:ro
      - configs/test.sh:/test.sh
```

=== ports（ポートマッピング）

ホストからコンテナのポートにアクセスするための設定です：

```yaml
nodes:
  srl:
    kind: nokia_srlinux
    image: ghcr.io/nokia/srlinux:24.10
    ports:
      - "8080:80"
      - "9443:443"
```

=== exec（起動後コマンド）

ノード起動後に自動実行するコマンドを指定します：

```yaml
nodes:
  linux1:
    kind: linux
    image: alpine:latest
    exec:
      - ip addr add 10.0.0.1/24 dev eth1
      - ip route add 10.0.1.0/24 via 10.0.0.254
```

== リンクの詳細

=== 簡略フォーマット

最も一般的な形式です：

```yaml
links:
  - endpoints: ["srl1:e1-1", "srl2:e1-1"]
```

=== 拡張フォーマット

MAC アドレスや MTU を指定する場合に使用します：

```yaml
links:
  - type: veth
    endpoints:
      - node: srl1
        interface: e1-1
        mac: "aa:bb:cc:dd:ee:01"
      - node: srl2
        interface: e1-1
        mac: "aa:bb:cc:dd:ee:02"
    mtu: 9000
```

=== 特殊なリンクタイプ

#table(
  columns: (auto, 1fr),
  align: (left, left),
  table.header([*タイプ*], [*説明*]),
  [`veth`], [デフォルト。仮想イーサネットペア],
  [`mgmt-net`], [管理ネットワークブリッジへの接続],
  [`macvlan`], [ホストインターフェース上の MACVlan],
  [`host`], [コンテナとホスト間の veth ペア],
  [`vxlan`], [VXLAN トンネルインターフェース],
)

== インターフェース名のエイリアス

各 NOS のインターフェース命名規則に対応したエイリアスが使えます：

#table(
  columns: (auto, auto),
  align: (left, left),
  table.header([*NOS*], [*エイリアス例*]),
  [SR Linux], [`ethernet-1/1` → `e1-1`],
  [Arista cEOS], [`Ethernet1/1` → `eth1`],
  [Linux], [`eth1`（そのまま）],
)

== マジック変数

トポロジファイル内で使用できる特殊変数です：

- `__clabLabName__`：ラボ名
- `__clabNodeName__`：ノード名
- `__clabNodeDir__`：ノードディレクトリのパス
- `__clabDir__`：ラボディレクトリのパス

== 環境変数の参照

トポロジファイル内で環境変数を参照できます：

```yaml
nodes:
  srl:
    kind: nokia_srlinux
    image: ${SRL_IMAGE:-ghcr.io/nokia/srlinux:24.10}
```

`${VAR:-default}` 構文でデフォルト値を指定できます。
