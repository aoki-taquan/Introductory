= Namespace

== Namespaceとは

Namespaceは、Kubernetesクラスタ内のリソースを論理的に分離するための仕組みです。同じクラスタ内で複数の環境（開発、ステージング、本番）やチームを分離する際に使用します。

== デフォルトのNamespace

Kubernetesクラスタには以下のNamespaceがデフォルトで存在します。

#table(
  columns: (1fr, 2fr),
  align: (left, left),
  table.header(
    [*Namespace*], [*説明*],
  ),
  [default], [Namespaceを指定しない場合に使用される],
  [kube-system], [Kubernetesシステムコンポーネントが動作する],
  [kube-public], [全ユーザーが読み取り可能な公開リソース],
  [kube-node-lease], [ノードのハートビート情報を管理する],
)

== Namespaceの操作

=== 作成

```bash
# コマンドで作成
kubectl create namespace development

# マニフェストで作成
kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: development
  labels:
    env: dev
EOF
```

=== 一覧表示

```bash
kubectl get namespaces
```

=== 特定のNamespace内のリソースを表示

```bash
# -n オプションでNamespaceを指定
kubectl get pods -n development

# すべてのNamespaceのリソースを表示
kubectl get pods --all-namespaces
# または
kubectl get pods -A
```

=== デフォルトNamespaceの変更

kubectlで毎回 `-n` を指定するのが面倒な場合、デフォルトのNamespaceを変更できます。

```bash
kubectl config set-context --current --namespace=development
```

== Namespaceにリソースを作成

マニフェストの `metadata.namespace` でNamespaceを指定します。

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  namespace: development
spec:
  replicas: 2
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

```bash
kubectl apply -f nginx-deployment.yaml
```

== ResourceQuota

Namespaceごとにリソースの使用量を制限できます。

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: dev-quota
  namespace: development
spec:
  hard:
    pods: "10"
    requests.cpu: "4"
    requests.memory: "8Gi"
    limits.cpu: "8"
    limits.memory: "16Gi"
```

=== ResourceQuotaの確認

```bash
kubectl describe resourcequota dev-quota -n development
```

== LimitRange

Namespace内のコンテナに対してデフォルトのリソース制限を設定できます。

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: dev-limits
  namespace: development
spec:
  limits:
    - default:
        cpu: "500m"
        memory: "256Mi"
      defaultRequest:
        cpu: "100m"
        memory: "128Mi"
      max:
        cpu: "2"
        memory: "1Gi"
      min:
        cpu: "50m"
        memory: "64Mi"
      type: Container
```

ResourceQuotaが設定されている場合、各Podにはresourcesのrequestsとlimitsの指定が必須になります。LimitRangeでデフォルト値を設定しておくと便利です。

== Namespaceの削除

```bash
kubectl delete namespace development
```

Namespaceを削除すると、そのNamespace内のすべてのリソースも削除されます。削除前に必ず確認してください。
