= Kustomize

== Kustomizeとは

Kustomizeは、Kubernetesマニフェストをテンプレートなしでカスタマイズするツールです。ベースとなるマニフェストに対して「パッチ」や「オーバーレイ」を適用することで、環境ごとの差分を管理します。

Kustomizeはkubectl に組み込まれており、追加のインストールなしで使用できます。

== HelmとKustomizeの比較

#table(
  columns: (1fr, 1fr, 1fr),
  align: (left, left, left),
  table.header(
    [*特徴*], [*Helm*], [*Kustomize*],
  ),
  [アプローチ], [テンプレートエンジン], [オーバーレイ（パッチ）],
  [学習コスト], [Goテンプレート構文が必要], [YAMLのみで完結],
  [パッケージ管理], [Chart リポジトリで配布], [Git で管理],
  [ロールバック], [helm rollback で可能], [Git で管理],
  [コミュニティChart], [豊富に存在], [なし（自分で作成）],
  [kubectl統合], [別途インストール必要], [kubectl に組み込み済み],
)

HelmとKustomizeは競合するものではなく、併用されることも多いです。HelmでインストールしたものをKustomizeでカスタマイズするパターンもあります。

== 基本的なディレクトリ構造

```
my-app/
├── base/                     # ベースのマニフェスト
│   ├── kustomization.yaml
│   ├── deployment.yaml
│   └── service.yaml
└── overlays/                 # 環境ごとのオーバーレイ
    ├── development/
    │   └── kustomization.yaml
    ├── staging/
    │   └── kustomization.yaml
    └── production/
        └── kustomization.yaml
```

== ベースの作成

=== マニフェストファイル

```yaml
# base/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
    spec:
      containers:
        - name: my-app
          image: my-app:latest
          ports:
            - containerPort: 8080
```

```yaml
# base/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: my-app
spec:
  selector:
    app: my-app
  ports:
    - port: 80
      targetPort: 8080
```

=== kustomization.yaml

```yaml
# base/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - deployment.yaml
  - service.yaml
commonLabels:
  managed-by: kustomize
```

=== ベースの適用

```bash
kubectl apply -k ./base/
```

== オーバーレイの作成

=== 開発環境

```yaml
# overlays/development/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../../base
namePrefix: dev-
namespace: development
patches:
  - target:
      kind: Deployment
      name: my-app
    patch: |
      - op: replace
        path: /spec/replicas
        value: 1
```

=== 本番環境

```yaml
# overlays/production/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../../base
namePrefix: prod-
namespace: production
patches:
  - target:
      kind: Deployment
      name: my-app
    patch: |
      - op: replace
        path: /spec/replicas
        value: 5
      - op: replace
        path: /spec/template/spec/containers/0/image
        value: my-app:v1.2.3
```

=== オーバーレイの適用

```bash
# 開発環境に適用
kubectl apply -k ./overlays/development/

# 本番環境に適用
kubectl apply -k ./overlays/production/

# 適用前にマニフェストを確認
kubectl kustomize ./overlays/production/
```

== 主な機能

=== namePrefix / nameSuffix

リソース名にプレフィックスやサフィックスを追加します。

```yaml
namePrefix: staging-
nameSuffix: -v2
```

=== namespace

すべてのリソースにNamespaceを設定します。

```yaml
namespace: staging
```

=== commonLabels / commonAnnotations

すべてのリソースに共通のラベルやアノテーションを追加します。

```yaml
commonLabels:
  env: staging
  team: backend
commonAnnotations:
  note: "managed by kustomize"
```

=== images

コンテナイメージを変更します。マニフェストを直接編集せずにイメージタグを切り替えられます。

```yaml
images:
  - name: my-app
    newName: registry.example.com/my-app
    newTag: v1.2.3
```

=== ConfigMapGenerator / SecretGenerator

ConfigMapやSecretを自動生成します。内容が変わるとハッシュ付きの名前が生成され、Podの再起動がトリガーされます。

```yaml
configMapGenerator:
  - name: app-config
    literals:
      - APP_ENV=production
      - APP_LOG_LEVEL=warn
    files:
      - config.json

secretGenerator:
  - name: app-secret
    literals:
      - DB_PASSWORD=mypassword
    type: Opaque
```

=== patchesStrategicMerge

Strategic Mergeパッチでマニフェストを部分的に上書きします。

```yaml
# overlays/production/increase-resources.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  template:
    spec:
      containers:
        - name: my-app
          resources:
            requests:
              cpu: "500m"
              memory: "256Mi"
            limits:
              cpu: "1000m"
              memory: "512Mi"
```

```yaml
# overlays/production/kustomization.yaml
patches:
  - path: increase-resources.yaml
```

== kustomize コマンド

```bash
# ビルド結果を表示（適用せずに確認）
kubectl kustomize ./overlays/production/

# 直接適用
kubectl apply -k ./overlays/production/

# 削除
kubectl delete -k ./overlays/production/

# diff（現在の状態との差分を確認）
kubectl diff -k ./overlays/production/
```
