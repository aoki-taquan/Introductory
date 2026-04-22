= アーキテクチャパターン集

実務で頻出する AWS 構成を「*なぜそうするか*」とセットで紹介する。各パターンに *構成図*、*主要サービス選択の理由*、*コスト感*、*拡張ポイント*、*変形パターン* を添える。

== Web アプリの基本パターン

=== 静的サイト + サーバーレス API

```
[User] → Route 53 → CloudFront → S3（静的フロント、OAC）
                            ↓ /api/*
                    API Gateway HTTP API → Lambda → DynamoDB
                                            ↓
                                          Cognito（認証）
```

- *特長*：常時稼働インフラゼロ、スケール無制限、Free Tier 内に収まることが多い
- *向く規模*：個人サービス〜MAU 数十万
- *コスト感*：MAU 1万なら月数ドル
- *弱点*：複雑なバックエンド処理、長時間処理、SQL 必須要件には向かない
- *変形*：認証を Auth0 に置換、DynamoDB → Aurora Serverless v2、Lambda → App Runner

=== 古典的 3層 Web アプリ

```
[User] → Route 53 → ALB → EC2 (Auto Scaling, multi-AZ) → RDS (Aurora, Multi-AZ)
                       ↓
                    ElastiCache（セッション・DB キャッシュ）
                       ↓
                    S3（画像・添付）+ CloudFront
```

- *特長*：既存技術スタック（PHP/Rails/Spring 等）をそのまま乗せやすい
- *向く規模*：MAU 数万〜数百万
- *コスト感*：t3.medium × 2 + Aurora db.r6g.large + ALB + NAT で月 \$300〜500
- *拡張*：CloudFront を前段に、Bot 対策に WAF、CDN/Cookie 認証を追加
- *変形*：EC2 → ECS Fargate、RDS → Aurora Serverless v2

=== コンテナ化 Web

```
[User] → CloudFront → ALB → ECS Fargate → Aurora
                       ↓
                    Service Discovery / App Mesh
                       ↓
                    ECS Fargate（マイクロサービス）
```

- *特長*：CI/CD で頻繁にデプロイ、サーバ管理ゼロ
- *向く規模*：マイクロサービス化されたアプリ
- *拡張*：EKS にすると Helm/operator など k8s エコシステム活用

== モバイルバックエンド

=== Amplify + Cognito + AppSync

```
[Mobile App] → Amplify Hosting（Web 配信）
            → Cognito（認証）
            → AppSync（GraphQL） → DynamoDB
                              → Lambda → 任意サービス
            → S3（添付）
            → Pinpoint（プッシュ通知）
```

- *特長*：フロント開発者だけで完結。GraphQL でクエリ柔軟
- *向く規模*：B2C モバイル、新規プロダクト

=== REST + Cognito + DynamoDB

```
[Mobile App] → API Gateway HTTP API（JWT Authorizer）
             → Lambda
             → DynamoDB / S3 / RDS
```

- *特長*：シンプル、REST 慣れている開発者向け

== バッチ・データ処理

=== サーバーレス ETL

```
[源データ S3] → EventBridge → Step Functions
                                ├ Glue Crawler
                                ├ Glue ETL（PySpark）
                                └ Athena CTAS
                                ↓
                            [変換後 S3] → QuickSight
```

- *特長*：常時稼働ゼロ、スケール自動
- *コスト感*：1日1回 100GB 処理で月 \$50〜100
- *変形*：EMR Serverless / Spark on K8s

=== Map-Reduce 大規模バッチ

```
[源データ S3] → EMR on EC2（Spark） → S3
                              → Spot で低コスト
```

- *特長*：超大規模、独自フレームワーク利用
- *拡張*：EMR Serverless にして運用負荷低減

=== 機械学習パイプライン

```
[新規データ S3] → SageMaker Pipelines
                  ├ 前処理（Processing Job）
                  ├ 訓練（Training Job、Spot）
                  ├ 評価
                  └ Model Registry 登録
                       ↓
                  CodePipeline 承認 → SageMaker Endpoint デプロイ
```

