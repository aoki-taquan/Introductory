= 料金モデル完全解説

AWS のコストは複雑で、似たワークロードでも構成次第で *数倍* の差がつく。本章では料金モデルの基本から、割引戦略、隠れたコスト、見積りと監視までを詳細に扱う。

== AWS 料金の基本原則

=== 従量課金（Pay-as-you-go）

- 使った分だけ支払う
- 前金なし（オプションで前払い割引あり）
- 秒単位課金（EC2、RDS など）
- リクエスト単位課金（Lambda、API Gateway）
- ストレージは GB-月

=== リザーブド / Savings Plans

- 長期コミットで大幅割引
- 1年・3年
- All Upfront / Partial Upfront / No Upfront

=== Spot Instance

- 余剰容量を市場価格で
- 最大 90% 割引
- 中断あり（2分前通知）

=== Free Tier

- 12か月無料（2025/7 以前開設アカウント）
- Always Free（月100万リクエストの Lambda、25GB の DynamoDB など）
- Short-term Trial（30日など）

2025/7/15 以降の新規アカウントは *Free Plan*（\$100 クレジット + 6か月 or 消化終了の早い方）。

== 主要サービスの料金構造

=== EC2

- *インスタンス稼働時間*：秒単位（Linux/Windows）
- *EBS*：容量、IOPS、スループット
- *ネットワーク転送*：リージョン内 AZ 間、インターネット
- *パブリック IPv4*：2024/2 以降、常時 \$0.005/時
- *Elastic IP*：関連付けの有無問わず \$0.005/時
- *EBS スナップショット*：ストレージ + リージョン間コピー

例：t3.medium を月200時間利用 + gp3 100GB + インターネット 50GB転送

```
t3.medium: \$0.0544/h × 200h = \$10.88
EBS gp3:   \$0.096/GB × 100GB = \$9.60
Public IP: \$0.005/h × 200h = \$1.00
Transfer:  \$0.114/GB × 50GB = \$5.70
合計:      約 \$27/月
```

=== RDS / Aurora

- *インスタンス時間* or *ACU 時間*（Serverless v2）
- *ストレージ*（Aurora は自動拡張、RDS はプロビジョン）
- *IOPS*（RDS の io1/io2、gp3 の追加）
- *バックアップストレージ*（クラスタサイズ超過分）
- *データ転送*
- *Performance Insights*（7日無料、長期は別料金）
- *Enhanced Monitoring*（CloudWatch メトリクス追加）
- *Multi-AZ*（ほぼ 2倍）
- *Reserved Instance*（1年 30% / 3年 50%程度）

=== Lambda

- *リクエスト*：\$0.20/100万
- *実行時間 × メモリ*：\$0.0000166667/GB秒（x86）、Graviton は約 20% 安
- *プロビジョンド Concurrency*：時間課金
- *Ephemeral Storage*：512MB〜10,240MB、追加料金
- *Data Transfer*

Free Tier：月100万リクエスト + 40万 GB秒（永続）。

=== S3

- *ストレージ*：クラスごと
- *リクエスト*：PUT / GET / LIST（クラスごと）
- *データ転送*：同リージョン内は基本無料、インターネットは有料
- *管理機能*：Inventory、Analytics、Storage Lens
- *レプリケーション*：リクエスト + 転送
- *Intelligent-Tiering モニタリング*：\$0.0025/1,000 objects

```
1TB Standard を1年保管、月 10万 PUT + 100万 GET + 100GB 読み出し

ストレージ: \$25 × 12 = \$300
PUT:       \$0.005 × 10万 × 12 = \$6
GET:       \$0.0004 × 100万 × 12 = \$4.8
転送:      \$0.114 × 100GB × 12 = \$136.8
合計:      約 \$448/年
```

=== DynamoDB

- *On-Demand*：読み取り・書き込みリクエスト単位
- *Provisioned*：RCU/WCU 時間
- *ストレージ*：\$0.285/GB-月
- *データ転送*
- *Streams*：リクエスト
- *Global Tables*：レプリケーション RWU
- *PITR*：ストレージ追加
- *DAX*：時間 + インスタンス

=== CloudFront

