= Deployment

== Deploymentとは

Deploymentは、Podのデプロイと管理を行うリソースです。Podを直接管理するのではなく、ReplicaSetを通じてPodを管理します。Deploymentを使うことで、以下の機能が利用できます。

- Podのレプリカ数の維持
- ローリングアップデート
- ロールバック
- スケーリング

実運用ではPodを直接作成せず、Deploymentを使うのが一般的です。

== DeploymentとReplicaSetの関係

Deploymentの管理構造は以下のようになっています。

```
Deployment
  └── ReplicaSet
        ├── Pod
        ├── Pod
        └── Pod
```

- *Deployment*: 望ましい状態を宣言し、ReplicaSetを管理する
- *ReplicaSet*: 指定された数のPodレプリカを維持する
- *Pod*: 実際にコンテナが動作する単位

== Deploymentの作成

`nginx-deployment.yaml` を作成します。

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  labels:
    app: nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
        - name: nginx
          image: nginx:1.27
          ports:
            - containerPort: 80
```

マニフェストの主要フィールドを解説します。

- `spec.replicas`: 維持するPodの数
- `spec.selector`: 管理対象のPodをラベルで選択
- `spec.template`: 作成するPodのテンプレート（ラベルはselectorと一致させる）

```bash
kubectl apply -f nginx-deployment.yaml
```

== 状態確認

```bash
# Deploymentの確認
kubectl get deployments

# ReplicaSetの確認
kubectl get replicasets

# Podの確認
kubectl get pods
```

```
NAME               READY   UP-TO-DATE   AVAILABLE   AGE
nginx-deployment   3/3     3            3           30s
```

- *READY*: 準備完了のPod数 / 期待するPod数
- *UP-TO-DATE*: 最新のPodテンプレートで作成されたPod数
- *AVAILABLE*: 利用可能なPod数

== スケーリング

=== コマンドでスケーリング

```bash
# レプリカ数を5に変更
kubectl scale deployment nginx-deployment --replicas=5

# 確認
kubectl get pods
```

=== マニフェストでスケーリング

`spec.replicas` の値を変更して `kubectl apply` を実行します。

```yaml
spec:
  replicas: 5
```

```bash
kubectl apply -f nginx-deployment.yaml
```

== ローリングアップデート

Deploymentの最大の利点の1つが、ダウンタイムなしのローリングアップデートです。

=== イメージの更新

```bash
# コマンドでイメージを更新
kubectl set image deployment/nginx-deployment nginx=nginx:1.27.3
```

またはマニフェストのイメージタグを変更して `kubectl apply` を実行します。

=== アップデートの進行状況を確認

```bash
kubectl rollout status deployment/nginx-deployment
```

```
Waiting for deployment "nginx-deployment" rollout to finish: 1 out of 3 new replicas have been updated...
Waiting for deployment "nginx-deployment" rollout to finish: 2 out of 3 new replicas have been updated...
deployment "nginx-deployment" successfully rolled out
```

=== アップデート戦略の設定

```yaml
spec:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1           # 同時に追加できるPod数
      maxUnavailable: 0     # 同時に停止できるPod数
```

- `maxSurge`: アップデート中に追加で作成できるPod数（またはパーセント）
- `maxUnavailable`: アップデート中に利用不可にできるPod数（またはパーセント）

== ロールバック

=== ロールアウト履歴の確認

```bash
kubectl rollout history deployment/nginx-deployment
```

```
REVISION  CHANGE-CAUSE
1         <none>
2         <none>
```

=== 特定リビジョンの詳細を確認

```bash
kubectl rollout history deployment/nginx-deployment --revision=1
```

=== 前のバージョンに戻す

```bash
kubectl rollout undo deployment/nginx-deployment
```

=== 特定のリビジョンに戻す

```bash
kubectl rollout undo deployment/nginx-deployment --to-revision=1
```

== 一時停止と再開

大きな変更を複数回に分けて行いたい場合、ロールアウトを一時停止できます。

```bash
# ロールアウトを一時停止
kubectl rollout pause deployment/nginx-deployment

# 複数の変更を適用
kubectl set image deployment/nginx-deployment nginx=nginx:1.27.3
kubectl set resources deployment/nginx-deployment -c=nginx --limits=cpu=200m,memory=512Mi

# ロールアウトを再開（一度にデプロイされる）
kubectl rollout resume deployment/nginx-deployment
```

== Deploymentの削除

```bash
# 名前で削除
kubectl delete deployment nginx-deployment

# マニフェストで削除
kubectl delete -f nginx-deployment.yaml
```

Deploymentを削除すると、管理下のReplicaSetとPodも自動的に削除されます。
