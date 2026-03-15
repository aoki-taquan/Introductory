= 実践運用

== アプリケーションのデプロイ例

実践的な例として、Webアプリケーションをデプロイする一連の流れを紹介します。

=== Deploymentの作成

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
  namespace: default
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web-app
  template:
    metadata:
      labels:
        app: web-app
    spec:
      containers:
        - name: web-app
          image: nginx:1.27
          ports:
            - containerPort: 80
          resources:
            requests:
              cpu: "100m"
              memory: "128Mi"
            limits:
              cpu: "200m"
              memory: "256Mi"
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

=== Serviceの作成

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web-app-service
spec:
  type: NodePort
  selector:
    app: web-app
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
      nodePort: 30080
```

=== ConfigMapの作成

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: web-app-config
data:
  APP_ENV: "production"
  APP_LOG_LEVEL: "warn"
```

=== 一括適用

すべてのマニフェストを1つのディレクトリに配置して一括適用できます。

```bash
# ディレクトリ内のすべてのマニフェストを適用
kubectl apply -f ./manifests/

# 再帰的に適用
kubectl apply -f ./manifests/ -R
```

== トラブルシューティング

=== Podが起動しない場合

```bash
# Podの状態を確認
kubectl get pods

# 詳細情報とイベントを確認
kubectl describe pod <Pod名>

# ログを確認
kubectl logs <Pod名>

# 前回のコンテナのログを確認（再起動した場合）
kubectl logs <Pod名> --previous
```

=== よくあるPodのエラー

#table(
  columns: (1fr, 2fr, 2fr),
  align: (left, left, left),
  table.header(
    [*状態*], [*原因*], [*対処法*],
  ),
  [ImagePullBackOff], [イメージの取得に失敗], [イメージ名・タグの確認、レジストリの認証確認],
  [CrashLoopBackOff], [コンテナが繰り返しクラッシュ], [ログの確認、アプリケーションの修正],
  [Pending], [スケジュールできない], [ノードのリソース確認、taintの確認],
  [OOMKilled], [メモリ不足で強制終了], [メモリのlimitsを増やす],
  [CreateContainerConfigError], [設定エラー], [ConfigMapやSecretの存在確認],
)

=== Serviceに接続できない場合

```bash
# Serviceの確認
kubectl get service <Service名>

# エンドポイントの確認（Podが紐づいているか）
kubectl get endpoints <Service名>

# ラベルの一致を確認
kubectl get pods --show-labels
```

== リソースの監視

=== リソース使用量の確認

```bash
# ノードのリソース使用量
kubectl top nodes

# Podのリソース使用量
kubectl top pods
```

`kubectl top` を使用するには、metrics-serverが必要です。Minikubeでは以下のコマンドで有効にできます。

```bash
minikube addons enable metrics-server
```

== ラベルを活用した運用

=== ラベルの追加・変更

```bash
# ラベルを追加
kubectl label pods nginx-pod version=v1

# ラベルを上書き
kubectl label pods nginx-pod version=v2 --overwrite

# ラベルを削除
kubectl label pods nginx-pod version-
```

=== ラベルによるフィルタリング

```bash
# 特定のラベルを持つPodを表示
kubectl get pods -l app=nginx

# 複数条件でフィルタリング
kubectl get pods -l "app=nginx,env=production"

# ラベルの表示
kubectl get pods --show-labels
```

== 便利なkubectlコマンド

#table(
  columns: (1fr, 2fr),
  align: (left, left),
  table.header(
    [*コマンド*], [*説明*],
  ),
  [`kubectl get events --sort-by=.metadata.creationTimestamp`], [イベントを時系列で表示],
  [`kubectl api-resources`], [利用可能なリソース種類を一覧表示],
  [`kubectl explain <リソース>`], [リソースのフィールドを確認],
  [`kubectl diff -f <ファイル>`], [適用前に差分を確認],
  [`kubectl debug <Pod名> -it --image=busybox`], [デバッグ用コンテナを起動],
)

== 次のステップ

本ガイドではKubernetesの基礎を学びました。さらに学習を進めるために、以下のトピックを探索してみてください。

- *Ingress*: HTTPルーティングとTLS終端
- *Helm*: Kubernetesパッケージマネージャ
- *Kustomize*: マニフェストのカスタマイズツール
- *RBAC*: ロールベースアクセス制御
- *NetworkPolicy*: Pod間のネットワーク制御
- *HPA（Horizontal Pod Autoscaler）*: 自動水平スケーリング
- *StatefulSet*: ステートフルアプリケーションの管理
- *Operator*: カスタムコントローラーの開発
- *GitOps*: ArgoCD、Fluxを使った継続的デリバリー

=== 参考リソース

- Kubernetes公式ドキュメント: https://kubernetes.io/ja/docs/
- Kubernetes公式チュートリアル: https://kubernetes.io/ja/docs/tutorials/
- kubectl チートシート: https://kubernetes.io/ja/docs/reference/kubectl/cheatsheet/
