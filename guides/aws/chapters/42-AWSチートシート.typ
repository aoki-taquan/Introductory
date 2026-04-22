= AWS チートシート

本書の最終資料章として、実務で頻出する数字・ID・コマンド・コンソールの場所を *早見表* としてまとめる。本書を辞書的に使うときの索引としても活用できる。

== リージョンコード

#table(
  columns: (1fr, 1fr, 1fr),
  align: left,
  table.header([*リージョン*], [*コード*], [*主な用途*]),
  [東京], [ap-northeast-1], [国内サービス標準],
  [大阪], [ap-northeast-3], [国内 DR],
  [ソウル], [ap-northeast-2], [日韓ビジネス],
  [シンガポール], [ap-southeast-1], [東南アジア],
  [シドニー], [ap-southeast-2], [豪州],
  [ジャカルタ], [ap-southeast-3], [opt-in 必要],
  [ムンバイ], [ap-south-1], [インド],
  [バージニア北部], [us-east-1], [新サービス先行・グローバル],
  [オハイオ], [us-east-2], [],
  [オレゴン], [us-west-2], [],
  [N. カリフォルニア], [us-west-1], [],
  [アイルランド], [eu-west-1], [欧州標準],
  [フランクフルト], [eu-central-1], [GDPR 準拠],
  [ロンドン], [eu-west-2], [],
  [パリ], [eu-west-3], [],
  [ストックホルム], [eu-north-1], [],
  [サンパウロ], [sa-east-1], [南米],
  [カナダ中部], [ca-central-1], [],
  [中国（北京）], [cn-north-1], [Sinnet 運営、別アカウント],
  [中国（寧夏）], [cn-northwest-1], [NWCD 運営、別アカウント],
  [GovCloud (US-East/West)], [us-gov-east-1 / us-gov-west-1], [米国政府向け、別アカウント],
)

== AWS 主要サービス価格感（東京、目安）

価格は変動するため *2026年4月時点の目安*。最新は公式 Pricing で要確認。

=== EC2

#table(
  columns: (1fr, 1fr, 1fr),
  align: left,
  table.header([*インスタンス*], [*オンデマンド/時*], [*月額（24/7）*]),
  [t3.nano], [\$0.0068], [\$5],
  [t3.micro], [\$0.0136], [\$10],
  [t3.small], [\$0.0272], [\$20],
  [t3.medium], [\$0.0544], [\$40],
  [t3.large], [\$0.1088], [\$80],
  [m7i.large], [\$0.124], [\$90],
  [m7g.large (Graviton)], [\$0.1088], [\$80],
  [c7i.xlarge], [\$0.245], [\$180],
  [r7i.large], [\$0.182], [\$133],
)

Savings Plans 1年で約 30%、3年で約 50% 引き。

=== ストレージ・ネットワーク

#table(
  columns: (1fr, 1fr),
  align: left,
  table.header([*項目*], [*料金（月、東京）*]),
  [EBS gp3], [\$0.096/GB],
  [EBS gp2], [\$0.12/GB],
  [EFS Standard], [\$0.36/GB],
  [S3 Standard], [\$0.025/GB],
  [S3 Standard-IA], [\$0.0138/GB + アクセス料],
  [S3 Glacier Deep Archive], [\$0.002/GB],
  [パブリック IPv4], [\$0.005/時 (約 \$3.6/月)],
  [Elastic IP（未使用）], [\$0.005/時],
  [NAT Gateway], [\$0.062/時 + \$0.062/GB],
  [ALB], [\$0.0243/時 + LCU],
  [NLB], [\$0.0243/時 + NLCU],
  [CloudFront データ転送], [\$0.114/GB（最初の 10TB）],
  [インターネットへの送信], [\$0.114/GB（最初の 10TB）],
  [Route 53 ホストゾーン], [\$0.50/月],
  [Route 53 クエリ], [\$0.40/100万],
)

