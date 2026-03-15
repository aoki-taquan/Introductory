= CLI リファレンス

== 基本コマンド

Containerlab のコマンドは直感的で、ラボのライフサイクル管理に必要な操作を網羅しています。

=== deploy（デプロイ）

ラボを起動します：

```bash
sudo containerlab deploy                         # 自動検出
sudo containerlab deploy --topo lab.clab.yml     # ファイル指定
sudo containerlab deploy --reconfigure           # 既存ラボを再構成
```

主なフラグ：

#table(
  columns: (auto, 1fr),
  align: (left, left),
  table.header([*フラグ*], [*説明*]),
  [`--topo`, `-t`], [トポロジファイルのパス],
  [`--reconfigure`], [既存のラボを再構成],
  [`--max-workers`], [並列起動するノード数],
  [`--export-template`], [トポロジデータのエクスポートテンプレート],
  [`--node-filter`], [特定のノードのみデプロイ],
)

=== destroy（破棄）

ラボを停止し削除します：

```bash
sudo containerlab destroy                         # 自動検出
sudo containerlab destroy --topo lab.clab.yml    # ファイル指定
sudo containerlab destroy --cleanup               # ラボディレクトリも削除
sudo containerlab destroy --all                   # すべてのラボを破棄
```

=== inspect（検査）

ラボの状態を確認します：

```bash
sudo containerlab inspect                        # 現在のラボ
sudo containerlab inspect --all                  # すべてのラボ
sudo containerlab inspect --format json          # JSON 形式で出力
```

出力には以下の情報が含まれます：
- ノード名
- コンテナ ID
- イメージ
- Kind
- 状態（running / stopped）
- IPv4 / IPv6 アドレス

=== save（保存）

実行中のノードの設定を保存します：

```bash
sudo containerlab save
sudo containerlab save --topo lab.clab.yml
```

NOS がサポートしている場合、ノードの現在のコンフィグをファイルに保存します。

=== graph（グラフ）

トポロジの可視化を行います：

```bash
sudo containerlab graph
sudo containerlab graph --topo lab.clab.yml
```

デフォルトで Web ブラウザでインタラクティブなトポロジ図を表示します。

=== exec（コマンド実行）

すべてのノードまたは特定のノードでコマンドを実行します：

```bash
sudo containerlab exec --topo lab.clab.yml \
  --label clab-node-name=srl1 \
  --cmd "ip addr show"
```

=== generate（生成）

設定ファイルの自動生成を行います：

```bash
sudo containerlab generate --name my-lab \
  --kind nokia_srlinux \
  --nodes 4 \
  --deploy
```

== 省略形

Containerlab は短縮コマンドにも対応しています：

```bash
clab deploy    # containerlab deploy の省略形
clab destroy   # containerlab destroy の省略形
clab inspect   # containerlab inspect の省略形
```

== グローバルフラグ

すべてのコマンドで使用可能なフラグです：

#table(
  columns: (auto, 1fr),
  align: (left, left),
  table.header([*フラグ*], [*説明*]),
  [`--runtime`], [コンテナランタイムの指定（docker / podman）],
  [`--debug`], [デバッグログを出力],
  [`--log-level`], [ログレベルの指定],
  [`--timeout`], [操作のタイムアウト時間],
)
