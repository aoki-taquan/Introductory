= 可観測性と SRE

9章で運用と監視の基本を扱った。本章では *可観測性（Observability）* の概念と、AWS での *分散トレーシング*、*Application Signals*、*Container Insights*、*OpenTelemetry*、*SRE 的な SLI/SLO 運用* を深掘りする。

== 監視と可観測性の違い

- *監視（Monitoring）*：事前に決めた指標が *予期した範囲* にあるかを継続チェック
- *可観測性（Observability）*：*予期しない問題* に対して、システムの内部状態を *外部から推測* できる性質

「予期しない問題が起こる」を前提に設計するのが現代システム。可観測性の3本柱：

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*柱*], [*説明*]),
  [Metrics（メトリクス）], [数値時系列。集計済み、低コスト、可視化容易],
  [Logs（ログ）], [テキストイベント。詳細だがクエリ・コスト負荷高],
  [Traces（トレース）], [リクエストの分散経路。ボトルネック特定に強い],
)

これらに加え、*Profiling*（CPU/メモリの詳細）と *Events*（重要事象）を含めて *5本柱* とすることもある。

== AWS の可観測性スタック

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*目的*], [*主なサービス*]),
  [メトリクス], [CloudWatch Metrics, Managed Prometheus],
  [ログ], [CloudWatch Logs, OpenSearch Service],
  [トレース], [X-Ray, Managed Grafana, OpenTelemetry],
  [APM・統合], [CloudWatch Application Signals],
  [外形監視], [CloudWatch Synthetics],
  [リアルユーザー監視], [CloudWatch RUM],
  [プロファイリング], [CodeGuru Profiler],
  [可視化], [CloudWatch Dashboard, Managed Grafana, QuickSight],
  [アラート・インシデント], [SNS, EventBridge, Incident Manager, Chatbot],
)

== CloudWatch Metrics の使いこなし

=== Embedded Metric Format (EMF)

ログ出力と同時にメトリクスも出す JSON フォーマット。Lambda Powertools の Metrics モジュールが内部で使っている。

```json
{
  "_aws": {
    "Timestamp": 1745231400000,
    "CloudWatchMetrics": [{
      "Namespace": "MyApp",
      "Dimensions": [["Service"]],
      "Metrics": [
        {"Name": "OrdersProcessed", "Unit": "Count"},
        {"Name": "OrderValue", "Unit": "None"}
      ]
    }]
  },
  "Service": "orders",
  "OrdersProcessed": 1,
  "OrderValue": 1234.56,
  "OrderId": "abc-123"
}
```

`PutMetricData` API を呼ばずに、ログ書き込みだけでメトリクスが生成される。コスト効率良。

=== Anomaly Detection

機械学習による *動的なしきい値*。曜日・時間帯のパターンを学習。

```bash
aws cloudwatch put-anomaly-detector \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=InstanceId,Value=i-0abc... \
  --stat Average
```

しきい値運用が難しい指標（リクエスト数、レイテンシ）で有効。

=== Composite Alarm

複数アラームを論理演算で合成。

```bash
aws cloudwatch put-composite-alarm \
  --alarm-name "ProdServiceUnhealthy" \
  --alarm-rule "ALARM(HighErrorRate) AND ALARM(HighLatency)"
```

アラート疲れ防止。

=== Metric Math

複数メトリクスを式で組み合わせて *派生メトリクス*。エラー率（`Errors / Invocations * 100`）など。

== CloudWatch Logs

=== Logs Insights

```
fields @timestamp, @message, @logStream
| filter @message like /ERROR/ and userId = "user-123"
| stats count(*) by bin(5m)
| sort @timestamp desc
| limit 100
```

*正規表現*、*JSON フィールド抽出*（`fields @message.userId as user`）、集計、ソート、グラフ化。

=== Live Tail

リアルタイムでログを流れるように見る。`docker logs -f` の CloudWatch 版。

=== Subscription Filter

ログをリアルタイムで Kinesis / Firehose / Lambda に転送。OpenSearch / S3 への流し込みパイプラインの起点。

=== Vended Logs

VPC Flow Logs、Route 53 Resolver Logs、CloudFront Logs などを CloudWatch Logs / S3 / Firehose に出力。

