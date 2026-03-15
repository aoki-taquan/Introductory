= 設定管理

== startup-config

ノードにあらかじめ設定を投入した状態でラボを起動できます。

=== ローカルファイルから読み込み

```yaml
name: config-lab

topology:
  nodes:
    srl:
      kind: nokia_srlinux
      image: ghcr.io/nokia/srlinux:24.10
      startup-config: configs/srl-config.json
    ceos:
      kind: arista_ceos
      image: ceos:4.32.0F
      startup-config: configs/ceos-config.cfg
```

設定ファイルの形式は NOS ごとに異なります：
- *SR Linux*：JSON 形式
- *Arista cEOS*：EOS CLI 形式
- *Juniper cRPD*：Junos CLI 形式

=== 設定例（SR Linux）

```json
{
  "interface": [
    {
      "name": "ethernet-1/1",
      "admin-state": "enable",
      "subinterface": [
        {
          "index": 0,
          "ipv4": {
            "admin-state": "enable",
            "address": [
              {
                "ip-prefix": "192.168.1.1/24"
              }
            ]
          }
        }
      ]
    }
  ]
}
```

== 設定の保存

実行中のラボの設定を保存できます：

```bash
sudo containerlab save
```

保存された設定はラボディレクトリ内の各ノードディレクトリに格納されます：

```
clab-<lab-name>/
  <node-name>/
    config/
      ...  # NOS 固有の設定ファイル
```

== ラボディレクトリ

ラボをデプロイすると、トポロジファイルと同じ場所にラボディレクトリが作成されます：

```
clab-<lab-name>/
  topology-data.json    # トポロジメタデータ
  ansible-inventory.yml # Ansible インベントリ
  <node-name>/          # 各ノードのディレクトリ
    config/             # 設定ファイル
    tls/                # TLS 証明書（対応ノードのみ）
```

== Ansible インベントリの自動生成

Containerlab はデプロイ時に Ansible インベントリファイルを自動生成します：

```bash
ansible-playbook -i clab-my-lab/ansible-inventory.yml playbook.yml
```

生成されるインベントリの構造：

```yaml
all:
  children:
    nokia_srlinux:
      hosts:
        clab-my-lab-srl1:
          ansible_host: <management-ip>
    arista_ceos:
      hosts:
        clab-my-lab-ceos1:
          ansible_host: <management-ip>
```

== 設定のバージョン管理

startup-config ファイルを Git で管理することで、ラボの設定変更を追跡できます：

```
my-lab/
  lab.clab.yml
  configs/
    srl1.json
    srl2.json
    ceos1.cfg
  README.md
```

この構成により、トポロジと設定を一元的にバージョン管理できます。
