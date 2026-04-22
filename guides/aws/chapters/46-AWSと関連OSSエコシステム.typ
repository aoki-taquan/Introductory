= AWS と関連 OSS エコシステム

AWS は多くの OSS をマネージド化して提供する一方、独自 SaaS としても多数のサードパーティが *AWS 上で* または *AWS と統合して* 動いている。本章は「AWS + OSS / SaaS」の全体像を俯瞰し、どの場面で何を選ぶかの指針を示す。

== OSS をマネージド化した AWS サービス

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*OSS*], [*マネージド版*]),
  [MySQL / PostgreSQL / MariaDB], [RDS、Aurora],
  [Redis / Valkey], [ElastiCache、MemoryDB],
  [Apache Kafka], [MSK],
  [PrometheuS], [Managed Prometheus],
  [Grafana], [Managed Grafana],
  [Kubernetes], [EKS],
  [OpenSearch (Elasticsearch)], [OpenSearch Service],
  [Apache Spark / Hive / Presto], [EMR],
  [Apache Airflow], [MWAA],
  [Terraform], [HCP Terraform（AWS 純正 ではないが連携）],
  [Docker], [ECR / ECS / EKS / Lambda コンテナ],
  [Cassandra], [Keyspaces],
  [Neo4j 互換], [Neptune（独自）],
  [MongoDB 互換], [DocumentDB],
  [Temporal (Workflow)], [—（Step Functions が類似）],
  [ActiveMQ / RabbitMQ], [Amazon MQ],
  [ArgoCD / FluxCD], [EKS 上で自前（マネージドなし）],
  [Jenkins], [CodeBuild / CodePipeline（完全代替ではない）],
  [GitLab CI / GitHub Actions], [CodeCatalyst / CodePipeline],
)

*OSS をフォークせず互換実装* のパターン（Aurora、DocumentDB、OpenSearch）と、*OSS そのままホスト* のパターン（EKS、MSK、MWAA）が混在。

== AWS と相性の良い OSS（自前 or EC2/EKS 利用）

=== オブザーバビリティ

- *Prometheus*：メトリクス。Node exporter、PostgreSQL exporter 等
- *Grafana*：ダッシュボード
- *Loki*：ログ
- *Tempo / Jaeger*：トレース
- *Thanos / Cortex*：Prometheus の長期保管・HA
- *Vector / Fluent Bit / Fluentd*：ログ収集

=== オーケストレーション

- *Kubernetes*：EKS で
- *Istio / Linkerd / Cilium*：Service Mesh
- *Karpenter*：ノードオートスケール
- *Argo CD / Flux*：GitOps
- *Tekton*：CI/CD on k8s

=== データエンジニアリング

- *Apache Airflow*：MWAA 又は EC2/EKS 自前
- *dbt*：ELT、Redshift/Snowflake 連携
- *Apache Iceberg*：S3 Tables で native 対応
- *Apache Spark*：EMR / Glue
- *Trino / Presto*：Athena / 自前
- *Debezium*：CDC（MSK Connect）

=== ML

- *PyTorch / TensorFlow / JAX*：SageMaker / 自前
- *Hugging Face*：SageMaker JumpStart に統合
- *LangChain / LlamaIndex*：Bedrock と連携
- *MLflow*：SageMaker 統合あり
- *Ray*：SageMaker / EMR

=== セキュリティ

- *Falco*：Runtime Security on EKS
- *OPA / Gatekeeper / Kyverno*：K8s Policy
- *Vault*（HashiCorp）：Secrets Manager 代替
- *Trivy / Grype / Syft*：コンテナスキャン
- *Semgrep / Bandit*：SAST
- *SIEM*：OpenSearch, Splunk, Elastic Stack

== AWS と統合する主要 SaaS

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*SaaS*], [*用途*]),
  [Datadog], [APM、ログ、メトリクス、セキュリティ],
  [New Relic], [APM、オブザーバビリティ],
  [Splunk], [ログ分析、SIEM],
  [Sumo Logic], [クラウドネイティブ SIEM],
  [Snyk], [脆弱性スキャン、依存管理],
  [GitHub], [Git ホスティング、GHA CI/CD],
  [GitLab], [Git + CI/CD + Registry],
  [CircleCI], [CI/CD],
  [Terraform Cloud (HCP Terraform)], [IaC 管理],
  [Snowflake], [データウェアハウス],
  [Databricks], [データレイクハウス、ML],
  [Confluent], [Managed Kafka + Stream processing],
  [MongoDB Atlas], [Managed MongoDB],
  [Redis Cloud], [Managed Redis],
  [Okta / Auth0], [認証・認可],
  [PagerDuty], [インシデント管理],
  [Zendesk / Intercom], [サポート],
)

PrivateLink で *プライベートに接続* できる SaaS が増えている（Snowflake、Datadog、Snyk 等）。

== 選び方の指針

=== AWS マネージド vs OSS 自前 vs SaaS

```
[AWS マネージド]
 ○ AWS との統合深、運用簡単
 × ベンダロックイン、機能制限、AWS コスト

[OSS 自前]
 ○ 自由度、コスト最低
 × 運用負担、スケール・HA は自前

[サードパーティ SaaS]
 ○ 最新機能、専門性
 × コスト、統合の手間、データ越境
```

