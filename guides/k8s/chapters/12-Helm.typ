= Helm

== Helmとは

Helmは Kubernetesのパッケージマネージャです。複数のKubernetesマニフェストを「Chart」というパッケージにまとめて管理します。LinuxにおけるaptやyumのKubernetes版と考えるとわかりやすいでしょう。

Helmを使うことで以下のメリットがあります。

- 複雑なアプリケーションをワンコマンドでデプロイできる
- 環境ごとの設定値（values）を簡単に切り替えられる
- アプリケーションのバージョン管理とロールバックができる
- 豊富なコミュニティChartを活用できる

== インストール

```bash
# macOS
brew install helm

# Linux
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Windows
winget install Helm.Helm
```

```bash
# バージョン確認
helm version
```

== Chartリポジトリ

=== リポジトリの追加

```bash
# 公式の安定版リポジトリを追加
helm repo add bitnami https://charts.bitnami.com/bitnami

# Prometheus用リポジトリを追加
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

# リポジトリの更新
helm repo update
```

=== リポジトリの管理

```bash
# リポジトリの一覧
helm repo list

# リポジトリの削除
helm repo remove bitnami
```

=== Chartの検索

```bash
# リポジトリ内のChartを検索
helm search repo nginx

# Artifact Hubで検索
helm search hub prometheus
```

== Chartのインストール

=== 基本的なインストール

```bash
# nginx をインストール
helm install my-nginx bitnami/nginx

# Namespace を指定してインストール
helm install my-nginx bitnami/nginx -n web --create-namespace
```

`helm install <リリース名> <Chart名>` の形式です。リリース名はクラスタ内で一意である必要があります。

=== インストール前の確認

```bash
# テンプレートを展開して確認（ドライラン）
helm install my-nginx bitnami/nginx --dry-run

# 生成されるマニフェストを確認
helm template my-nginx bitnami/nginx
```

=== 設定値のカスタマイズ

Chartの設定値をカスタマイズするには `--set` フラグまたは `values.yaml` ファイルを使用します。

```bash
# --setで直接指定
helm install my-nginx bitnami/nginx \
  --set replicaCount=3 \
  --set service.type=NodePort

# values.yamlファイルで指定
helm install my-nginx bitnami/nginx -f my-values.yaml
```

`my-values.yaml` の例:

```yaml
replicaCount: 3
service:
  type: NodePort
  port: 80
resources:
  requests:
    memory: "128Mi"
    cpu: "100m"
  limits:
    memory: "256Mi"
    cpu: "200m"
```

=== 利用可能な設定値を確認

```bash
# Chartのデフォルトvaluesを確認
helm show values bitnami/nginx

# Chartの情報を確認
helm show chart bitnami/nginx
```

== リリースの管理

=== リリースの一覧

```bash
# 全リリースを表示
helm list

# 特定のNamespace
helm list -n web

# 全Namespace
helm list -A
```

=== アップグレード

```bash
# 設定値を変更してアップグレード
helm upgrade my-nginx bitnami/nginx --set replicaCount=5

# values.yamlを指定してアップグレード
helm upgrade my-nginx bitnami/nginx -f my-values.yaml

# インストールされていなければインストールする
helm upgrade --install my-nginx bitnami/nginx
```

=== ロールバック

```bash
# リリース履歴を確認
helm history my-nginx

# 前のバージョンに戻す
helm rollback my-nginx

# 特定のリビジョンに戻す
helm rollback my-nginx 2
```

=== アンインストール

```bash
helm uninstall my-nginx
```

== 独自Chartの作成

=== Chartのひな形を作成

```bash
helm create my-chart
```

以下のディレクトリ構造が生成されます。

```
my-chart/
├── Chart.yaml          # Chartのメタデータ
├── values.yaml         # デフォルトの設定値
├── charts/             # 依存Chart
├── templates/          # マニフェストテンプレート
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml
│   ├── hpa.yaml
│   ├── serviceaccount.yaml
│   ├── _helpers.tpl    # テンプレートヘルパー
│   ├── NOTES.txt       # インストール後のメッセージ
│   └── tests/
│       └── test-connection.yaml
└── .helmignore
```

=== Chart.yaml

```yaml
apiVersion: v2
name: my-chart
description: A Helm chart for my application
type: application
version: 0.1.0          # Chartのバージョン
appVersion: "1.0.0"     # アプリケーションのバージョン
```

=== テンプレートの記法

Helmテンプレートでは Go テンプレート構文を使用します。

```yaml
# templates/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "my-chart.fullname" . }}
  labels:
    {{- include "my-chart.labels" . | nindent 4 }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      {{- include "my-chart.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "my-chart.selectorLabels" . | nindent 8 }}
    spec:
      containers:
        - name: {{ .Chart.Name }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          ports:
            - containerPort: {{ .Values.service.port }}
```

=== ローカルChartのインストール

```bash
# ディレクトリから直接インストール
helm install my-release ./my-chart

# パッケージ化してインストール
helm package my-chart
helm install my-release my-chart-0.1.0.tgz
```

== よく使われるコミュニティChart

#table(
  columns: (1fr, 1fr, 1.5fr),
  align: (left, left, left),
  table.header(
    [*Chart*], [*リポジトリ*], [*用途*],
  ),
  [ingress-nginx], [ingress-nginx], [NGINX Ingress Controller],
  [cert-manager], [jetstack], [TLS証明書の自動管理],
  [prometheus], [prometheus-community], [メトリクス収集・監視],
  [grafana], [grafana], [ダッシュボード・可視化],
  [argo-cd], [argo], [GitOpsによるCD],
  [postgresql], [bitnami], [PostgreSQLデータベース],
  [redis], [bitnami], [Redisキャッシュ],
  [sealed-secrets], [sealed-secrets], [暗号化されたSecret管理],
)