== ストリーミング処理

=== リアルタイムログ分析

```
[App] → CloudWatch Logs → Subscription Filter → Kinesis Firehose
                                              → S3（長期）
                                              → OpenSearch（短期）
                                  → Athena → QuickSight
```

=== IoT データパイプライン

```
[Devices] → IoT Core → Rules Engine
                    ├ DynamoDB（最新値）
                    ├ Kinesis Data Streams → Flink → Aurora（集計）
                    └ Firehose → S3（履歴）→ Athena
```

== イベント駆動・非同期

=== 注文処理（Saga）

```
[Web] → API → SQS → Lambda（注文受付）
                  ↓
              EventBridge → Step Functions
                            ├ 在庫確認 → 在庫サービス
                            ├ 決済処理 → 決済サービス
                            ├ 配送手配 → 物流サービス
                            └ 通知    → SES / SNS
                            ↑
                            （失敗時は補償トランザクション）
```

=== ファンアウト処理

```
[Producer] → SNS Topic → SQS-A → Worker A（メール送信）
                      → SQS-B → Worker B（DB 更新）
                      → SQS-C → Worker C（外部 API 通知）
```

== マイクロサービス通信

=== ECS / EKS + Service Discovery

```
[ALB / Ingress] → Service A
                ↓ Service Discovery (Cloud Map / k8s Service)
              Service B → DynamoDB
              Service C → Aurora
```

=== VPC Lattice

```
[Service Network]
  ├ Service A（Lambda）
  ├ Service B（ECS Fargate）
  └ Service C（EC2）
   ↑
   Auth Policy（IAM）で認可
```

VPC ピアリング・PrivateLink・ALB を使わず、サービス間通信を抽象化。

=== App Mesh（Envoy ベース）

ECS / EKS の上で *Envoy サイドカー* を使った Service Mesh。リトライ、サーキットブレーカ、可観測性、mTLS。AWS は VPC Lattice に重心移動中だが、既存 App Mesh 利用は継続。

== マルチアカウント・マルチリージョン

=== 中央 Inspection VPC + Workload VPCs

```
[Workload VPC] →┐
                ├ Transit Gateway → Inspection VPC（Network Firewall）→ Internet
[Workload VPC] →┘                                                    ↑
                                                                  Egress VPC
```

すべての外向き通信を中央検査。コンプライアンス重視構成。

=== Active-Active マルチリージョン

```
[User] → Route 53 (Latency) → 東京 ALB → ECS → Aurora Global Cluster Primary
                            → バージニア ALB → ECS → Aurora Global Cluster Secondary
                            ↓
                        CloudFront でキャッシュ統合
```

- DynamoDB Global Tables、Aurora Global Database、S3 Cross-Region Replication
- Route 53 Failover で災害時の切替

=== マルチアカウント Landing Zone

20章参照。Control Tower で構築。

== セキュリティ重視構成

=== ゼロトラスト・ネットワーク

```
[User] → AWS Verified Access（IAM Identity Center + デバイス検証）
       → 内部 ALB → ECS → DB
```

VPN なしで社内アプリにアクセス。コンテキスト評価で動的認可。

=== 機密データレイク

```
[源] → KMS 暗号化 → S3（プライベート、CMK）
              ↓ Glue Crawler
              Glue Catalog（Lake Formation で行・列単位制御）
              ↓
              Athena / Redshift Spectrum / EMR（Lake Formation で認可）
              ↓
              QuickSight
```

== ハイブリッドクラウド

=== Direct Connect + Transit Gateway

```
[On-prem DC] ⇆ Direct Connect ⇆ Direct Connect Gateway ⇆ Transit Gateway
                                                       ⇆ VPC × N
```

=== Storage Gateway

```
[On-prem NAS] → File Gateway（NFS/SMB）→ S3
                                       ↓
                                   ライフサイクル → Glacier
```

== 災害復旧（DR）

