= 基本概念

== トポロジファイル

Containerlab の中核となるのがトポロジ定義ファイル（`.clab.yml`）です。
YAML 形式でネットワークラボの構成を宣言的に記述します。

基本的な構造は以下の通りです：

```yaml
name: my-lab

topology:
  nodes:
    router1:
      kind: nokia_srlinux
      image: ghcr.io/nokia/srlinux:24.10
    router2:
      kind: nokia_srlinux
      image: ghcr.io/nokia/srlinux:24.10

  links:
    - endpoints: ["router1:e1-1", "router2:e1-1"]
```

== ノード（nodes）

ノードはラボ内の各ネットワーク機器を表します。ノードには以下のプロパティがあります：

- `kind`：ノードの種類（NOS タイプ）
- `image`：使用するコンテナイメージ
- `type`：ハードウェアモデル（kind に応じて）
- `startup-config`：起動時に適用する設定ファイル
- `binds`：ホストとコンテナ間のボリュームマウント
- `ports`：ポートマッピング
- `env`：環境変数
- `labels`：メタデータラベル
- `exec`：起動後に実行するコマンド

```yaml
nodes:
  srl:
    kind: nokia_srlinux
    image: ghcr.io/nokia/srlinux:24.10
    startup-config: configs/srl.cfg
    ports:
      - "8080:80"
    env:
      MY_VAR: "value"
```

== リンク（links）

リンクはノード間の接続を定義します。基本フォーマットはエンドポイントのペアです：

```yaml
links:
  - endpoints: ["node1:e1-1", "node2:e1-1"]
```

IP アドレスを直接割り当てることもできます：

```yaml
links:
  - endpoints: ["node1:e1-1", "node2:e1-1"]
    ipv4: ["192.168.1.1/24", "192.168.1.2/24"]
```

== Kind（ノード種別）

`kind` はノードの NOS タイプを指定します。主要な kind は以下の通りです：

#table(
  columns: (auto, auto, 1fr),
  align: (left, left, left),
  table.header([*ベンダー*], [*kind*], [*説明*]),
  [Nokia], [`nokia_srlinux`], [SR Linux コンテナ],
  [Arista], [`arista_ceos`], [cEOS コンテナ],
  [Cisco], [`cisco_xrd`], [XRd コンテナ],
  [Cisco], [`cisco_iol`], [IOL コンテナ],
  [Juniper], [`juniper_crpd`], [cRPD コンテナ],
  [Cumulus], [`cumulus_cvx`], [Cumulus VX],
  [SONiC], [`sonic-vs`], [SONiC 仮想スイッチ],
  [Linux], [`linux`], [汎用 Linux コンテナ],
)

== コンテナの命名規則

Containerlab はコンテナに以下の命名規則を適用します：

```
clab-<lab-name>-<node-name>
```

例えば、ラボ名が `my-lab`、ノード名が `router1` の場合：

```
clab-my-lab-router1
```

この名前で `docker exec` や SSH アクセスが可能です。

== 管理ネットワーク

Containerlab はデフォルトで管理ネットワーク（`clab` ブリッジ）を作成し、
すべてのノードに管理インターフェースを接続します。
これにより、ホストから各ノードへ SSH でアクセスできます。

== 設定の継承

トポロジファイルでは設定の継承がサポートされています。
優先順位は以下の通りです（高い順）：

+ ノード固有の設定
+ グループの設定
+ Kind の設定
+ デフォルトの設定

```yaml
topology:
  defaults:
    env:
      COMMON_VAR: "shared"

  kinds:
    nokia_srlinux:
      image: ghcr.io/nokia/srlinux:24.10

  nodes:
    srl1:
      kind: nokia_srlinux
    srl2:
      kind: nokia_srlinux
```

この例では `srl1` と `srl2` の両方が同じイメージを使用します。
