= クイックスタート

== 最初のラボを作る

実際にラボを構築してみましょう。Nokia SR Linux 2 台を接続するシンプルなトポロジを作成します。

=== トポロジファイルの作成

作業ディレクトリを作成し、トポロジファイルを記述します：

```bash
mkdir ~/first-lab && cd ~/first-lab
```

以下の内容で `first-lab.clab.yml` を作成します：

```yaml
name: first-lab

topology:
  nodes:
    srl1:
      kind: nokia_srlinux
      image: ghcr.io/nokia/srlinux:24.10
    srl2:
      kind: nokia_srlinux
      image: ghcr.io/nokia/srlinux:24.10

  links:
    - endpoints: ["srl1:e1-1", "srl2:e1-1"]
```

=== ラボのデプロイ

```bash
sudo containerlab deploy
```

Containerlab はカレントディレクトリ内の `*.clab.yml` ファイルを自動検出します。
ファイルを明示的に指定する場合は `--topo` フラグを使用します：

```bash
sudo containerlab deploy --topo first-lab.clab.yml
```

デプロイが完了すると、ノード情報の一覧が表示されます。

=== ラボの確認

デプロイされたラボの状態を確認します：

```bash
sudo containerlab inspect
```

すべてのラボを一覧表示する場合：

```bash
sudo containerlab inspect --all
```

== ノードへの接続

=== SSH でアクセス

SR Linux のデフォルト認証情報は `admin` / `NokiaSrl1!` です：

```bash
ssh admin@clab-first-lab-srl1
```

=== Docker exec でアクセス

```bash
docker exec -it clab-first-lab-srl1 sr_cli
```

== 疎通確認

srl1 から srl2 へインターフェースを設定し、ping で疎通を確認してみましょう。

srl1 の CLI で：

```
set / interface ethernet-1/1 admin-state enable
set / interface ethernet-1/1 subinterface 0 \
    ipv4 admin-state enable \
    address 192.168.1.1/24
commit now
```

srl2 の CLI で：

```
set / interface ethernet-1/1 admin-state enable
set / interface ethernet-1/1 subinterface 0 \
    ipv4 admin-state enable \
    address 192.168.1.2/24
commit now
```

srl1 から ping：

```
ping 192.168.1.2 network-instance default
```

== ラボの破棄

ラボが不要になったら破棄します：

```bash
sudo containerlab destroy
```

特定のトポロジファイルを指定する場合：

```bash
sudo containerlab destroy --topo first-lab.clab.yml
```

`--cleanup` フラグでラボディレクトリも削除できます：

```bash
sudo containerlab destroy --cleanup
```