- *データ転送*：リージョンごと、10TB 以降階段
- *HTTPS リクエスト*：\$0.0120/10,000（北米）
- *Origin Shield*：追加
- *Functions / Lambda\@Edge*：実行単価
- *Invalidation*：月1,000 パス無料、以降 \$0.005/パス
- *Free Tier*：永続1TB転送 + 1,000万リクエスト

=== CloudWatch

- *Metrics*：\$0.30/メトリクス/月（最初の10,000）、カスタムは別
- *Logs 取り込み*：\$0.50/GB、Standard
- *Logs 保存*：\$0.033/GB-月
- *Logs Insights*：\$0.0050/GB スキャン
- *Dashboard*：3つ無料、以降 \$3/月
- *Alarms*：\$0.10/アラーム/月（最初の 10）
- *Container Insights*、*Application Signals*：別

=== Bedrock

- *On-Demand*：入力トークン、出力トークン
- *Provisioned Throughput*：時間 + モデル単位
- モデルごとに大きく単価が違う

例：Claude Sonnet で質問1回（入力 500 tokens、出力 200 tokens）

```
Input:  500 tokens × \$3/100万 = \$0.0015
Output: 200 tokens × \$15/100万 = \$0.003
合計:   \$0.0045 per query
```

月 1万クエリで \$45。

=== NAT Gateway

- *時間*：\$0.062/時（東京）= 月 \$45
- *データ処理*：\$0.062/GB
- 2 AZ で \$90/月 基本料

=== Elastic Load Balancing

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*種類*], [*料金*]),
  [ALB], [\$0.0243/時 + LCU],
  [NLB], [\$0.0243/時 + NLCU],
  [GWLB], [\$0.0135/時 + GWCU],
)

月 18〜20 ドル + 処理量。

=== VPC エンドポイント

- *Gateway 型*（S3/DynamoDB）：無料
- *Interface 型*：\$0.014/時 + \$0.01/GB 処理

AZ ごとに ENI を持つため、マルチ AZ だと時間課金が倍々に。

== 割引戦略

=== Savings Plans

```
Compute Savings Plans（最大 66%）
  ├ EC2, Fargate, Lambda 横断
  └ インスタンスファミリー・リージョン・OS 変更可

EC2 Instance Savings Plans（最大 72%）
  └ 特定ファミリー・リージョンに固定

SageMaker Savings Plans（最大 64%）
  └ ML 訓練・推論
```

=== Reserved Instance

- RDS / ElastiCache / OpenSearch / Redshift / Elasticsearch で利用
- EC2 は Savings Plans 推奨

=== Spot

- 中断耐性のあるワークロード：最大 90%
- Batch、CI/CD、分散訓練、ステートレス Web の冗長部分

=== ボリュームディスカウント

- S3、CloudFront、データ転送は使用量階段制
- 組織全体で集約して割引適用（Organizations 一括請求）

== 隠れたコスト

運用中に *気づきにくい* が積み重なるもの：

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*項目*], [*実態*]),
  [NAT Gateway], [立てっぱなしで月数千円〜数万円],
  [Elastic IP（未使用）], [2024/2 以降は使用中も課金],
  [Public IPv4 一般], [2024/2 以降、全アドレスで時間課金],
  [CloudWatch Logs], [保持期間設定なしで無限],
  [S3 不完全マルチパート], [ライフサイクルで消さないと永久],
  [S3 非現行バージョン], [バージョニング有効バケット],
  [RDS Backup], [クラスタサイズ超過分で別課金],
  [EBS スナップショット], [増分だが蓄積],
  [OpenSearch Serverless], [最低 4 OCU で月 \$700 程度],
  [Transit Gateway], [アタッチメント時間課金],
  [Data Transfer], [リージョン間、AZ 間、NAT 経由],
  [Support Plan], [Developer \$29〜、Business 3%],
)

*月次のコストレビュー* が必須。

== コスト最適化の優先順位

