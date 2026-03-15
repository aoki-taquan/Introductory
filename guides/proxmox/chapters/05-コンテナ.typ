= コンテナ（LXC）

== LXC コンテナとは

LXC（Linux Containers）は、Linux カーネルの機能（namespaces、cgroups）を利用した
OS レベルの仮想化技術です。仮想マシンと比較して以下の利点があります：

- *軽量*：カーネルを共有するためオーバーヘッドが少ない
- *高速起動*：数秒で起動
- *低リソース消費*：メモリ・CPU の使用効率が良い
- *ほぼネイティブな性能*：ハードウェアエミュレーションが不要

一方で以下の制約があります：

- Linux カーネルを共有するため、Linux OS のみ動作可能
- カーネルモジュールのロードなど、一部の操作が制限される
- Windows や BSD は動作不可

== コンテナの作成

=== Web UI から作成

+ 右上の「Create CT」ボタンをクリック
+ 各タブで設定を行う：

*General*
- *Node*：コンテナを配置するノード
- *CT ID*：一意の番号
- *Hostname*：ホスト名
- *Password*：root パスワード
- *SSH Public Key*：SSH 公開鍵（任意）

*Template*
- ダウンロード済みのテンプレートを選択

*Root Disk*
- *Storage*：ディスクの保存先
- *Disk size*：ルートディスクのサイズ（GiB）

*CPU*
- *Cores*：割り当てるコア数

*Memory*
- *Memory (MiB)*：メモリ量
- *Swap (MiB)*：スワップ量

*Network*
- *Bridge*：`vmbr0`
- *IPv4/IPv6*：DHCP または固定 IP

*DNS*
- *DNS domain*：ドメイン名
- *DNS servers*：DNS サーバー

=== コマンドラインから作成

```bash
# コンテナの作成
pct create 200 local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst \
  --hostname my-container \
  --memory 1024 \
  --swap 512 \
  --cores 2 \
  --rootfs local-lvm:8 \
  --net0 name=eth0,bridge=vmbr0,ip=dhcp \
  --password

# コンテナの起動
pct start 200
```

== コンテナの管理

=== 基本操作

```bash
# コンテナ一覧
pct list

# コンテナの起動・停止
pct start <ctid>
pct stop <ctid>
pct shutdown <ctid>

# コンテナに入る
pct enter <ctid>

# コンテナ内でコマンド実行
pct exec <ctid> -- apt update
```

=== リソースの変更

コンテナはホットプラグに対応しており、稼働中にリソースを変更できます。

```bash
# メモリの変更
pct set <ctid> --memory 2048

# CPU コア数の変更
pct set <ctid> --cores 4

# ディスクのリサイズ
pct resize <ctid> rootfs +5G
```

== 特権コンテナと非特権コンテナ

=== 非特権コンテナ（推奨）

デフォルトの設定です。UID/GID がマッピングされ、ホストとは異なるユーザー空間で動作します。
セキュリティが高く、通常はこちらを使用します。

=== 特権コンテナ

コンテナ内の root がホストの root と同じ権限を持ちます。
特定のアプリケーション（NFS サーバーなど）で必要な場合にのみ使用します。

```bash
# 特権コンテナの作成
pct create 201 local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst \
  --unprivileged 0 \
  --hostname privileged-ct \
  --memory 1024 \
  --rootfs local-lvm:8 \
  --net0 name=eth0,bridge=vmbr0,ip=dhcp
```

== マウントポイント

ホストのディレクトリやストレージをコンテナ内にマウントできます。

```bash
# バインドマウント（ホストのディレクトリを共有）
pct set <ctid> --mp0 /host/path,mp=/container/path

# ストレージからの追加ディスク
pct set <ctid> --mp0 local-lvm:10,mp=/data
```

== コンテナのバックアップと復元

```bash
# バックアップ
vzdump <ctid> --storage local --compress zstd

# 復元
pct restore <新ctid> /var/lib/vz/dump/vzdump-lxc-<ctid>-*.tar.zst
```
