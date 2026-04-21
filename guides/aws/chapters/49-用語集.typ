= 用語集

本書中で頻出する AWS / クラウド / 関連技術の用語をアルファベット順・五十音順で整理する。本書の最後の参照資料として使ってほしい。

== A〜Z

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*用語*], [*説明*]),
  [ABAC], [Attribute-Based Access Control。属性ベースアクセス制御],
  [ACM], [AWS Certificate Manager。SSL/TLS 証明書管理],
  [ACU], [Aurora Capacity Unit。Aurora Serverless v2 のリソース単位],
  [ADOT], [AWS Distro for OpenTelemetry。AWS が配布する OTel ディストロ],
  [AFT], [Account Factory for Terraform。Control Tower + Terraform 統合],
  [AKS], [Azure Kubernetes Service（AWS のサービスではない参考）],
  [ALB], [Application Load Balancer。L7 ロードバランサ],
  [AMI], [Amazon Machine Image。EC2 起動用イメージ],
  [APN], [AWS Partner Network],
  [APIs (API GW)], [API Gateway。HTTP / WebSocket API のマネージド],
  [ARN], [Amazon Resource Name。AWS リソースの一意識別子],
  [ASG], [Auto Scaling Group],
  [ASL], [Amazon States Language。Step Functions 定義言語],
  [AZ], [Availability Zone。リージョン内の独立データセンター群],
  [BCP], [Business Continuity Plan。事業継続計画],
  [BGP], [Border Gateway Protocol。Direct Connect / VPN で使用],
  [Bedrock], [生成 AI 基盤モデルの統合 API],
  [BYOK], [Bring Your Own Key。自社鍵を AWS に持ち込み],
  [BYOL], [Bring Your Own License],
  [CAA], [Certification Authority Authorization（DNS レコード）],
  [CAF], [Cloud Adoption Framework。AWS のクラウド導入指針],
  [CDK], [Cloud Development Kit。プログラム言語で書く IaC],
  [CDN], [Content Delivery Network。CloudFront など],
  [CDR], [Change Data Replication。CDC（Change Data Capture）と同義],
  [CER], [Certificate],
  [CIDR], [Classless Inter-Domain Routing。IP アドレス範囲],
  [CIDR ブロック], [VPC やサブネットの IP 範囲],
  [CIS], [Center for Internet Security。セキュリティベンチマーク],
  [Claude], [Anthropic 社の生成 AI モデル（Bedrock 提供）],
  [CMK], [Customer Managed Key。利用者管理 KMS 鍵],
  [CNAME], [Canonical Name。DNS の別名レコード],
  [Cognito], [エンドユーザー認証サービス],
  [Compute Optimizer], [リソース右サイジング推奨サービス],
  [Conformance Pack], [Config の準拠ルール集],
  [Cost Categories], [Cost Explorer の論理グループ化],
  [CSPM], [Cloud Security Posture Management。Security Hub など],
  [CUR], [Cost and Usage Report。詳細請求データ],
  [DAX], [DynamoDB Accelerator。インメモリキャッシュ],
  [DDoS], [Distributed Denial of Service。Shield で対策],
  [DLM], [Data Lifecycle Manager。EBS スナップショット自動化],
  [DLQ], [Dead Letter Queue。失敗メッセージ退避],
  [DMS], [Database Migration Service],
  [DNSSEC], [DNS Security Extensions。DNS 改ざん対策],
  [DR], [Disaster Recovery],
  [DRT], [DDoS Response Team（Shield Advanced）],
  [DynamoDB], [マネージド NoSQL（KVS / ドキュメント）],
  [EBS], [Elastic Block Store。永続ブロックストレージ],
  [EC2], [Elastic Compute Cloud。仮想マシン],
  [ECR], [Elastic Container Registry],
  [ECS], [Elastic Container Service],
  [EDP], [Enterprise Discount Program],
  [EFA], [Elastic Fabric Adapter。HPC 向け低レイテンシ NIC],
  [EFS], [Elastic File System。NFS 共有ファイルシステム],
  [EIP], [Elastic IP。固定パブリック IPv4],
  [EKS], [Elastic Kubernetes Service],
  [EMF], [Embedded Metric Format。CloudWatch Logs から派生メトリクス生成],
  [EMR], [Elastic MapReduce。Hadoop / Spark 等のクラスタ],
  [ENA], [Elastic Network Adapter。新世代インスタンスの高速 NIC],
  [ENI], [Elastic Network Interface],
  [EOL], [End of Life],
  [Event-driven], [イベント駆動アーキテクチャ],
  [EventBridge], [サーバーレスイベントバス],
  [Fargate], [サーバーレスコンテナ実行環境],
  [FedRAMP], [米連邦政府クラウドセキュリティ基準],
  [FinOps], [クラウド財務管理],
  [FISC], [日本の金融機関向け安全対策基準],
  [FM], [Foundation Model。基盤モデル（Bedrock）],
  [FSx], [マネージドファイルシステム（Windows/Lustre/OpenZFS/ONTAP）],
  [GDPR], [一般データ保護規則（EU）],
  [GovCloud], [米政府向け AWS 専用リージョン],
  [Graviton], [AWS の ARM プロセッサ],
  [GSI], [Global Secondary Index（DynamoDB）],
  [GuardDuty], [脅威検知サービス],
  [Guardrails], [Bedrock の安全フィルタ],
  [HCP], [HashiCorp Cloud Platform],
  [HIPAA], [医療情報保護法（米）],
  [HSM], [Hardware Security Module],
  [IaaS], [Infrastructure as a Service],
  [IaC], [Infrastructure as Code],
  [IAM], [Identity and Access Management],
  [Identity Center], [IAM Identity Center。SSO アイデンティティ基盤],
  [IGW], [Internet Gateway],
  [IMDSv2], [Instance Metadata Service v2。トークン必須の安全版],
  [Inferentia], [AWS の推論専用チップ],
  [Inspector], [脆弱性スキャナ],
  [IRSA], [IAM Roles for Service Accounts（EKS）],
  [Iceberg], [Apache Iceberg。S3 上のテーブルフォーマット],
  [JWT], [JSON Web Token],
  [Karpenter], [EKS のノードオートスケーラ],
  [KCL], [Kinesis Client Library],
  [KMS], [Key Management Service],
  [KNN], [k-Nearest Neighbors。OpenSearch のベクトル検索],
  [KPI], [Key Performance Indicator],
  [KPL], [Kinesis Producer Library],
  [Lake Formation], [データレイクのアクセス制御],
  [Lambda], [サーバーレス関数実行],
  [Lambda\@Edge], [CloudFront エッジで Lambda 実行],
  [LCU], [Load Balancer Capacity Unit。ALB の課金単位],
  [LSI], [Local Secondary Index（DynamoDB）],
  [Macie], [S3 の機密データ発見],
  [MACsec], [L2 暗号化（Direct Connect）],
  [MFA], [Multi-Factor Authentication],
  [MGN], [Application Migration Service。サーバ移行],
  [Move], [Snowball Move（旧 Snowmobile）],
  [MSK], [Managed Streaming for Kafka],
  [MWAA], [Managed Workflows for Apache Airflow],
  [NACL], [Network Access Control List],
  [NAT], [Network Address Translation],
  [NIST], [米国立標準技術研究所],
  [NLB], [Network Load Balancer],
  [NoSQL], [非リレーショナル DB（DynamoDB 等）],
  [OAC], [Origin Access Control（CloudFront）],
  [OAI], [Origin Access Identity（旧、OAC に置換）],
  [OCU], [OpenSearch Compute Unit],
  [OIDC], [OpenID Connect],
  [OOM], [Out Of Memory],
  [OpenSearch], [Elasticsearch フォークの全文検索エンジン],
  [OpenTelemetry], [計装の OSS 標準],
  [Organizations], [マルチアカウント管理],
  [Outposts], [自社 DC に置く AWS インフラ],
  [PaaS], [Platform as a Service],
  [PCI DSS], [カード業界セキュリティ基準],
  [PEM], [証明書フォーマット],
  [PHI], [Protected Health Information],
  [PII], [Personally Identifiable Information],
  [PITR], [Point-in-Time Recovery],
  [PoP], [Point of Presence。CloudFront のエッジロケーション],
  [PowerTools], [Lambda Powertools。サーバーレス運用ライブラリ],
  [Prometheus], [メトリクス収集 OSS],
  [Provisioned], [事前確保（DynamoDB / Concurrency 等）],
  [PrivateLink], [VPC 間のプライベート接続],
  [QA], [Quality Assurance],
  [Q（Amazon Q）], [生成 AI アシスタント],
  [Q in Connect], [コンタクトセンター用 Q],
  [Q Developer], [開発者向け Q（旧 CodeWhisperer）],
  [Q Business], [社内検索 Q],
  [QuickSight], [BI / ダッシュボード],
  [RAG], [Retrieval-Augmented Generation],
  [RAM], [Resource Access Manager],
  [RBAC], [Role-Based Access Control],
  [RCU / WCU], [DynamoDB のキャパシティ単位],
  [RDS], [Relational Database Service],
  [Redshift], [DWH（列指向 MPP）],
  [Region], [リージョン。地理的データセンター群],
  [Rekognition], [画像・動画認識],
  [RIs], [Reserved Instances],
  [RPO / RTO], [Recovery Point/Time Objective],
  [RUM], [Real-User Monitoring（CloudWatch RUM）],
  [SaaS], [Software as a Service],
  [SAA], [Solutions Architect Associate（資格）],
  [SAM], [Serverless Application Model],
  [SAP], [Solutions Architect Professional（資格）/ SAP（システム）],
  [SCP], [Service Control Policy],
  [SCT], [Schema Conversion Tool],
  [SDK], [Software Development Kit],
  [SES], [Simple Email Service],
  [SG], [Security Group],
  [SLI / SLO / SLA], [Service Level Indicator/Objective/Agreement],
  [SMS], [Server Migration Service（MGN に統合進行）],
  [SnapStart], [Lambda の起動高速化],
  [SNS], [Simple Notification Service],
  [SOA], [SysOps Administrator Associate（資格）],
  [Spot], [Spot Instance。割安だが中断あり],
  [SQS], [Simple Queue Service],
  [SSE-S3 / SSE-KMS], [S3 のサーバーサイド暗号化方式],
  [SSM], [Systems Manager],
  [SSO], [Single Sign-On],
  [STS], [Security Token Service],
  [Step Functions], [サーバーレスワークフロー],
  [TGW], [Transit Gateway],
  [Trainium], [AWS の ML 訓練専用チップ],
  [Transfer Family], [SFTP/FTPS/AS2 マネージド],
  [Trusted Advisor], [リソース最適化推奨],
  [TTL], [Time To Live],
  [UDP], [User Datagram Protocol],
  [VPC], [Virtual Private Cloud],
  [VPC Lattice], [サービス層ネットワーキング],
  [VPN], [Virtual Private Network],
  [WAF], [Web Application Firewall],
  [WAR], [Well-Architected Review],
  [Wavelength], [5G エッジコンピューティング],
  [WORM], [Write Once Read Many。改ざん不能ストレージ],
  [Workspaces], [マネージド仮想デスクトップ],
  [X-Ray], [分散トレーシング],
  [Zero-ETL], [ETL 不要の自動データレプリケーション],
)