=== サーバーレス

#table(
  columns: (1fr, 1fr),
  align: left,
  table.header([*項目*], [*料金*]),
  [Lambda リクエスト], [\$0.20/100万],
  [Lambda 実行 (x86)], [\$0.0000166667/GB秒],
  [Lambda 実行 (ARM/Graviton)], [\$0.0000133334/GB秒],
  [Lambda Free Tier], [月100万リクエスト・40万GB秒（永続）],
  [API Gateway HTTP API], [\$1.00/100万リクエスト],
  [API Gateway REST API], [\$3.50/100万リクエスト],
  [DynamoDB On-Demand 書込], [\$1.4221/100万 WRU],
  [DynamoDB On-Demand 読込], [\$0.2845/100万 RRU],
  [DynamoDB ストレージ], [\$0.285/GB-月],
  [Step Functions Standard], [\$0.025/1,000 ステート遷移],
  [Step Functions Express], [\$1/100万リクエスト + 実行時間],
)

=== AI / ML

#table(
  columns: (1fr, 1fr),
  align: left,
  table.header([*項目*], [*料金（目安）*]),
  [Bedrock Claude Sonnet (input)], [\$3/100万トークン],
  [Bedrock Claude Sonnet (output)], [\$15/100万トークン],
  [Bedrock Claude Haiku (input)], [\$0.25/100万トークン],
  [Bedrock Nova Pro (input)], [\$0.80/100万トークン],
  [Bedrock Titan Embeddings v2], [\$0.02/100万トークン],
  [SageMaker ml.m5.large], [\$0.115/時],
  [OpenSearch Serverless OCU], [\$0.24/時/OCU（最低 4 OCU）],
  [Rekognition 画像分析], [\$0.001/画像（最初の 100万）],
  [Translate], [\$15/100万文字],
  [Transcribe], [\$0.024/分],
)

== 主要 ARN フォーマット

```
arn:aws:s3:::my-bucket
arn:aws:s3:::my-bucket/path/to/key
arn:aws:ec2:ap-northeast-1:123456789012:instance/i-0abcd1234
arn:aws:ec2:ap-northeast-1:123456789012:vpc/vpc-0abcd1234
arn:aws:iam::123456789012:user/alice
arn:aws:iam::123456789012:role/MyRole
arn:aws:iam::aws:policy/AdministratorAccess
arn:aws:lambda:ap-northeast-1:123456789012:function:my-fn
arn:aws:lambda:ap-northeast-1:123456789012:function:my-fn:1
arn:aws:dynamodb:ap-northeast-1:123456789012:table/my-table
arn:aws:rds:ap-northeast-1:123456789012:db:my-db
arn:aws:sns:ap-northeast-1:123456789012:my-topic
arn:aws:sqs:ap-northeast-1:123456789012:my-queue
arn:aws:secretsmanager:ap-northeast-1:123456789012:secret:my-secret-AbCdEf
arn:aws:kms:ap-northeast-1:123456789012:key/12345678-1234-1234-1234-123456789012
arn:aws:bedrock:ap-northeast-1:123456789012:inference-profile/apac.anthropic.claude-sonnet-4-6-v1:0
```

== 必須リソースの上限値（クォータ）

