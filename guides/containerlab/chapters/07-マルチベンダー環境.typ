= マルチベンダー環境

== 複数ベンダーの組み合わせ

Containerlab の大きな強みは、異なるベンダーの NOS を一つのラボ内で組み合わせられることです。

=== マルチベンダートポロジの例

Nokia SR Linux と Arista cEOS を接続する例：

```yaml
name: multivendor-lab

topology:
  nodes:
    srl:
      kind: nokia_srlinux
      image: ghcr.io/nokia/srlinux:24.10
    ceos:
      kind: arista_ceos
      image: ceos:4.32.0F

  links:
    - endpoints: ["srl:e1-1", "ceos:eth1"]
```

== コンテナベースの NOS

=== Nokia SR Linux

オープンで無料のコンテナ NOS です。Containerlab で最もよく使われます：

```yaml
nodes:
  srl:
    kind: nokia_srlinux
    image: ghcr.io/nokia/srlinux:24.10
    type: ixrd3l  # ハードウェアタイプ
```

デフォルト認証情報：`admin` / `NokiaSrl1!`

=== Arista cEOS

Arista の EOS をコンテナ化したものです。arista.com からイメージを取得する必要があります：

```yaml
nodes:
  ceos:
    kind: arista_ceos
    image: ceos:4.32.0F
```

デフォルト認証情報：`admin`（パスワードなし）

=== Juniper cRPD

Juniper のルーティングプロトコルデーモンをコンテナ化したものです：

```yaml
nodes:
  crpd:
    kind: juniper_crpd
    image: crpd:23.4R1.10
```

=== Cisco XRd

Cisco IOS XR のコンテナ版です：

```yaml
nodes:
  xrd:
    kind: cisco_xrd
    image: ios-xr/xrd-control-plane:24.1.1
```

== Linux コンテナ

汎用の Linux コンテナをホストやクライアントとして利用できます：

```yaml
nodes:
  client1:
    kind: linux
    image: alpine:latest
    exec:
      - ip addr add 10.0.0.10/24 dev eth1
      - ip route add default via 10.0.0.1

  server1:
    kind: linux
    image: nginx:latest
    ports:
      - "8080:80"
```

== VM ベースの NOS（vrnetlab）

コンテナ化されていない NOS は vrnetlab 統合により VM として実行できます。
主な対応 NOS は以下の通りです：

#table(
  columns: (auto, auto),
  align: (left, left),
  table.header([*NOS*], [*kind*]),
  [Juniper vMX], [`juniper_vmx`],
  [Juniper vSRX], [`juniper_vsrx`],
  [Cisco CSR1000v], [`cisco_csr1000v`],
  [Cisco Nexus 9000v], [`cisco_n9kv`],
  [Aruba AOS-CX], [`aruba_aoscx`],
  [Palo Alto PAN-OS], [`paloalto_panos`],
)

vrnetlab を使用するには、ベンダーから NOS イメージを取得し、
vrnetlab のビルドスクリプトでコンテナイメージを作成する必要があります。

== コンテナイメージの取得

各ベンダーのイメージ取得方法は異なります：

- *Nokia SR Linux*：GitHub Container Registry から無料で取得可能（`ghcr.io/nokia/srlinux`）
- *Arista cEOS*：arista.com でアカウント登録後にダウンロード
- *Juniper cRPD*：Juniper のサイトから取得（評価版あり）
- *Cisco XRd*：Cisco のソフトウェアダウンロードから取得
