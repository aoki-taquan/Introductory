= IaCと運用Tips

AWS のリソースをコンソールで作ると、*再現性が低く・構成変更の履歴が追えない* という問題が起きる。これを解決するのが Infrastructure as Code（IaC）である。本章では主要 IaC ツールを比較し、最後に運用で知っておきたい Tips と事故回避策をまとめる。

== なぜ IaC が必要か

- *再現性*：同じ構成を別リージョン・別アカウントに何度でも作れる
- *履歴管理*：Git で変更を追える。レビューできる
- *自動化*：CI/CD でデプロイできる
- *ドキュメント*：コード自体が構成の正となる
- *破壊と再構築*：環境を丸ごと作り直せる

個人検証でも IaC を使う最大のメリットは *「まとめて削除」が簡単* な点。コンソールで作ると消し忘れるリソースも、IaC なら `destroy` 一発で片付く。

== CloudFormation

AWS 純正の IaC。YAML / JSON でリソースを宣言する。

=== 基本概念

- *テンプレート*：リソース定義の YAML / JSON
- *スタック*：テンプレートを適用して作られたリソース群
- *スタックセット*：複数アカウント・リージョンに展開するスタック
- *変更セット*：適用前の差分プレビュー

=== 最小テンプレート例

```yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: A single S3 bucket

Parameters:
  BucketName:
    Type: String

Resources:
  MyBucket:
    Type: AWS::S3::Bucket
    Properties:
      BucketName: !Ref BucketName
      VersioningConfiguration:
        Status: Enabled
      PublicAccessBlockConfiguration:
        BlockPublicAcls: true
        BlockPublicPolicy: true
        IgnorePublicAcls: true
        RestrictPublicBuckets: true

Outputs:
  BucketArn:
    Value: !GetAtt MyBucket.Arn
```

=== 適用

```bash
aws cloudformation create-stack \
  --stack-name my-bucket \
  --template-body file://bucket.yaml \
  --parameters ParameterKey=BucketName,ParameterValue=my-bucket-20260421

# 更新
aws cloudformation update-stack \
  --stack-name my-bucket \
  --template-body file://bucket.yaml \
  --parameters ParameterKey=BucketName,ParameterValue=my-bucket-20260421

# 削除
aws cloudformation delete-stack --stack-name my-bucket
```

=== 特徴

- AWS 純正なので新サービス対応が早い
- *IAM 権限がそのまま効く*
- ドリフト検知（実リソースとテンプレートの差分）
- ネイティブ機能としてロールバック
- 反面、YAML の記述量が多くなりがち

=== SAM（Serverless Application Model）

Lambda・API Gateway・DynamoDB を *短い記述* で書ける CloudFormation の拡張。サーバーレス構成に特化。

```yaml
Transform: AWS::Serverless-2016-10-31
Resources:
  HelloApi:
    Type: AWS::Serverless::Function
    Properties:
      Runtime: python3.12
      Handler: app.handler
      CodeUri: ./src
      Events:
        Api:
          Type: HttpApi
          Properties:
            Path: /hello
            Method: get
```

== AWS CDK（Cloud Development Kit）

*CDK* は、TypeScript / Python / Java / Go / C\# などの *プログラミング言語* でクラウド構成を書くツール。裏では CloudFormation テンプレートを生成する。

=== 特徴

- 条件分岐・ループ・ヘルパー関数などを自然に書ける
- *Construct* による抽象化（「Web サービス一式」を1行で書く、のような）
- 型補完が効く
- エコシステム（L2 / L3 Construct、Community Constructs）が豊富

=== TypeScript での例

```typescript
import { Stack, StackProps, RemovalPolicy } from 'aws-cdk-lib';
import { Bucket, BucketEncryption, BlockPublicAccess } from 'aws-cdk-lib/aws-s3';
import { Construct } from 'constructs';

export class MyStack extends Stack {
  constructor(scope: Construct, id: string, props?: StackProps) {
    super(scope, id, props);

    new Bucket(this, 'MyBucket', {
      versioned: true,
      encryption: BucketEncryption.S3_MANAGED,
      blockPublicAccess: BlockPublicAccess.BLOCK_ALL,
      removalPolicy: RemovalPolicy.DESTROY,
    });
  }
}
```

=== デプロイフロー

```bash
cdk init app --language typescript
cdk bootstrap                 # 初回のみ、CDK 用の土台を作る
cdk synth                     # CloudFormation YAML を生成
cdk diff                      # 差分プレビュー
cdk deploy
cdk destroy
```

=== CloudFormation との使い分け

- プログラマビリティが欲しい、テストを書きたい → CDK
- YAML で宣言的に書きたい、純 AWS で揃えたい → CloudFormation / SAM

新規プロジェクトなら CDK を第一候補に挙げる開発者が増えている。

== Terraform

HashiCorp が提供する *マルチクラウド対応* の IaC ツール。AWS に限定されないため、オンプレや他クラウドと混在する環境で強い。

=== 特徴

- HCL（HashiCorp Configuration Language）で記述
- *プロバイダ* を差し替えれば AWS / GCP / Azure / Kubernetes / SaaS もまとめて扱える
- *state ファイル* が現実のリソースとコードの対応表になる（S3 + DynamoDB でリモート保存）
- OSS 版と HCP Terraform（旧 Terraform Cloud）あり
- ライセンス変更後のフォークとして *OpenTofu* も選択肢

=== 例

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket         = "tfstate-20260421"
    key            = "my-app/terraform.tfstate"
    region         = "ap-northeast-1"
    dynamodb_table = "tfstate-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = "ap-northeast-1"
}

resource "aws_s3_bucket" "app" {
  bucket = "my-bucket-20260421"
}