#table(
  columns: (1fr, 1fr),
  align: left,
  table.header([*項目*], [*デフォルト上限*]),
  [VPC 数 / リージョン], [5],
  [サブネット数 / VPC], [200],
  [SG 数 / リージョン], [2,500],
  [SG ルール / SG], [60 / 60（in/out）],
  [SG / ENI], [5（per ENI）],
  [Elastic IP / リージョン], [5],
  [EC2 vCPU / オンデマンド (Standard)], [リージョンごとに異なる、申請必要],
  [Lambda 同時実行], [1,000（アカウント・リージョン、緩和可）],
  [Lambda ENV変数 合計], [4 KB],
  [Lambda 実行時間], [15 分（900 秒）],
  [Lambda メモリ], [128 MB 〜 10,240 MB（10 GB）],
  [DynamoDB テーブル / リージョン], [2,500],
  [API Gateway API / リージョン], [600],
  [S3 バケット / アカウント], [10,000（デフォルト、2024/11〜。申請で最大 100 万）],
  [CloudFormation スタック / リージョン], [2,000],
  [スタック内リソース], [500],
  [ALB / リージョン], [50],
  [Cognito User Pool / リージョン], [1,000],
  [IAM ユーザー / アカウント], [5,000],
  [IAM ロール / アカウント], [1,000],
  [IAM 管理ポリシー / アカウント], [1,500],
)

緩和は Service Quotas コンソールから申請可。

== AWS CLI チートシート

```bash
# 認証情報の確認
aws sts get-caller-identity
aws configure list

# プロファイル指定
aws s3 ls --profile dev
export AWS_PROFILE=dev

# リージョン指定
aws ec2 describe-instances --region ap-northeast-1
export AWS_REGION=ap-northeast-1

# 出力フォーマット
aws ec2 describe-instances --output json
aws ec2 describe-instances --output table
aws ec2 describe-instances --output text
aws ec2 describe-instances --query 'Reservations[].Instances[].InstanceId'

# ページング自動・無効
aws ec2 describe-instances --no-paginate
aws ec2 describe-instances --max-items 10

# Identity Center ログイン
aws configure sso
aws sso login --profile dev

# CloudShell
aws cloudshell  # コンソールから
```

=== よく使うコマンド

```bash
# S3
aws s3 ls
aws s3 cp file.txt s3://bucket/
aws s3 sync ./dist s3://bucket/site/ --delete
aws s3 rm s3://bucket/key

# EC2
aws ec2 describe-instances
aws ec2 start-instances --instance-ids i-0abc
aws ec2 stop-instances --instance-ids i-0abc
aws ec2 terminate-instances --instance-ids i-0abc
aws ec2 modify-instance-metadata-options --instance-id i-0abc --http-tokens required

# IAM
aws iam list-users
aws iam list-roles
aws iam get-role --role-name MyRole
aws iam list-attached-role-policies --role-name MyRole

# Lambda
aws lambda list-functions
aws lambda invoke --function-name my-fn --payload '{}' /tmp/out.json
aws lambda update-function-code --function-name my-fn --zip-file fileb://func.zip

# DynamoDB
aws dynamodb scan --table-name my-table --max-items 10
aws dynamodb get-item --table-name my-table --key '{"id":{"S":"1"}}'
aws dynamodb put-item --table-name my-table --item '{"id":{"S":"1"},"name":{"S":"a"}}'

# CloudWatch Logs
aws logs tail /aws/lambda/my-fn --follow
aws logs filter-log-events --log-group-name /aws/lambda/my-fn --filter-pattern ERROR
aws logs start-query --log-group-name /aws/lambda/my-fn --start-time ... --end-time ... --query-string "fields @timestamp, @message | filter @message like /ERROR/"

# SSM
aws ssm start-session --target i-0abc
aws ssm get-parameter --name /myapp/db_password --with-decryption
aws ssm put-parameter --name /myapp/x --type String --value "hello"

# CloudFormation / CDK
aws cloudformation describe-stacks --stack-name my-stack
aws cloudformation describe-stack-events --stack-name my-stack
aws cloudformation delete-stack --stack-name my-stack
npx cdk deploy
npx cdk diff
npx cdk destroy

# Cost
aws ce get-cost-and-usage --time-period Start=2026-04-01,End=2026-04-30 --granularity MONTHLY --metrics UnblendedCost
```

