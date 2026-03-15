= Pod

== Podとは

Podは Kubernetesにおけるデプロイの最小単位です。1つ以上のコンテナをまとめたグループであり、同一Pod内のコンテナはネットワークとストレージを共有します。

多くの場合、1つのPodには1つのコンテナを配置しますが、密接に連携する複数のコンテナを同一Podに配置するパターン（サイドカーパターン）もあります。

== Podの作成

=== マニフェストで作成

`nginx-pod.yaml` というファイルを作成します。

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-pod
  labels:
    app: nginx
spec:
  containers:
    - name: nginx
      image: nginx:1.27
      ports:
        - containerPort: 80
```

マニフェストを適用してPodを作成します。

```bash
kubectl apply -f nginx-pod.yaml
```

=== コマンドで直接作成

簡単なテスト用途では `kubectl run` コマンドでも作成できます。

```bash
kubectl run nginx-pod --image=nginx:1.27 --port=80
```

== Podの状態確認

=== 一覧表示

```bash
kubectl get pods
```

```
NAME        READY   STATUS    RESTARTS   AGE
nginx-pod   1/1     Running   0          30s
```

=== 詳細情報

```bash
kubectl describe pod nginx-pod
```

Podの詳細情報が表示されます。トラブルシューティングの際に特に重要な情報は以下の通りです。

- *Events*: Podに関するイベント（スケジュール、イメージのプル、起動など）
- *Conditions*: Podの状態条件
- *Containers*: 各コンテナの状態

== Podのライフサイクル

Podは以下の状態（Phase）を遷移します。

#table(
  columns: (1fr, 2fr),
  align: (left, left),
  table.header(
    [*状態*], [*説明*],
  ),
  [Pending], [Podが作成されたがまだコンテナが起動していない],
  [Running], [少なくとも1つのコンテナが実行中],
  [Succeeded], [すべてのコンテナが正常に終了した],
  [Failed], [少なくとも1つのコンテナが異常終了した],
  [Unknown], [Podの状態を取得できない],
)

== Pod内でのコマンド実行

```bash
# Podのシェルに接続
kubectl exec -it nginx-pod -- /bin/bash

# 単一コマンドの実行
kubectl exec nginx-pod -- cat /etc/nginx/nginx.conf
```

== Podのログ確認

```bash
# ログを表示
kubectl logs nginx-pod

# リアルタイムでログを追跡
kubectl logs -f nginx-pod

# 直近の100行を表示
kubectl logs --tail=100 nginx-pod
```

== ポートフォワーディング

Podに直接アクセスするにはポートフォワーディングを使用します。

```bash
kubectl port-forward nginx-pod 8080:80
```

ブラウザで `http://localhost:8080` にアクセスするとnginxの画面が表示されます。

== マルチコンテナPod

1つのPodに複数のコンテナを配置する場合の例です。

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: multi-container-pod
spec:
  containers:
    - name: app
      image: nginx:1.27
      ports:
        - containerPort: 80
    - name: sidecar
      image: busybox:1.36
      command: ["sh", "-c", "while true; do echo sidecar running; sleep 30; done"]
```

マルチコンテナPodではコンテナ名を指定してログを確認します。

```bash
kubectl logs multi-container-pod -c sidecar
```

== リソース制限

コンテナに対してCPUとメモリの制限を設定できます。

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: resource-limited-pod
spec:
  containers:
    - name: app
      image: nginx:1.27
      resources:
        requests:          # 最低限確保するリソース
          memory: "64Mi"
          cpu: "250m"
        limits:            # 使用上限
          memory: "128Mi"
          cpu: "500m"
```

- *requests*: スケジューラがノードを選択する際の基準。この量のリソースが利用可能なノードに配置される
- *limits*: コンテナが使用できるリソースの上限。超過するとOOMKill（メモリ）やスロットリング（CPU）が発生する

== ヘルスチェック

Kubernetesは3種類のヘルスチェック（Probe）をサポートしています。

=== livenessProbe

コンテナが正常に動作しているか確認します。失敗するとコンテナが再起動されます。

=== readinessProbe

コンテナがリクエストを受け付けられる状態か確認します。失敗するとServiceのエンドポイントから除外されます。

=== startupProbe

コンテナの起動が完了したか確認します。起動が遅いアプリケーションに使用します。

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: health-check-pod
spec:
  containers:
    - name: app
      image: nginx:1.27
      livenessProbe:
        httpGet:
          path: /
          port: 80
        initialDelaySeconds: 5
        periodSeconds: 10
      readinessProbe:
        httpGet:
          path: /
          port: 80
        initialDelaySeconds: 3
        periodSeconds: 5
```

== Podの削除

```bash
# 名前を指定して削除
kubectl delete pod nginx-pod

# マニフェストで削除
kubectl delete -f nginx-pod.yaml
```