=== コスト

- 取り込み：\$0.50/GB（東京、Standard）
- 保管：\$0.033/GB-月
- Logs Insights：\$0.0050/GB スキャン

*保持期間設定が必須*、*ログレベルの調整* と *サンプリング* で大幅削減できる。Standard と Infrequent Access（IA）クラスの選択も2024〜可能。

== AWS X-Ray

分散トレース。

=== セグメントとサブセグメント

- *セグメント*：1サービス内のトレース単位
- *サブセグメント*：セグメント内の細かい操作（DynamoDB 呼び出し、外部 HTTP 等）

X-Ray SDK / Lambda Powertools Tracer / OpenTelemetry いずれでも生成可。

=== サービスマップ

トレースから自動生成される *依存関係グラフ*。各ノードの平均レイテンシ、エラー率、スループットが見える。問題発生時の影響範囲特定が早い。

=== サンプリング

全トレースを取ると高コスト。X-Ray の *デフォルトサンプリングルール* は「最初の1リクエスト/秒 + 残り 5%」。アプリで上書き可。

== Application Signals

CloudWatch の *APM 機能*（2024年 GA）。

=== 主要機能

- *自動 SLI/SLO 設定*：レイテンシ、可用性、エラー率を自動収集
- *サービスカタログ*：マイクロサービス一覧
- *依存関係マップ*：X-Ray 統合のサービス相互参照
- *Burn Rate Alarm*：SLO の予算消費速度に基づくアラート
- *対応*：EC2 / ECS / EKS / Lambda（Lambda Powertools 経由）

=== SLO 設定の例

```
Service: orders-api
SLI: latency < 500ms (P99)
SLO: 99.5% over 7 days
Error budget: 0.5% × 10,080分 = 50.4分
Burn rate alarm: 1時間で全budget の 14.4倍消費
```

エラーバジェットの考え方を SRE 的に組み込める。

== Container Insights

ECS / EKS / Kubernetes 向け。Pod / コンテナ / ノード単位の CPU / メモリ / ネットワーク / ディスクメトリクス。

=== Enhanced observability（2024〜）

新世代。Prometheus メトリクス自動収集、より深い OS レベルメトリクス、コンテナ単位のドリルダウン。

=== 料金注意

メトリクス数とログ量で課金。大規模クラスタでは *特定 namespace のみ有効*、サンプリングで節約。

== AWS Distro for OpenTelemetry（ADOT）

*OpenTelemetry*（OTel）の AWS ディストリビューション。ベンダーロックイン回避、業界標準。

=== 構成

- *ADOT Collector*：エージェント。Trace / Metric / Log を受信し変換・送信
- *ADOT SDK*：アプリに組み込んで自動計装
- 送信先：X-Ray、CloudWatch、Managed Prometheus、Managed Grafana、サードパーティ（Datadog、New Relic 等）

```yaml
# ADOT Collector の設定例
receivers:
  otlp:
    protocols:
      grpc: { endpoint: 0.0.0.0:4317 }
      http: { endpoint: 0.0.0.0:4318 }
processors:
  batch:
exporters:
  awsxray:
  awsemf:
    namespace: MyApp
service:
  pipelines:
    traces: { receivers: [otlp], processors: [batch], exporters: [awsxray] }
    metrics: { receivers: [otlp], processors: [batch], exporters: [awsemf] }
```

OTel + ADOT は *将来の柔軟性* を確保する選択。

== Managed Prometheus / Managed Grafana

OSS の Prometheus / Grafana をマネージドで。

=== Managed Prometheus

- スケーラブル、リテンション 150日
- リモートライト経由でメトリクス収集
- PromQL 完全互換
- *Workspace* 単位

=== Managed Grafana

- ダッシュボード / アラート
- 多数のデータソース統合（CloudWatch、Prometheus、X-Ray、OpenSearch、Athena 等）
- IAM / SAML / Identity Center 認証

EKS と Prometheus エコシステムを使うなら *Managed Prometheus + Managed Grafana* が定番。

== CloudWatch Synthetics

外形監視。Canary（Node.js / Python スクリプト）を定期実行して URL や API のヘルスを確認。