== 五十音順（カタカナ・日本語）

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*用語*], [*説明*]),
  [アクセスキー], [長期認証情報。なるべく避ける],
  [一括請求], [Organizations 管理アカウントへの請求集約],
  [インスタンスストア], [EC2 のローカル NVMe SSD（揮発性）],
  [インスタンスタイプ], [EC2 の CPU/メモリ等の規格],
  [インスタンスプロファイル], [EC2 に IAM ロールを付与する仕組み],
  [エッジロケーション], [CloudFront / Route 53 の世界中の配信拠点],
  [オリジン], [CloudFront のコンテンツ取得元（S3 / ALB 等）],
  [可用性], [Availability。サービスが利用可能な割合],
  [カナリアデプロイ], [小割合トラフィックで新版を段階公開],
  [強整合性 / 結果整合性], [DynamoDB / S3 の読み取り保証レベル],
  [権限境界], [Permissions Boundary。IAM 権限の上限],
  [サブネット], [VPC を分割した IP 範囲（AZ 単位）],
  [シャード], [DynamoDB / Kinesis の分散単位],
  [スタンバイ], [Multi-AZ の待機系インスタンス],
  [責任共有モデル], [AWS と利用者のセキュリティ責任分担],
  [セッションマネージャ], [SSM 経由の安全なシェル接続],
  [セキュリティグループ], [ENI 単位のステートフル FW],
  [タグ], [リソースに付ける Key/Value メタデータ],
  [テンプレート], [CloudFormation の YAML / JSON],
  [トークン], [STS の一時認証情報や JWT などの認証文字列],
  [トポロジー], [ネットワーク構成],
  [認証], [Authentication（誰か）],
  [認可], [Authorization（何ができるか）],
  [ヘルスチェック], [リソース健全性確認],
  [ボールト], [AWS Backup の保存先],
  [ポリシー], [JSON ベースの許可・拒否ルール],
  [マネジメントコンソール], [AWS の Web UI],
  [リーダー], [Aurora の読み取り専用インスタンス],
  [リーダブルスタンバイ], [Multi-AZ DB Cluster の読み取り可スタンバイ],
  [ライター], [Aurora の書き込み可インスタンス],
  [リソースベースポリシー], [リソース側に貼るポリシー],
  [ルートユーザー], [AWS アカウント開設者。日常使用禁止],
  [レプリカ], [複製インスタンス（Read Replica など）],
  [ロール], [一時的に引き受けるアイデンティティ],
  [ローリングアップデート], [段階的にインスタンス入れ替え],
  [ワークスペース], [Terraform の論理分離単位 / WorkSpaces サービス],
)

