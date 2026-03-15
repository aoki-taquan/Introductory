= 基本概念

== Kubernetesのアーキテクチャ

Kubernetesクラスタは、大きく分けて*コントロールプレーン*と*ワーカーノード*の2つの要素で構成されます。

=== コントロールプレーン

クラスタ全体を管理する頭脳の役割を担います。

#table(
  columns: (1fr, 2fr),
  align: (left, left),
  table.header(
    [*コンポーネント*], [*役割*],
  ),
  [kube-apiserver], [Kubernetes APIを提供するフロントエンド。kubectlからのリクエストを受け付ける],
  [etcd], [クラスタの全データを保存する分散キーバリューストア],
  [kube-scheduler], [新しいPodをどのノードに配置するか決定する],
  [kube-controller-manager], [各種コントローラー（ReplicaSet、Deploymentなど）を実行する],
)

=== ワーカーノード

実際にコンテナが動作するマシンです。

#table(
  columns: (1fr, 2fr),
  align: (left, left),
  table.header(
    [*コンポーネント*], [*役割*],
  ),
  [kubelet], [ノード上でPodの起動・管理を行うエージェント],
  [kube-proxy], [ネットワークルールを管理し、Serviceへの通信を転送する],
  [コンテナランタイム], [コンテナを実行する（containerd、CRI-Oなど）],
)

== 主要なリソース

Kubernetesでは、すべてのものが「リソース」として管理されます。以下が主要なリソースです。

=== ワークロード系リソース

- *Pod*: コンテナの最小デプロイ単位
- *ReplicaSet*: Podのレプリカ数を維持する
- *Deployment*: ReplicaSetを管理し、ローリングアップデートを実現する
- *DaemonSet*: 各ノードにPodを1つずつ配置する
- *StatefulSet*: ステートフルなアプリケーション向けのPod管理
- *Job / CronJob*: 一回限り、または定期的なバッチ処理を実行する

=== ネットワーク系リソース

- *Service*: Podへのネットワークアクセスを提供する
- *Ingress*: HTTP/HTTPSのルーティングを管理する

=== 設定・ストレージ系リソース

- *ConfigMap*: 設定データを管理する
- *Secret*: 機密情報を管理する
- *PersistentVolume (PV)*: 永続ストレージを提供する
- *PersistentVolumeClaim (PVC)*: PVの利用を要求する

=== クラスタ管理系リソース

- *Namespace*: クラスタ内のリソースを論理的に分離する
- *ServiceAccount*: Pod用の認証情報を管理する
- *Role / ClusterRole*: アクセス権限を定義する

== マニフェストファイル

Kubernetesではリソースの定義をYAMLファイル（マニフェスト）で記述します。すべてのマニフェストには以下の共通フィールドがあります。

```yaml
apiVersion: v1          # APIのバージョン
kind: Pod               # リソースの種類
metadata:               # メタデータ
  name: my-pod          # リソース名
  labels:               # ラベル（任意のキー・バリュー）
    app: my-app
spec:                   # リソースの仕様（種類によって異なる）
  ...
```

=== apiVersion

リソースの種類によって使用するAPIバージョンが異なります。

#table(
  columns: (1fr, 1fr),
  align: (left, left),
  table.header(
    [*リソース*], [*apiVersion*],
  ),
  [Pod, Service, ConfigMap, Secret], [`v1`],
  [Deployment, ReplicaSet], [`apps/v1`],
  [Ingress], [`networking.k8s.io/v1`],
  [Job, CronJob], [`batch/v1`],
)

== ラベルとセレクタ

=== ラベル

ラベルはリソースに付与するキー・バリューのペアです。リソースの分類やフィルタリングに使用します。

```yaml
metadata:
  labels:
    app: web-server
    env: production
    tier: frontend
```

=== セレクタ

セレクタはラベルを使ってリソースを選択する仕組みです。DeploymentがPodを管理したり、ServiceがPodにトラフィックを送る際に使われます。

```yaml
selector:
  matchLabels:
    app: web-server
```

== kubectl の基本コマンド

#table(
  columns: (1fr, 2fr),
  align: (left, left),
  table.header(
    [*コマンド*], [*説明*],
  ),
  [`kubectl get <リソース>`], [リソースの一覧を表示する],
  [`kubectl describe <リソース> <名前>`], [リソースの詳細を表示する],
  [`kubectl apply -f <ファイル>`], [マニフェストを適用する（作成・更新）],
  [`kubectl delete -f <ファイル>`], [マニフェストのリソースを削除する],
  [`kubectl logs <Pod名>`], [Podのログを表示する],
  [`kubectl exec -it <Pod名> -- <コマンド>`], [Pod内でコマンドを実行する],
  [`kubectl port-forward <Pod名> <ローカルポート>:<Podポート>`], [Podへポートフォワーディングする],
)

=== 出力フォーマット

`-o` オプションで出力形式を変更できます。

```bash
kubectl get pods -o wide          # 詳細情報を表示
kubectl get pods -o yaml          # YAML形式で出力
kubectl get pods -o json          # JSON形式で出力
kubectl get pods -o name          # リソース名のみ表示
```