27章で詳述。代表4パターン（Backup \& Restore、Pilot Light、Warm Standby、Multi-Site Active-Active）。

== コスト最適化テンプレート

=== 検証環境の自動停止

```
EventBridge Scheduler（平日 22:00）→ Lambda → EC2/RDS Stop
EventBridge Scheduler（平日 08:00）→ Lambda → EC2/RDS Start
```

夜間・週末停止で月コスト 1/3 程度に。

=== Spot を使ったバッチ処理

```
[Job Queue (SQS)] → AWS Batch（Spot）→ EC2 Spot Fleet
                                     → 中断時の再キュー
```

GPU 計算、ML 訓練、ETL バッチで適用。

== ゲーム配信パターン

=== マルチプレイヤゲームサーバ

```
[Player] → Global Accelerator（Anycast）
        → GameLift FleetIQ → EC2 Spot
        → Matchmaking
[ゲーム状態] → Redis (ElastiCache) / DynamoDB
[資産・配信] → S3 + CloudFront
```

== チャットボット / カスタマサポート

=== Connect + Bedrock

```
[Customer Call] → Amazon Connect → Lex Bot
                                ↓
                                Lambda → Bedrock（生成 AI）
                                       → Knowledge Base（社内 RAG）
                                ↓
                               必要時にエージェント転送
```

== 計算ワークロード

=== HPC

```
[Job] → AWS Batch / ParallelCluster
      → C7i / Hpc7g など計算ファミリー
      → FSx for Lustre（高速ファイル）
      → S3 永続保存
      → Spot で大幅コスト減
```

=== ML 推論サーバ

```
[Client] → ALB → ECS Fargate（軽量推論）
        → ALB → SageMaker Endpoint（重い推論、Inferentia）
```

== メタパターン：選択の指針

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*要件*], [*第一選択*]),
  [常時負荷低・スパイクあり], [サーバーレス（Lambda、Fargate Spot、Aurora Serverless）],
  [予測可能な常時負荷], [EC2 + Savings Plans / RI、Aurora Provisioned],
  [既存資産活用], [Lift \& Shift（EC2、RDS）],
  [新規・モダン化前提], [サーバーレス + マネージド DB],
  [マルチクラウド要件], [Kubernetes（EKS）+ Terraform],
  [規制・隔離強い], [マルチアカウント + 中央 Inspection VPC],
  [グローバル展開], [Aurora Global / DynamoDB Global / Route 53 Latency],
  [低レイテンシ要件], [Wavelength / Outposts / Local Zones],
)

== 設計時のチェックリスト

新規構成を組むときに自問する項目：

- *データの所在* と *責任共有モデル* は明確か
- *単一障害点* がないか（AZ、リージョン、IAM、データ）
- *スケール戦略* は何か（垂直、水平、自動）
- *セキュリティ層* が適切か（IAM、ネットワーク、データ、検知）
- *監視と通知* がデフォルトで仕込まれているか
- *バックアップ・リストア演習* を行ったか
- *コスト構造* を把握しているか（時間課金、データ転送、リクエスト）
- *IaC で再現可能* か
- *終了・削除* の手順が決まっているか

すべてに「はい」と答えられない構成は、本番投入前にレビュー必須。

== Anti-pattern（避けるべき構成）

- *EC2 1台に全部乗せ*（DB、アプリ、キャッシュ、Web）→ SPOF
- *キーをコードにハードコード* → IAM Role、Secrets Manager に
- *本番アカウントで全部やる* → マルチアカウントで隔離
- *NAT Gateway を立てっぱなしの個人検証* → 検証後即削除
- *Lambda 単位で 5 個のテーブル JOIN* → 設計の見直し（DynamoDB なら Single Table）
- *巨大 Glue ジョブで全部前処理* → 段階的に Bronze→Silver→Gold
- *監視を後回し* → 最初の1日目から CloudWatch Dashboard と GuardDuty
- *バックアップを取っただけで終わり* → 必ず復元演習
