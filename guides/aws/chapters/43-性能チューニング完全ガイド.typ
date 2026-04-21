= 性能チューニング完全ガイド

各サービスを本番運用する際の *性能チューニング知識* をサービス横断でまとめる。EC2 / EBS / S3 / Aurora / DynamoDB / Lambda / CloudFront / ELB の主要観点を扱う。

== 性能の前提：測定なくして改善なし

「遅い」を改善する前に、まず *測定* と *目標* を明確にする。

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*要素*], [*指標*]),
  [レイテンシ], [P50, P95, P99（中央値だけ見ない）],
  [スループット], [RPS、TPS、MB/s],
  [可用性], [Success Rate、エラー率],
  [コスト効率], [リクエストあたりコスト、ユーザーあたりコスト],
)

ツール：

- *CloudWatch Metrics*：基本指標
- *X-Ray*：分散トレーシング
- *Application Signals*：APM
- *Performance Insights*（RDS）
- *Lambda Power Tuning*：メモリ vs 速度の最適点
- *負荷ツール*：k6、Locust、JMeter、AWS Distributed Load Testing

== EC2 の性能

=== インスタンスタイプ選定

- *汎用（M）*：CPU/メモリバランス。迷ったらここから
- *コンピュート最適（C）*：CPU 重視。バッチ・コーディング
- *メモリ最適（R）*：メモリ重視。インメモリ DB、キャッシュ
- *ストレージ最適（I/D）*：ローカル NVMe SSD
- *GPU（G/P）*：機械学習、レンダリング
- *バースト（T）*：軽量・スパイク。CPU クレジット注意

=== 世代と CPU アーキテクチャ

- 最新世代を選ぶ（同価格でも性能向上）
- *Graviton（ARM, 末尾 g）*：x86 より 20% 安く 19% 高速のことが多い
- アプリが ARM 対応していれば検討価値大

=== EBS パフォーマンス

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*項目*], [*目安*]),
  [gp3 ベースライン], [3,000 IOPS、125 MB/s（容量に依存しない）],
  [gp3 最大], [16,000 IOPS、1,000 MB/s],
  [io2 Block Express], [256,000 IOPS、4,000 MB/s（特定インスタンス）],
  [EBS 最適化], [新世代インスタンスは標準で有効],
  [スループット制限], [インスタンスタイプ側にも上限あり],
)

性能不足のときは：

- gp2 → gp3 に切替（同性能で安い）
- gp3 の IOPS / Throughput を追加プロビジョン（容量と独立）
- io2 / io2 Block Express に切替（高 IOPS 要件）
- インスタンスタイプの EBS スループット上限を確認

=== ネットワーク

- 新世代インスタンスは *ENA*（10〜200 Gbps）対応
- 同一 *Cluster Placement Group* で低レイテンシ・高スループット
- *Elastic Fabric Adapter (EFA)*：HPC 用、低レイテンシ MPI

=== CPU バーストとクレジット（T 系）

- t3.micro：ベースライン 10%、unlimited mode で従量課金して持続
- 常時 CPU 高負荷なら *T 系を避ける*

== Aurora / RDS の性能

=== インスタンスサイズ

- ライターは *書き込み負荷* で決定
- リーダーは *読み取り並列度* で決定
- *Aurora Serverless v2* で動的に

=== クエリチューニング

- *EXPLAIN / EXPLAIN ANALYZE*：実行計画
- インデックス：B-tree（標準）、複合インデックス、被覆インデックス
- *Performance Insights* でトップ SQL を特定
- *pg\_stat\_statements* / *Performance Schema*

=== 接続管理

- アプリ側コネクションプール
- *RDS Proxy*：Lambda / マイクロサービスから多数接続するとき必須
- 接続数上限はインスタンスサイズ依存

=== Aurora 特有の最適化

- *I/O Optimized*：I/O が多いワークロードで固定料金
- *Aurora Optimized Reads*：読み取りキャッシュ拡大
- *Cache Warming*：起動直後の遅さを軽減
- *Backtrack*（MySQL）：誤更新からの即時巻き戻し

=== レプリケーションラグ

- リーダーで読み取った直後の書き込みは反映されないことがある
- 強整合性が必要な部分はライターから読む
- *Aurora Global Database* のクロスリージョンは通常 1秒未満

== DynamoDB の性能

=== Hot Partition

特定 PK に集中するとスロットル。対策：

- *書き込みシャーディング*：PK に乱数 suffix
- *Adaptive Capacity*：DynamoDB 側が自動調整（限界あり）
- *Write-through cache*：DAX で書き込み平準化

=== Query vs Scan

- Query：効率的、PK 必須
- Scan：全件、本番では原則禁止
- *Parallel Scan*：必要時に並列化

=== バッチ操作

- `BatchGetItem`：最大25項目
- `BatchWriteItem`：最大25項目
- ネットワーク往復削減

=== DAX（DynamoDB Accelerator）

- マイクロ秒台、読み取り重視
- Item Cache + Query Cache
- 書き込みは write-through
- VPC 内に配置

=== Global Tables

- 双方向レプリケーション、通常 1秒未満
- LWW での競合解決
- リージョン間ラグの可能性

== Lambda の性能

=== コールドスタート対策

- *SnapStart*（Java/Python/.NET）
- *Provisioned Concurrency*
- パッケージサイズ削減（`esbuild` 等）
- 軽量ランタイム選択
- *ARM (Graviton)*

=== 同時実行・スロットリング

- *Reserved Concurrency*：上限予約・他関数の影響回避
- *Provisioned Concurrency*：事前ウォーム
- バーストキャパ後は毎分 +500/秒
- 上限緩和申請

=== メモリと速度