== 略語一覧（早見）

```
ABAC  Attribute-Based Access Control
ACM   AWS Certificate Manager
ACU   Aurora Capacity Unit
ADOT  AWS Distro for OpenTelemetry
ALB   Application Load Balancer
AMI   Amazon Machine Image
APN   AWS Partner Network
ARN   Amazon Resource Name
ASG   Auto Scaling Group
AZ    Availability Zone
BCP   Business Continuity Plan
CAF   Cloud Adoption Framework
CDK   Cloud Development Kit
CDN   Content Delivery Network
CIDR  Classless Inter-Domain Routing
CMK   Customer Managed Key
CSPM  Cloud Security Posture Management
CUR   Cost and Usage Report
DAX   DynamoDB Accelerator
DDoS  Distributed Denial of Service
DLM   Data Lifecycle Manager
DLQ   Dead Letter Queue
DMS   Database Migration Service
DR    Disaster Recovery
EBS   Elastic Block Store
EC2   Elastic Compute Cloud
ECR   Elastic Container Registry
ECS   Elastic Container Service
EDP   Enterprise Discount Program
EFS   Elastic File System
EIP   Elastic IP
EKS   Elastic Kubernetes Service
ENA   Elastic Network Adapter
ENI   Elastic Network Interface
FaaS  Function as a Service
FedRAMP Federal Risk and Authorization Management Program
FM    Foundation Model
GDPR  General Data Protection Regulation
GSI   Global Secondary Index
HSM   Hardware Security Module
IaaS  Infrastructure as a Service
IaC   Infrastructure as Code
IAM   Identity and Access Management
IGW   Internet Gateway
IMDS  Instance Metadata Service
KMS   Key Management Service
KNN   k-Nearest Neighbors
LCU   Load Balancer Capacity Unit
LSI   Local Secondary Index
MFA   Multi-Factor Authentication
MGN   Application Migration Service
MSK   Managed Streaming for Kafka
NACL  Network Access Control List
NAT   Network Address Translation
NLB   Network Load Balancer
OAC   Origin Access Control
OIDC  OpenID Connect
PaaS  Platform as a Service
PCI DSS Payment Card Industry Data Security Standard
PHI   Protected Health Information
PII   Personally Identifiable Information
PITR  Point-in-Time Recovery
RAG   Retrieval-Augmented Generation
RAM   Resource Access Manager
RBAC  Role-Based Access Control
RCU   Read Capacity Unit
RDS   Relational Database Service
RI    Reserved Instance
RPO   Recovery Point Objective
RTO   Recovery Time Objective
SaaS  Software as a Service
SCP   Service Control Policy
SDK   Software Development Kit
SES   Simple Email Service
SG    Security Group
SLI/SLO/SLA Service Level Indicator/Objective/Agreement
SNS   Simple Notification Service
SQS   Simple Queue Service
SSE   Server-Side Encryption
SSM   Systems Manager
SSO   Single Sign-On
STS   Security Token Service
TGW   Transit Gateway
TTL   Time To Live
VPC   Virtual Private Cloud
VPN   Virtual Private Network
WAF   Web Application Firewall
WCU   Write Capacity Unit
WORM  Write Once Read Many
```