== コンソールの「どこにあるか」早見表

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*やりたいこと*], [*場所*]),
  [請求情報], [右上アカウント名 → Billing and Cost Management],
  [予算アラート設定], [Billing → Budgets],
  [Free Tier 確認], [Billing → Free Tier],
  [サポートケース], [右上の \? → AWS Support],
  [リソース棚卸し], [Resource Groups → Tag Editor],
  [全リージョンのリソース], [Tag Editor で「すべてのリージョン」],
  [サービス上限緩和], [Service Quotas],
  [新規アカウント作成], [Organizations → アカウント追加],
  [Identity Center ログイン URL], [IAM Identity Center → Settings → User portal URL],
  [自分の ARN], [IAM → Users / 右上ドロップダウン / `aws sts get-caller-identity`],
  [GuardDuty 有効化], [GuardDuty → 有効にする],
  [CloudTrail 履歴], [CloudTrail → イベント履歴],
)

== セキュリティ初期セットアップ チェックリスト

新規アカウント開設時に *最初の30分* で：

- [ ] ルートユーザーに passkey（または ハードウェアキー） MFA
- [ ] ルートユーザーのアクセスキーは作らない／削除
- [ ] AWS Budgets で月次予算アラート（実測80%、予測100%）
- [ ] Free Tier 使用量アラート有効化
- [ ] IAM Identity Center を有効化（または作業用 IAM ユーザー + MFA）
- [ ] CloudTrail 全リージョン有効、S3 に保管、ログファイル整合性検証
- [ ] GuardDuty 全リージョン有効
- [ ] IAM Access Analyzer 有効
- [ ] EBS デフォルト暗号化を全リージョンで ON
- [ ] S3 アカウントレベル Block Public Access ON
- [ ] SCP で利用リージョン制限（東京 + 大阪のみ等）
- [ ] AWS CLI が動作（`aws sts get-caller-identity`）

== トラブルシューティング 早見表

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*症状*], [*まず見るべき場所*]),
  [請求が多い], [Cost Explorer → サービス別 → リージョン別、Cost Anomaly Detection],
  [権限エラー], [CloudTrail → eventName で検索、IAM Policy Simulator],
  [API スロットル], [CloudWatch メトリクス、Service Quotas],
  [DNS が解決しない], [`dig`、Route 53 hosted zone、レジストラ NS],
  [SSL エラー], [ACM 証明書、CloudFront は us-east-1 か],
  [接続できない（EC2/RDS）], [SG、NACL、ルートテーブル、VPC エンドポイント],
  [Lambda がエラー], [CloudWatch Logs `/aws/lambda/<name>`],
  [API Gateway 504], [Lambda タイムアウト 29秒、バックエンド遅延],
  [S3 403], [Block Public Access、バケットポリシー、IAM、署名付き URL],
  [CloudFormation 失敗], [Events タブ、ROLLBACK\_FAILED ステート],
  [request signature mismatch], [時刻同期、AWS\_ACCESS\_KEY\_ID 設定],
)

== Pricing Calculator URL

新サービスや構成変更前に *Pricing Calculator* で見積：

- 公式：`calculator.aws`
- アカウントなしでも使える
- 構成を保存・共有可能
- 月額・年額・3年想定で表示

== 公式ドキュメントの場所

- *General Reference*：`docs.aws.amazon.com/general/latest/gr/`
- *Service Endpoints \& Quotas*：上記内
- *Whitepapers*：`aws.amazon.com/whitepapers/`
- *Architecture Center*：`aws.amazon.com/architecture/`
- *AWS What's New*：`aws.amazon.com/new/`
- *AWS Status*：`status.aws.amazon.com`
- *Blog*：`aws.amazon.com/blogs/`

== 緊急時の連絡先

- *AWS Support*（コンソール内ケース作成）
- *AWS Health Dashboard*：障害情報
- *Trusted Advisor*：Business / Enterprise サポートで全推奨が見える
- *Account Manager*（Enterprise Support 以上）

本章は本書の *最終資料*。本文中で参照するときの索引として活用してほしい。