- メモリを上げると CPU も比例増
- *Lambda Power Tuning* で最適点を探る
- 「メモリ増 → 速度向上 → コスト同等 or 低下」のスイートスポットあり

=== VPC 内 Lambda

- Hyperplane ENI で起動時間影響は最小（2019〜）
- DB 接続なら *RDS Proxy* 推奨

== S3 の性能

=== 高スループット

- Prefix あたり 3,500 PUT/秒、5,500 GET/秒
- 異なる Prefix を使うことで *並列化*（自動シャーディング）
- *Transfer Acceleration*：CloudFront エッジ経由でアップロード加速

=== マルチパートアップロード

- 100MB 超は *マルチパート推奨*
- 5GB 超は *マルチパート必須*
- 並列パート転送で高速

=== コピー

- *S3 Batch Operations*：大量オブジェクト一括処理
- *S3 Replication*：継続的同期
- *AWS DataSync*：高速・並列

=== S3 Express One Zone

低レイテンシ・高 IO 特化（ML 訓練、ビッグデータ）。Standard より高い。

=== Intelligent-Tiering

アクセスパターン不明 → 自動最適化。コスト重視。

== CloudFront の性能

=== Cache Hit Ratio 向上

- *キャッシュキー最小化*：Cache Policy で必要要素のみ
- *TTL 適切に*：オリジン側ヘッダ尊重
- *バージョン化 URL*：`/v123/app.js`（Invalidation 不要）
- *Origin Shield*：オリジン保護＋ヒット率向上

=== Origin への負荷

- Origin Failover：複数オリジン
- *Lambda\@Edge / CloudFront Functions* でリクエスト前処理
- *Origin Access Control*：プライベート S3 オリジン

=== 動的コンテンツ

- 動的 API は通常 CDN 効果薄い
- *エッジロケーションへの近接* は低レイテンシに有効
- *Lambda\@Edge* でエッジ側ロジック

== ELB の性能

=== ALB

- *ターゲットタイプ ip*：Pod IP に直接、k8s で推奨
- *ヘルスチェック*：適切な間隔と path
- *Connection Idle Timeout*：デフォルト 60秒、長時間処理は調整
- *HTTP/2 / gRPC* サポート
- *Connection Draining* でグレースフル切断

=== NLB

- 超低レイテンシ
- *Cross-zone Load Balancing*：AZ 間負荷分散（追加料金）
- *Static IP*：Elastic IP 割当可

=== 共通

- *スティッキネス*：Cookie / IP ベース
- *デプロイ前 Pre-warm*：大規模ローンチ時に AWS Support 依頼

== ネットワーク全般

=== データ転送料金

- 同一 AZ 内：無料
- 別 AZ：\$0.01/GB（双方向）
- 別リージョン：\$0.02〜\$0.09/GB

最適化：

- *VPC エンドポイント*（S3/DynamoDB は Gateway 型で無料）
- *PrivateLink* で別 VPC・別アカウントもプライベート
- *CloudFront* で S3 オリジンプル無料
- *AZ 配置の意識*：同一 AZ 通信を優先

=== Transit Gateway

- データ処理 \$0.02/GB
- 中央集約は楽だがコストかさむ

== コンテナ（ECS / EKS）の性能

=== タスク・Pod のリソース割当

- CPU / Memory リクエストとリミット
- *過剰リミット*：他に枯渇影響
- *過少リミット*：OOM
- *Burstable* 設定

=== ノード性能

- *Karpenter*：適切なインスタンスタイプ自動選定
- *Cluster Autoscaler*：ASG ベース
- *Spot 混合*：コスト・パフォーマンス

=== ネットワーキング

- *VPC CNI* の ENI 上限
- *Cilium* / *Calico* の eBPF
- *AWS Load Balancer Controller* で IP ターゲット

== サーバーレス全般

=== API Gateway

- *HTTP API*：低レイテンシ・低コスト
- *キャッシュ*：REST API のステージキャッシュ
- *Throttling*：使用量プランで制御

=== Step Functions

- *Express* vs *Standard*：高頻度短時間 → Express
- *Map*：並列実行最適化
- *Lambda 過剰呼び出し* を avoid（Service Integration を活用）

=== EventBridge

- *Event Pattern* の効率化
- *Pipes* でフィルタ・変換をサーバレス化

== 共通の最適化原則

1. *測定 → 仮説 → 改善 → 再測定* の繰り返し
2. *ボトルネックは1つ* ずつ解消
3. *キャッシュ* を多層に（CDN、API、DB、アプリ）
4. *非同期化*：SQS、Kinesis で耐スパイク
5. *バッチ化*：N 回呼び出しを1回に
6. *並列化*：Map、Parallel Scan、Fork-Join
7. *データ局所性*：通信距離を縮める
8. *Right-sizing*：過剰スペックは無駄、過少は性能不足

== ベンチマーク・負荷試験

=== ツール

- *k6*：JavaScript ベース、軽量
- *Locust*：Python、分散
- *JMeter*：定番、シナリオ機能豊富
- *Distributed Load Testing on AWS*：Fargate ベース、ボタン1つで大規模

=== 計測の鉄則

- 本番に近い構成で
- 段階的な負荷上昇（ramp-up）
- *コールドスタート / ウォーム* を分けて計測
- *エラー率と一緒に* レイテンシを見る
- パーセンタイル（P50/P95/P99）を見る

== チューニングの落とし穴

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*罠*], [*対処*]),
  [推測でチューニング], [必ず計測してから],
  [全部キャッシュで解決], [TTL、キャッシュ無効化、整合性],
  [スケールアップで凌ぐ], [ボトルネックを切り分け、水平分散],
  [コスト無視で性能追求], [コスト効率指標も併走],
  [本番でいきなり試す], [ステージング・段階リリース],
  [一度の改善で満足], [継続計測、リグレッション],
)
