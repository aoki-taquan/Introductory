= 実践的なトポロジ

== Leaf-Spine トポロジ

データセンターで一般的な Leaf-Spine 構成の例です：

```yaml
name: leaf-spine

topology:
  kinds:
    nokia_srlinux:
      image: ghcr.io/nokia/srlinux:24.10

  nodes:
    spine1:
      kind: nokia_srlinux
    spine2:
      kind: nokia_srlinux
    leaf1:
      kind: nokia_srlinux
    leaf2:
      kind: nokia_srlinux
    leaf3:
      kind: nokia_srlinux

  links:
    # Spine1 - Leaf 接続
    - endpoints: ["spine1:e1-1", "leaf1:e1-49"]
    - endpoints: ["spine1:e1-2", "leaf2:e1-49"]
    - endpoints: ["spine1:e1-3", "leaf3:e1-49"]
    # Spine2 - Leaf 接続
    - endpoints: ["spine2:e1-1", "leaf1:e1-50"]
    - endpoints: ["spine2:e1-2", "leaf2:e1-50"]
    - endpoints: ["spine2:e1-3", "leaf3:e1-50"]
```

== ISP ネットワーク構成

BGP ピアリングを含む ISP 風のトポロジ例：

```yaml
name: isp-network

topology:
  kinds:
    nokia_srlinux:
      image: ghcr.io/nokia/srlinux:24.10

  nodes:
    core1:
      kind: nokia_srlinux
      startup-config: configs/core1.json
    core2:
      kind: nokia_srlinux
      startup-config: configs/core2.json
    edge1:
      kind: nokia_srlinux
      startup-config: configs/edge1.json
    edge2:
      kind: nokia_srlinux
      startup-config: configs/edge2.json
    client:
      kind: linux
      image: alpine:latest

  links:
    - endpoints: ["core1:e1-1", "core2:e1-1"]
    - endpoints: ["core1:e1-2", "edge1:e1-1"]
    - endpoints: ["core2:e1-2", "edge2:e1-1"]
    - endpoints: ["edge1:e1-2", "client:eth1"]
```

== テレメトリスタック統合

gNMI テレメトリと Grafana を組み合わせた監視環境の例：

```yaml
name: telemetry-lab

topology:
  nodes:
    srl1:
      kind: nokia_srlinux
      image: ghcr.io/nokia/srlinux:24.10
    srl2:
      kind: nokia_srlinux
      image: ghcr.io/nokia/srlinux:24.10

    gnmic:
      kind: linux
      image: ghcr.io/openconfig/gnmic:latest
      binds:
        - gnmic-config.yml:/app/gnmic.yml:ro
      env:
        GNMIC_API: ":7890"

    prometheus:
      kind: linux
      image: prom/prometheus:latest
      binds:
        - prometheus.yml:/etc/prometheus/prometheus.yml:ro
      ports:
        - "9090:9090"

    grafana:
      kind: linux
      image: grafana/grafana:latest
      ports:
        - "3000:3000"

  links:
    - endpoints: ["srl1:e1-1", "srl2:e1-1"]
```

== トラフィックジェネレータの統合

ixia-c（Keysight の OTG 準拠トラフィックジェネレータ）との統合例：

```yaml
name: traffic-test

topology:
  nodes:
    srl:
      kind: nokia_srlinux
      image: ghcr.io/nokia/srlinux:24.10
    ixia:
      kind: keysight_ixia-c-one
      image: ghcr.io/open-traffic-generator/ixia-c-one:latest

  links:
    - endpoints: ["ixia:eth1", "srl:e1-1"]
    - endpoints: ["ixia:eth2", "srl:e1-2"]
```

== node-filter によるノードの部分デプロイ

大規模トポロジの一部だけをデプロイしたい場合に便利です：

```bash
sudo containerlab deploy --node-filter "spine1,leaf1,leaf2"
```

テスト対象のノードだけを起動することで、リソースを節約できます。