=== 判断軸

- *チームの運用力*：弱ければ AWS マネージド / SaaS、強ければ OSS 自前
- *コスト感度*：高ければ OSS、低ければ SaaS
- *機能要件*：先進的なら SaaS、標準的なら AWS / OSS
- *ベンダーロックイン許容度*：低ければ OSS、高ければ AWS マネージド
- *マルチクラウド要件*：あれば OSS 中立 or ベンダ中立 SaaS

== OSS 派の典型スタック

```
[Observability]    Prometheus + Grafana + Loki + Tempo
[Orchestration]    Kubernetes (EKS) + Argo CD + Karpenter
[Data]             Airflow on MWAA + dbt + Iceberg + Spark
[Security]         Vault + Falco + Trivy + Semgrep
[CI/CD]            GitHub + Argo CD + Tekton
[IaC]              Terraform + Helm
[Auth]             Keycloak or Dex（OIDC）
```

自由度高いがチーム体制が必須。

== SaaS 派の典型スタック

```
[Observability]    Datadog（APM / Log / Metric / Synthetics）
[Orchestration]    ECS Fargate（サーバーレスで楽に）
[Data]             Snowflake + dbt Cloud + Fivetran
[Security]         AWS GuardDuty + Snyk + Wiz
[CI/CD]            GitHub Actions + Vercel / Render
[IaC]              Terraform Cloud
[Auth]             Okta / Auth0
```

初期コスト高だが、少人数でも運用可。

== AWS 純正派の典型スタック

```
[Observability]    CloudWatch + Application Signals + X-Ray
[Orchestration]    ECS Fargate
[Data]             Athena + Glue + Redshift Serverless
[Security]         GuardDuty + SecurityHub + Inspector + Macie
[CI/CD]            CodePipeline + CodeBuild + CodeDeploy
[IaC]              CDK + CloudFormation
[Auth]             IAM Identity Center + Cognito
```

AWS 内で完結、ロックイン許容、最も運用楽。

== 現実的なハイブリッド

ほとんどの組織は *混合*：

```
[Observability]    Datadog（メイン）+ CloudWatch（補助）
[Orchestration]    EKS（移植性）+ 一部 Lambda
[Data]             Athena + Snowflake（BI）
[Security]         GuardDuty + Snyk
[CI/CD]            GitHub Actions（メイン）+ CodeBuild（内部）
[IaC]              Terraform（マルチクラウド）+ CDK（AWS ネイティブ一部）
[Auth]             Okta → Identity Center フェデレーション
```

「純粋」を追求するより、*用途に応じて使い分け* が現実解。

== OSS 活用のベストプラクティス

- *運用担当を明確化*：誰が OSS を更新・修正するか
- *バージョン pin*：突然の破壊的変更を避ける
- *CVE 監視*：脆弱性通知、定期パッチ
- *フォールバック計画*：OSS が止まった場合の代替
- *コミュニティ貢献*：長期利用するなら PR や Issue で関与
- *ライセンス確認*：商用利用の制約、GPL vs Apache vs BSL

== CNCF / オープンソース財団との関係

AWS は CNCF（Cloud Native Computing Foundation）のプラチナメンバー。Kubernetes、Prometheus、Envoy、etcd などを活用。独自プロジェクト（Karpenter、cdk8s、eks-anywhere）も CNCF に寄贈している。

OpenTelemetry、OpenSearch、OpenTofu など、「Open-」系プロジェクトへの投資も増加中。

== AWS 独自 OSS プロジェクト

- *cdk8s*：CDK で Kubernetes マニフェスト
- *Karpenter*：ノードオートスケーラー
- *Bottlerocket*：コンテナ最適化 OS
- *Firecracker*：マイクロ VM（Lambda / Fargate の基盤）
- *Amazon Linux*：独自ディストリビューション
- *OpenSearch*：Elasticsearch フォーク
- *Lambda Powertools*：サーバーレス運用ライブラリ
- *Copilot CLI*：ECS デプロイツール
- *AWS SDK*：各言語

「OSS としても公開、自社サービスとしても利用」というパターンが増えている。

== 選択は文化と変化する

- *10年前*：AWS 純正 + 自前 Jenkins
- *5年前*：AWS 純正 + GitHub Actions + Datadog
- *今*：AWS 純正 + GitHub + Datadog + Snowflake + Terraform
- *これから*：AWS + AI（Bedrock/Q）+ SaaS 複数 + OSS

*絶対の正解はない*。自社の目的と制約に応じて選び、定期的に見直す。ツール選択は *技術戦略* そのもの。

== チェックリスト

ツール選定時に自問：

- [ ] 解きたい問題は何か、他の選択肢と何が違うか
- [ ] 運用コスト（時間 + 費用）は見合うか
- [ ] データ・認証情報は誰の手に渡るか
- [ ] ベンダー依存のリスクは許容できるか
- [ ] 5年後も使える見込みはあるか
- [ ] チームの学習コストは妥当か
- [ ] 退出（乗り換え・廃止）の手順はあるか
- [ ] コミュニティ・サポートの状態
- [ ] ライセンス・商用利用条件
- [ ] セキュリティ・コンプライアンス要件

答えられない項目があれば、まず *PoC* で試してから本採用。
