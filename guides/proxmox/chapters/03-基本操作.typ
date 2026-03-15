= 基本操作

== Web UI の構成

Proxmox VE の Web UI は以下の主要エリアで構成されています：

- *ヘッダーバー*：ユーザー情報、ドキュメントリンク、ログアウト
- *リソースツリー（左側）*：データセンター、ノード、VM、コンテナの階層表示
- *コンテンツパネル（中央）*：選択した項目の詳細情報と操作
- *タスクログ（下部）*：実行中・完了済みタスクの履歴

== ノードの管理

=== ノード情報の確認

リソースツリーでノードを選択すると、以下の情報を確認できます：

- *Summary*：CPU、メモリ、ストレージの使用状況
- *Notes*：ノードに関するメモ
- *Shell*：Web ベースのコンソール（noVNC / xterm.js）
- *System*：ネットワーク、DNS、時刻、Syslog の設定
- *Updates*：パッケージの更新状態

=== シェルアクセス

Web UI から直接シェルにアクセスする方法は 2 つあります：

+ *Web UI のシェル*：ノードを選択 → 「Shell」ボタン
+ *SSH 接続*：
  ```bash
  ssh root@<IPアドレス>
  ```

== コマンドラインツール

Proxmox VE には専用の CLI ツールが用意されています。

=== qm（仮想マシン管理）

```bash
# VM 一覧
qm list

# VM の起動
qm start <vmid>

# VM の停止
qm stop <vmid>

# VM のシャットダウン（ゲスト OS 経由）
qm shutdown <vmid>

# VM の設定確認
qm config <vmid>

# VM の作成
qm create <vmid> --name <名前> --memory 2048 --cores 2
```

=== pct（コンテナ管理）

```bash
# コンテナ一覧
pct list

# コンテナの起動
pct start <ctid>

# コンテナの停止
pct stop <ctid>

# コンテナの設定確認
pct config <ctid>

# コンテナにログイン
pct enter <ctid>
```

=== pvesm（ストレージ管理）

```bash
# ストレージ一覧
pvesm status

# ストレージの追加（NFS の例）
pvesm add nfs <ストレージ名> --server <サーバー> --export <パス>
```

=== pvesh（API シェル）

```bash
# ノード情報の取得
pvesh get /nodes

# VM 一覧の取得
pvesh get /nodes/<ノード名>/qemu

# リソースの取得
pvesh get /cluster/resources
```

== ISO イメージのアップロード

VM にインストールする OS の ISO イメージをアップロードします。

=== Web UI から

+ データセンター → ストレージ → `local` を選択
+ 「ISO Images」タブを選択
+ 「Upload」ボタンからファイルを選択
+ アップロードが完了するまで待機

=== コマンドラインから

```bash
# wget で直接ダウンロード
cd /var/lib/vz/template/iso/
wget https://example.com/os-image.iso
```

== テンプレートのダウンロード

LXC コンテナ用のテンプレートをダウンロードします。

=== Web UI から

+ ストレージ → `local` → 「CT Templates」タブ
+ 「Templates」ボタンをクリック
+ 使用したいテンプレートを選択してダウンロード

=== コマンドラインから

```bash
# テンプレート一覧の更新
pveam update

# 利用可能なテンプレートの表示
pveam available

# テンプレートのダウンロード
pveam download local debian-12-standard_12.2-1_amd64.tar.zst
```
