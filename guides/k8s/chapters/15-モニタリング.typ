= モニタリング

== Kubernetesにおけるモニタリングの重要性

Kubernetesクラスタを運用するには、アプリケーションとインフラの状態を継続的に監視する必要があります。モニタリングにより、障害の早期検知、パフォーマンスのボトルネック特定、キャパシティプランニングが可能になります。

== モニタリングスタック

Kubernetesのモニタリングにはデファクトスタンダードとなっているツールの組み合わせがあります。

#table(
  columns: (1fr, 1fr, 1.5fr),
  align: (left, left, left),
  table.header(
    [*ツール*], [*役割*], [*説明*],
  ),
  [Prometheus], [メトリクス収集], [時系列データベース、プル型のメトリクス収集],
  [Grafana], [可視化], [ダッシュボードによるメトリクスの可視化],
  [Alertmanager], [アラート管理], [Prometheusからのアラートをルーティング・通知],
  [Loki], [ログ収集], [Prometheusライクなログ集約システム],
  [Promtail / Alloy], [ログ転送], [各ノードからLokiへログを転送],
)

== Prometheus

=== Prometheusとは

PrometheusはCNCFの卒業プロジェクトで、Kubernetesクラスタのメトリクス収集と保存を行う時系列データベースです。プル型でターゲットからメトリクスをスクレイプ（収集）します。

=== kube-prometheus-stackのインストール

Prometheus、Grafana、Alertmanager、各種Exporterをまとめてインストールできるkube-prometheus-stackが広く使われています。

```bash
# Helmリポジトリの追加
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# インストール
helm install prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace
```

=== インストールされるコンポーネント

```bash
kubectl get pods -n monitoring
```

- *prometheus-server*: メトリクスの収集と保存
- *alertmanager*: アラートのルーティングと通知
- *grafana*: ダッシュボードUI
- *node-exporter*: ノードのメトリクスを公開
- *kube-state-metrics*: Kubernetesリソースの状態をメトリクスとして公開

=== Prometheus UIへのアクセス

```bash
kubectl port-forward svc/prometheus-kube-prometheus-prometheus -n monitoring 9090:9090
```

ブラウザで `http://localhost:9090` にアクセスします。

=== PromQL（Prometheus Query Language）

PrometheusではPromQLというクエリ言語でメトリクスを検索・集計します。

```
# Podごとの CPU 使用率
rate(container_cpu_usage_seconds_total{namespace="default"}[5m])

# Podごとのメモリ使用量
container_memory_usage_bytes{namespace="default"}

# HTTPリクエストのレート
rate(http_requests_total[5m])

# 5xx エラー率
rate(http_requests_total{status=~"5.."}[5m])
/ rate(http_requests_total[5m])
```

=== ServiceMonitor

Prometheus Operatorでは、ServiceMonitorリソースを使ってスクレイプ対象を定義します。

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: my-app-monitor
  namespace: monitoring
  labels:
    release: prometheus
spec:
  selector:
    matchLabels:
      app: my-app
  endpoints:
    - port: metrics
      interval: 30s
      path: /metrics
  namespaceSelector:
    matchNames:
      - default
```

アプリケーション側で `/metrics` エンドポイントを公開する必要があります。

== Grafana

=== Grafana UIへのアクセス

```bash
kubectl port-forward svc/prometheus-grafana -n monitoring 3000:80
```

ブラウザで `http://localhost:3000` にアクセスします。

=== 初期認証情報

kube-prometheus-stackでインストールした場合のデフォルト:

- ユーザー名: `admin`
- パスワード: `prom-operator`

=== プリインストールされたダッシュボード

kube-prometheus-stackには多数のダッシュボードがプリインストールされています。

- *Kubernetes / Compute Resources / Cluster*: クラスタ全体のリソース使用量
- *Kubernetes / Compute Resources / Namespace (Pods)*: Namespace別のPodリソース
- *Kubernetes / Compute Resources / Node (Pods)*: ノード別のPodリソース
- *Node Exporter / Nodes*: ノードのCPU、メモリ、ディスク、ネットワーク

=== カスタムダッシュボードの作成

Grafanaでは独自のダッシュボードを作成できます。

+ 左メニューの「+」→「New Dashboard」を選択
+ 「Add visualization」をクリック
+ データソースにPrometheusを選択
+ PromQLクエリを入力してパネルを作成
+ ダッシュボードを保存

== Alertmanager

=== アラートルールの定義

Prometheus Operatorでは、PrometheusRuleリソースでアラートルールを定義します。

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: my-app-alerts
  namespace: monitoring
  labels:
    release: prometheus
spec:
  groups:
    - name: my-app
      rules:
        - alert: HighMemoryUsage
          expr: |
            container_memory_usage_bytes{namespace="default",container="my-app"}
            / container_spec_memory_limit_bytes{namespace="default",container="my-app"}
            > 0.8
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "High memory usage detected"
            description: "Pod {{ $labels.pod }} memory usage is above 80%"

        - alert: PodCrashLooping
          expr: rate(kube_pod_container_status_restarts_total{namespace="default"}[15m]) > 0
          for: 5m
          labels:
            severity: critical
          annotations:
            summary: "Pod is crash looping"
            description: "Pod {{ $labels.pod }} has been restarting"
```

=== 通知先の設定

AlertmanagerでSlackやメールに通知を送信できます。Helmのvaluesで設定します。

```yaml
# values.yaml（kube-prometheus-stack）
alertmanager:
  config:
    route:
      receiver: slack
      group_by: ['alertname', 'namespace']
      group_wait: 30s
      group_interval: 5m
      repeat_interval: 4h
    receivers:
      - name: slack
        slack_configs:
          - channel: '#alerts'
            send_resolved: true
            api_url: 'https://hooks.slack.com/services/xxx/yyy/zzz'
```

== Loki（ログ集約）

Lokiは Grafana Labsが開発した、Prometheusに着想を得たログ集約システムです。ラベルベースでログをインデックス化するため、軽量で効率的です。

=== インストール

```bash
# Loki Stack（Loki + Promtail）のインストール
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
helm install loki grafana/loki-stack \
  -n monitoring \
  --set grafana.enabled=false \
  --set promtail.enabled=true
```

=== GrafanaでLokiのログを確認

+ Grafanaの左メニューから「Connections」→「Data sources」を選択
+ 「Add data source」で Loki を追加
+ URLに `http://loki:3100` を設定
+ 「Explore」でログを検索

=== LogQL（ログクエリ）

```
# Namespace でフィルタリング
{namespace="default"}

# Pod名でフィルタリング
{namespace="default", pod=~"my-app.*"}

# キーワードで検索
{namespace="default"} |= "error"

# 正規表現で検索
{namespace="default"} |~ "status=[45].."

# エラーログのレート
rate({namespace="default"} |= "error" [5m])
```

== metrics-server

metrics-serverは `kubectl top` コマンドやHPA（Horizontal Pod Autoscaler）に必要な軽量メトリクス収集ツールです。

```bash
# Minikubeの場合
minikube addons enable metrics-server

# Helmの場合
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm install metrics-server metrics-server/metrics-server -n kube-system
```

```bash
# ノードのリソース使用量
kubectl top nodes

# Podのリソース使用量
kubectl top pods

# 特定のNamespace
kubectl top pods -n monitoring
```
