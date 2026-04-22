= コスト最適化と FinOps

10章でコストの基本、28章で Well-Architected の柱として軽く触れたコスト最適化を、本章では *FinOps の方法論* と *AWS の具体ツール* を組み合わせて深掘りする。

== FinOps とは

FinOps は *Finance + DevOps* の合成語。クラウド利用の財務管理を *エンジニアリング・財務・経営* の協業で回す方法論。FinOps Foundation が標準化を進めている。

=== FinOps の3原則

+ *Inform（可視化）*：何にいくら使っているかを把握する
+ *Optimize（最適化）*：無駄を削り、最適なリソース構成にする
+ *Operate（運用）*：継続的なプロセス・文化として定着させる

=== FinOps のフェーズ

```
[Crawl 段階] 月次レポート、コスト按分タグ、無駄リソース掃除
   ↓
[Walk 段階] Savings Plans、Reserved Instance、予算アラート
   ↓
[Run 段階] 自動化、リアルタイム可視化、アーキテクチャ単位の最適化
```

== AWS のコスト関連サービス

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*サービス*], [*用途*]),
  [Cost Explorer], [可視化・分析（13か月、API 経由で37か月）],
  [Budgets], [予算設定とアラート（コスト・使用量・RI/SP）],
  [Cost and Usage Report (CUR 2.0)], [詳細データを S3 へ。Athena で深掘り],
  [Cost Optimization Hub], [推奨を一元集約・優先順位付け],
  [Compute Optimizer], [EC2 / EBS / Lambda / ASG / RDS / Fargate の右サイジング推奨],
  [Trusted Advisor], [コスト・パフォーマンス・セキュリティ・耐障害性チェック],
  [Savings Plans], [計算リソースの予約購入],
  [Reserved Instances], [従来型予約購入（多くは Savings Plans 推奨）],
  [Customer Carbon Footprint Tool], [CO2 排出量可視化],
  [Pricing Calculator], [構成見積],
)

== コストの可視化

=== コスト配分タグ（Cost Allocation Tags）

リソースに付けたタグでコストを按分。*アカウント設定で「Active」化* しないとレポートに反映されない（アクティブ化日からのデータのみ）。

推奨タグ：

- `Project` / `Application`
- `Environment`（prod / staging / dev / sandbox）
- `Owner` / `Team`
- `CostCenter`
- `ManagedBy`（terraform / cdk / manual）

=== Cost Categories

複数のディメンション（アカウント・タグ・サービス）を *論理的にグループ* 化。「Marketing 部門」「データ基盤」「セキュリティ基盤」のような *ビジネス意味* で集計できる。

=== AWS Cost Explorer

13か月分（API 経由で最大37か月）のコスト・使用量を分析。

- グループ化：サービス、リージョン、AZ、API オペレーション、タグ、Cost Categories
- フィルタ：複数条件
- 予測（Forecast）：ML ベースで今月末の予測
- 保存済みレポート、お気に入り
- 異常検知（Cost Anomaly Detection）

=== Cost Anomaly Detection

ML ベースで *予期しないコスト急増* を検知し、メール / Slack で通知。Monitor を「サービス」「アカウント」「タグ」「Cost Categories」で設定。

=== CUR（Cost and Usage Report 2.0）

最も詳細な利用データを *S3 にデータレイク形式で配信*。Glue カタログ自動登録、Athena / QuickSight でクエリ。

=== AWS Cost Optimization Hub

各種推奨（Savings Plans、Compute Optimizer、Idle Resources、Right-sizing）を *横断的に集約・優先順位付け*。組織レベルでも有効化可。

== Right-Sizing（適正サイジング）

=== Compute Optimizer

EC2、Auto Scaling Group、EBS、Lambda、RDS、ECS Fargate に対し、*過去14日のメトリクスから* 推奨サイズを算出。

```bash
aws compute-optimizer get-ec2-instance-recommendations
```

レコメンデーションは「現状のリスク」と「最適化後の節約見込み」がセット。GUI で一覧確認可。

=== 手動チェックの観点

- *CPU 使用率* < 40%（平均）→ ダウンサイズ候補
- *メモリ使用率* < 40% → ダウンサイズ候補
- *ネットワーク I/O* < 50% → ダウンサイズ候補
- *EBS Provisioned IOPS / Throughput* が常時余裕 → gp3 に切替