== 本書からのキーワード索引（部分）

主要章とキーワードの対応：

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*章*], [*キーワード*]),
  [01 はじめに], [責任共有モデル、リージョン、AZ、Free Tier、Free Plan],
  [02 アカウント開設], [ルートユーザー、MFA passkey、IAM Identity Center、Budgets],
  [03 IAM], [ユーザー、ロール、ポリシー、ABAC、Permissions Boundary、Access Analyzer],
  [04 VPC], [CIDR、サブネット、IGW、NAT Gateway、SG、NACL、VPC エンドポイント],
  [05 EC2], [AMI、インスタンスタイプ、EBS、IMDSv2、SSM Session Manager、ASG],
  [06 S3], [バケット、Block Public Access、SSE-S3、Lifecycle、バージョニング、CloudFront+OAC],
  [07 DB], [RDS、Aurora、DynamoDB、ElastiCache、Multi-AZ、PITR],
  [08 コンテナ・サーバーレス], [Lambda、API GW、ECS、EKS、Fargate、App Runner],
  [09 運用], [CloudWatch、CloudTrail、Config、Systems Manager],
  [10 セキュリティ・コスト], [GuardDuty、Inspector、KMS、Budgets、SCP],
  [11 IaC], [CloudFormation、CDK、Terraform、運用Tips],
  [〜36], [各サービス深掘り、ハンズオン、DR、WAF、認定資格],
  [37〜49], [生成AI、IaC詳細、CI/CD、SaaS、性能、コスト、業界別],
)

== 参考リンク

本書執筆に主に参照した公式ソース：

- AWS Documentation：`docs.aws.amazon.com`
- AWS What's New：`aws.amazon.com/new/`
- AWS Well-Architected：`aws.amazon.com/architecture/well-architected/`
- AWS Architecture Center：`aws.amazon.com/architecture/`
- AWS Pricing：`aws.amazon.com/pricing/`
- AWS Solutions Library：`aws.amazon.com/solutions/`
- AWS Skill Builder：`skillbuilder.aws/`
- AWS Blog：`aws.amazon.com/blogs/`
- AWS GitHub Samples：`github.com/aws-samples`

すべて 2026年4月時点の最新情報に基づく。AWS のサービスは頻繁に更新されるため、最新は必ず公式を参照のこと。