```javascript
const { Synthetics } = require('Synthetics');

const apiCanary = async function () {
  const url = 'https://api.example.com/health';
  const response = await Synthetics.executeHttpStep('healthcheck', { url });
  if (response.statusCode !== 200) {
    throw new Error(`Status: ${response.statusCode}`);
  }
};

exports.handler = async () => {
  return await apiCanary();
};
```

CloudWatch アラームで失敗時に通知。

== CloudWatch RUM（Real-User Monitoring）

実際のブラウザクライアントから *パフォーマンス・エラー* をメトリクス化。Core Web Vitals（LCP、FID、CLS）、JS エラー、ページロード時間。

== Incident Manager

インシデント発生時の *対応プロセス自動化*。

- Response Plan（連絡経路、対応手順）
- Engagement（誰を呼ぶか、PagerDuty / Slack 統合）
- Runbook（Systems Manager Automation で対応操作）
- Post-incident analysis（テンプレートで振り返り）

CloudWatch アラーム → Incident Manager → 対応者呼び出し → Runbook 実行、というフロー。

== SRE 的な運用

=== SLI / SLO / SLA

- *SLI*（Indicator）：実測の指標（例：可用性 99.95%）
- *SLO*（Objective）：目標（例：99.9% 保証する内部目標）
- *SLA*（Agreement）：顧客との契約（例：99.5% 以下なら返金）

SLO は SLA より厳しく設定。バッファを内部で持つ。

=== Error Budget

SLO の余裕分を *エンジニアリングチームが「使える」* 概念。

- 99.9% SLO → 30日で 43.2分のダウンタイム許容
- これを超えるとリリースを止め、信頼性向上に集中
- 余裕があれば新機能リリースに使える

=== Burn Rate Alarm

Error Budget の消費速度でアラート。

```
1時間で 1日分（30日 budget の 1/30 = 3.33%）以上消費 → 重大アラート
1時間で 6時間分以上消費 → 中程度アラート
```

短期と長期を組み合わせて *誤検知を減らす*。Application Signals に組み込み済み。

=== Postmortem 文化

インシデント後に *非難なしの振り返り*。

- 何が起きたか
- なぜ起きたか（5 Whys）
- どう検知したか、どう対応したか
- 再発防止策

Incident Manager のテンプレート活用。

== オブザーバビリティの設計原則

- *最初の1日からダッシュボード* 1枚作る
- *構造化ログ*（JSON）を最初から
- *相関 ID* を全ログに伝播
- *ヘルスチェックエンドポイント* を必ず実装
- *ビジネスメトリクス* を技術メトリクスと並べて見る
- *ログ・メトリクス・トレースの相互リンク* を確立

== コスト最適化

可観測性は *気を抜くと月数百万円* レベルになる。

- *ログ取り込み量* を意識（DEBUG ログを本番で出さない）
- *保持期間* を必ず設定
- *Log Insights のクエリ範囲* を絞る
- *メトリクスのカーディナリティ* に注意（タグ次元が多すぎると爆発）
- *X-Ray サンプリング* を用途別に
- *Container Insights* は必要 namespace のみ

== サードパーティ統合

- *Datadog*：APM・ログ・メトリクスの統合プラットフォーム。AWS 連携豊富
- *New Relic*：APM 強い、SaaS
- *Splunk*：エンタープライズログ・SIEM
- *Honeycomb*：イベント指向、高カーディナリティに強い
- *Sumo Logic*：クラウドネイティブ SIEM

OTel + ADOT で *ベンダー乗り換え可能性* を確保しておくのが現代的。

== よくある落とし穴

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*罠*], [*対処*]),
  [ログ垂れ流し], [構造化、レベル別、サンプリング、保持期間],
  [ダッシュボードがない], [新規サービスはダッシュボード必須化],
  [アラート疲れ], [Composite Alarm、Severity 分け、Runbook 化],
  [監視のための監視], [SLO ベースに切替、ビジネス KPI と紐付け],
  [トレースのサンプリング不足], [99.9% は問題ない、エラー時は100%サンプル],
  [可観測性コスト爆発], [月次レビュー、必要 namespace のみ、サンプリング],
  [独自実装で属人化], [Powertools / OTel 等の標準採用],
)