== 購入オプション最適化

=== Compute Savings Plans

EC2、Fargate、Lambda 横断で1〜3年予約。

- 最大 *66% 割引*
- インスタンスファミリー・サイズ・リージョン・OS を変更可
- 全 EC2 / Fargate / Lambda に自動適用

=== EC2 Instance Savings Plans

特定インスタンスファミリー・リージョンに縛り、最大 *72% 割引*。

=== Reserved Instances

従来型。RDS / ElastiCache / OpenSearch / Redshift で利用。EC2 では Savings Plans 推奨。

=== コミット戦略

- *ベースライン消費の 60〜70% を Savings Plans でカバー*
- 残り 30% はオンデマンド + Spot
- ベースラインを急に下げない計画
- *3年 No Upfront > 1年 All Upfront > 1年 No Upfront* の順でお得（一般論）

=== Spot Instance

最大 *90% 割引*。中断耐性のあるワークロードに。

- *EC2 Auto Scaling グループ* で Spot 混合
- *Fargate Spot* でコンテナタスク
- *AWS Batch* でバッチ処理
- *EC2 Spot Fleet* で複数インスタンスタイプ＋複数 AZ
- *EMR / SageMaker* で計算ワークロード

== 不要リソースの掃除

定期的に確認するチェックリスト：

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*対象*], [*探し方*]),
  [停止 EC2 に紐づく EBS], [Trusted Advisor、Cost Explorer の EBS],
  [未アタッチ EBS], [`aws ec2 describe-volumes --filters Name=status,Values=available`],
  [未関連付け Elastic IP], [`aws ec2 describe-addresses --query "Addresses[?AssociationId==null]"`],
  [古い EBS スナップショット], [Lifecycle Manager で自動削除],
  [古い AMI], [カスタム AMI の世代管理],
  [使われていない NAT Gateway], [VPC Flow Logs で通信実績確認],
  [アイドル ELB], [Cost Explorer + CloudWatch (Active Connections=0)],
  [使われていない Lambda], [`Invocations`=0 の関数],
  [古い CloudWatch Logs グループ], [保持期間設定、不要グループ削除],
  [大量のマルチパートアップロードの破片], [S3 ライフサイクル],
  [非現行 S3 バージョン], [S3 ライフサイクル],
)

=== 自動化

EventBridge Scheduler + Lambda で *夜間に検出 → タグ付け → 通知 → 一定期間後削除* のフローを組む。

== サービス別の最適化ポイント

=== EC2

- 最新世代・Graviton 検討
- Auto Scaling で需要追従
- Spot 混合
- 停止可能なら夜間停止
- Compute Optimizer 反映
- *EBS gp2 → gp3 移行*（性能同等で安い）

=== RDS / Aurora

- *Multi-AZ は本番のみ*、検証は Single AZ
- Aurora Serverless v2（特に 0 ACU 自動ポーズ）
- リードレプリカ数の見直し
- *I/O Optimized*：I/O が多いなら検討
- *Reserved Instance*：1年予約で30〜40%

=== Lambda

- *Graviton（ARM）*：x86 比 20% 安い
- *メモリ最適化*：Lambda Power Tuning
- *Provisioned Concurrency* は本当に必要な時間帯のみ
- *コールドスタート対策*でリクエストあたりコスト最適化

=== コンテナ（ECS / EKS / Fargate）

- *Fargate Spot* / *EC2 Spot*
- *Karpenter consolidation*
- *Cluster Autoscaler* 最小構成
- 不要な NAT Gateway 共有化

=== S3

- ライフサイクルで Standard → IA → Glacier → Deep Archive
- *Intelligent-Tiering*：アクセスパターン不明なら一律
- *S3 Storage Lens* で全社可視化
- 未完了マルチパート削除（ライフサイクル）
- 古いバージョン削除
- *Requester Pays*：パブリックデータの読み出しを利用者負担に

=== データ転送

- *VPC エンドポイント*（S3/DynamoDB は無料）
- *PrivateLink* で内部通信プライベート化
- *CloudFront* 経由で S3 オリジンプル無料
- *リージョン間転送を避ける* 設計