resource "aws_s3_bucket_versioning" "app" {
  bucket = aws_s3_bucket.app.id
  versioning_configuration {
    status = "Enabled"
  }
}
```

=== コマンド

```bash
terraform init    # プロバイダと backend を初期化
terraform plan    # 差分確認
terraform apply   # 適用
terraform destroy # 削除
terraform fmt     # 整形
terraform validate
```

=== state 管理の注意

- *state ファイルには機密情報が含まれる*（パスワードや ARN など）ので、S3 リモート backend を使う
- *state の手編集は避ける*（`terraform import` / `state rm` を使う）
- 複数人・CI で運用するなら *排他ロック* は必須。Terraform 1.10 以降は `backend "s3"` に `use_lockfile = true` を指定することで *S3 ネイティブのロック* が GA（DynamoDB テーブル不要）。それ以前の構成では従来通り `dynamodb_table` でロックを取る

== IaC ツール選びのガイドライン

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*状況*], [*おすすめ*]),
  [AWS 純度重視・小規模], [CloudFormation / SAM],
  [サーバーレスだけを素早く], [SAM または CDK],
  [プログラマビリティ重視・型安全に書きたい], [CDK],
  [マルチクラウド・オンプレ混在], [Terraform / OpenTofu],
  [既存チームが Terraform に慣れている], [Terraform],
  [K8s マニフェストも同一ツールで], [Terraform + Helm プロバイダ or Pulumi],
)

どれか1つに決める必要はなく、*チームと用途に合わせて併用* するのが現実解。CDK で AWS 基盤を作り、Kubernetes 上のアプリは Helm で運用、といった構成はよくある。

== 運用 Tips とハマりどころ

=== リージョン設定の一貫性

コンソールの右上リージョンは *ブラウザのタブごとに独立* する。スタックを削除したつもりで別リージョンを見ていた、という事故がよくある。IaC を使えばリージョンは明示的にコードで指定されるため、この種の事故が防げる。

=== 名前衝突の回避

- S3 バケット名、CloudFront、Route 53 レコードはグローバル一意
- IAM ロール名、Lambda 関数名、セキュリティグループ名はアカウント＋リージョン内一意
- *環境サフィックス*（`-prod`、`-dev`）を入れる／乱数を付与する

=== 削除できないリソース

- S3 バケットが空でない → 全バージョン削除が必要
- RDS に *削除保護*（Deletion Protection）がかかっている → 無効化してから
- VPC を消したいのにできない → ENI や EIP がどこかで紐づいている
- IAM ロールにサービスが紐づいたままになっている

「消すときのコスト」を IaC で下げる意味は大きい。

=== マルチアカウント設計

個人でも *検証専用の子アカウント* を作るのを推奨する。

- 実験で事故ってもメインのアカウントに影響しない
- 課金を明確に分離できる
- 検証が終わったらアカウントごと閉鎖できる

Organizations + Control Tower で楽に構築できる。

=== CI/CD での認証

GitHub Actions / GitLab CI から AWS を操作するときは、*アクセスキーを置かずに OIDC で AssumeRole* する。手順：

+ IAM で OIDC プロバイダ（`token.actions.githubusercontent.com`）を登録
+ 引き受け可能なロールを作成、信頼ポリシーで対象リポジトリを制限
+ Workflow で `aws-actions/configure-aws-credentials@v4` を使い、`role-to-assume` を指定

この方式なら、万一リポジトリが公開されても長期キーが漏れる心配がない。

=== よくある事故と回避

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*事故*], [*回避策*]),
  [NAT Gateway 立てっぱなしで月数千円], [検証終了時に `destroy`、または平日だけ稼働する IaC],
  [Elastic IP 放置で課金], [未使用の EIP を自動検知する Lambda を設置],
  [S3 バケットを誤って公開], [ブロックパブリックアクセス、Access Analyzer、Config ルール],
  [ルートユーザー漏洩], [MFA 必須、Organizations で使用を制限、CloudTrail で即時通知],
  [リージョン間違いで不要リソース増殖], [SCP で使えるリージョンを限定],
  [CloudWatch Logs が無限に増える], [ロググループごとに保持期間を必ず設定],
  [想定外の無料枠超過], [Billing Preferences で Free Tier アラート有効化],
  [IAM 権限不足で急な障害], [IAM Access Analyzer Policy Generator で必要権限を算出],
)

=== リソース棚卸しの習慣

月1回、以下を確認する。

- *Cost Explorer* で前月比の急増がないか
- 全リージョンで *EC2 の停止インスタンス*、*未使用の EBS*、*未使用の EIP* を点検
- *停止した RDS*（自動再起動でコストが戻る）
- *放置された CloudFormation スタック* や *Terraform state*
- *IAM ユーザーの未使用アクセスキー*

Trusted Advisor（Basic プランでも一部利用可）を見ると、上記の多くが自動リスト化される。

== さらに学ぶために

- *AWS Well-Architected Framework*：運用・セキュリティ・信頼性・パフォーマンス・コスト・持続可能性の6本柱で AWS 構成をレビューする公式フレームワーク
- *AWS Skill Builder*：公式の学習プラットフォーム。無料コースだけでもかなりの量
- *AWS Certified Cloud Practitioner（CLF）／Solutions Architect Associate（SAA）*：資格勉強は体系学習の最短コース
- *AWS ブログ／What's New*：新サービス・アップデートのキャッチアップ
- 各サービスの *公式ドキュメント*：情報の正は常にドキュメント。ブログや本は補助

本書は「広く浅く」で全体像を掴むためのものである。実運用では、各サービスのドキュメントをあたり、Well-Architected の柱ごとにチェックしていく姿勢が長期的に効く。