+ *見えない無駄を消す*：未使用 EIP / EBS、保持期間なし Logs、放置 NAT
+ *Right-sizing*：Compute Optimizer 推奨
+ *Savings Plans*：ベースラインの 60〜70% を 1年でコミット
+ *Spot*：中断耐性ワークロード
+ *Graviton*：ARM 対応アプリを移行
+ *Serverless 化*：Lambda / Fargate / Aurora Serverless
+ *S3 階層化*：Lifecycle、Intelligent-Tiering
+ *CloudFront*：オリジンへの転送を CloudFront 経由無料化
+ *予約 RI*：Savings Plans 対象外の RDS / Redshift など
+ *Organizations 一括請求*：ボリュームディスカウント共有

== 見積りとシミュレーション

=== AWS Pricing Calculator

- `calculator.aws`
- 構成を組んで月額・年額・3年コスト
- 見積り保存・共有可能
- 複数シナリオの比較

=== Cost Explorer Forecast

機械学習ベースの予測。当月末・翌月の予測コスト。

=== Cost Anomaly Detection

異常急増を自動検知。Slack / メール通知。

=== AWS Budgets

- 月次・四半期・年次予算
- 実績 + 予測ベースのアラート
- 最大 100 予算 / アカウント

== 請求情報のアクセス

ルートユーザーだけでなく IAM ユーザーにも請求閲覧権限を付与：

1. ルートユーザーで *Billing Preferences*
2. *Activate IAM Access* を有効化
3. IAM ポリシー（例：`AWSBillingReadOnlyAccess`）を付与

== タグ戦略

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*タグキー*], [*用途*]),
  [Project / Application], [プロジェクト按分],
  [Environment], [prod / staging / dev / sandbox 別集計],
  [Owner / Team], [担当者・チーム別],
  [CostCenter], [財務按分の正本],
  [ManagedBy], [terraform / cdk / manual],
  [Compliance], [PCI / HIPAA 等の規制対応],
)

*Tag Policies*（Organizations）で必須タグを強制。*Cost Categories* で複数タグを組み合わせて論理グループ。

== CUR（Cost and Usage Report 2.0）

- 詳細利用データを S3 に配信
- Glue Catalog 自動登録
- Athena / QuickSight で経営向けダッシュボード
- 複雑な按分・分析に必須

```sql
SELECT
  line_item_product_code,
  SUM(line_item_unblended_cost) AS cost
FROM cur.cur_2_0
WHERE bill_billing_period_start_date = DATE '2026-04-01'
GROUP BY line_item_product_code
ORDER BY cost DESC
LIMIT 10;
```

== コストオプティマイゼーション ハブ

2023年後半 GA の *Cost Optimization Hub*。以下を *一元集約*：

- Savings Plans / RI 推奨
- Compute Optimizer 推奨
- 未使用リソース
- Graviton / Spot 適用余地

月次でレビュー、ROI 順に対応。

== Enterprise Discount Program（EDP）

- 大規模利用者向けの *カスタム割引*
- 年間コミット（例：年 \$1M 以上）で平均 10〜25% 追加割引
- AWS アカウントマネージャーと交渉
- Private Pricing Agreement

スタートアップ向けには *AWS Activate* クレジット（最大 \$100K）がある。

== Marketplace の料金

AWS Marketplace を通じて購入した SaaS / ソフトは AWS 請求に統合される。

- *SaaS 購読*：月額・年額、Pay-as-you-go
- *AMI / コンテナ*：インスタンス時間 + ライセンス
- *Private Offer*：ベンダとの個別価格
- *EDP カウント*：Marketplace 支払いも EDP のコミット達成に算入

== 最終チェックリスト

月次レビューで確認：

- [ ] 前月比の急増項目（Cost Explorer）
- [ ] Cost Anomaly Detection の通知
- [ ] 未使用リソース（EBS / EIP / 停止インスタンス）
- [ ] NAT Gateway 立てっぱなし
- [ ] CloudWatch Logs の保持期間
- [ ] S3 Lifecycle と非現行バージョン
- [ ] Savings Plans Coverage / Utilization
- [ ] Compute Optimizer 推奨
- [ ] 新規リージョンでのリソース誤作成
- [ ] 予算 vs 実績、予測

コスト管理は *継続的な文化*。ツールだけでなく、組織の習慣として定着させる。