=== CloudWatch

- *Logs 保持期間* 必須設定
- *Metrics の高頻度カスタムメトリクス* を絞る
- *Logs Insights クエリ* のスキャン量に注意
- *Container Insights / Application Insights* のサンプリング

=== Bedrock / SageMaker

- Bedrock：On-Demand → Provisioned Throughput の損益分岐
- SageMaker Notebook / Endpoint の停止忘れ防止
- *Spot Training*
- *Inferentia / Trainium* 検討

== 予算管理

=== AWS Budgets

- *コスト予算*：金額上限
- *使用量予算*：EC2 時間、データ転送量
- *Reservation 予算*：RI/SP 利用率
- *Savings Plans 予算*：SP 利用率と Coverage

通知：メール、SNS、Chatbot（Slack/Teams）。1アカウントで *最大 100 個* の予算。

=== 階層的予算設計

- *組織全体予算*：管理アカウントで月次総額
- *環境別予算*：prod / dev / sandbox
- *部門別予算*：CostCenter タグベース
- *プロジェクト別予算*：Project タグベース

== タグ戦略の運用

タグは *最初に決めて全リソースに強制* するのが鉄則。

- *Tag Policies*（Organizations）：組織レベルで必須タグ・タグ値を強制
- *Service Control Policies*：タグなしリソース作成を Deny
- *AWS Resource Groups Tag Editor*：一括タグ付け・修正
- *AWS Config Rule*：必須タグ違反を検知

== 組織的な FinOps

=== Cost Center モデル

- *Showback*：使用部署にコストを *見える化* する（請求はしない）
- *Chargeback*：使用部署に *請求書を回す*

最初は Showback で意識を高め、定着したら Chargeback に進む。

=== コストレビュー会議

- *月次*：前月実績、予算対比、異常検知、トレンド
- *四半期*：購入オプション最適化（SP 更新）
- *年次*：全体戦略、契約見直し

参加者：FinOps チーム、エンジニア、財務、経営層。

== 持続可能性とコスト

10章の *Customer Carbon Footprint Tool* と組み合わせ、CO2 削減 = 多くの場合 = コスト削減。

- Graviton 採用：CO2 削減＋コスト削減
- Spot 利用：遊休 HW 活用、CO2 削減
- データライフサイクル：低炭素な層へ

== 典型的な節約事例

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*施策*], [*典型的な節約率*]),
  [Compute Savings Plans 1年 No Upfront], [〜30%],
  [EC2 Spot（中断耐性ワークロード）], [〜70%],
  [gp2 → gp3 EBS], [〜20%],
  [Aurora Serverless v2 0 ACU], [低頻度環境で 80%超],
  [S3 Intelligent-Tiering], [10〜30%],
  [Right-sizing（Compute Optimizer）], [10〜25%],
  [Graviton 採用（EC2 / Lambda）], [10〜20%],
  [古い RI / SP の刷新], [5〜15%],
  [NAT Gateway 削減（S3 GW Endpoint）], [トラフィック次第で大幅],
  [CloudWatch Logs 保持期間設定], [ログ多めなら大],
)

== コスト最適化の優先順位

+ *見えない無駄を消す*：未使用 EBS / EIP / NAT、保持期間なし Logs
+ *Right-sizing*：Compute Optimizer 推奨を反映
+ *購入オプション*：Savings Plans でベースラインを覆う
+ *アーキテクチャ最適化*：Serverless 化、Graviton、S3 階層化
+ *組織的最適化*：FinOps 文化、定期レビュー、自動化

== よくある罠

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*罠*], [*対処*]),
  [タグ付けを後からやる], [最初から Tag Policy で強制],
  [予算アラートだけで安心], [予測ベースアラート、定期レビュー],
  [Savings Plans を過剰に買う], [ベースラインの 60〜70% に留める],
  [リザーブ買って即アーキ変更], [3年 RI は慎重に、1年でリスクヘッジ],
  [Cost Explorer を月末だけ見る], [週次・日次の異常検知],
  [削除を恐れて溜め込む], [タグ + 自動化で一定期間後削除],
  [Spot で本番停止], [中断耐性設計、混合戦略],
  [Bedrock / SageMaker で青天井], [Budgets、利用上限、レート制限],
)
