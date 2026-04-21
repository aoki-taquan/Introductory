= Terraform 詳細

Terraform / OpenTofu は AWS だけでなく、マルチクラウド・SaaS・自社プロビジョニング全般に使える IaC の事実上標準。本章では state 管理、モジュール、ワークフロー、テスト、組織運用までを深掘りする。

== Terraform vs OpenTofu

2023年8月、HashiCorp が Terraform を BSL（Business Source License）に変更したのを契機に、コミュニティが OpenTofu としてフォーク。

#table(
  columns: (1fr, 1fr, 1fr),
  align: left,
  table.header([*項目*], [*Terraform*], [*OpenTofu*]),
  [ライセンス], [BSL（商用制約）], [MPL 2.0（OSS）],
  [機能], [HashiCorp 拡張あり], [OSS のみ + 独自拡張],
  [互換], [v1.5 まで OpenTofu と互換], [v1.6 以降は分岐],
  [HCP / Cloud], [HashiCorp Cloud Platform], [—（独自にどうぞ）],
  [State 暗号化], [—], [v1.7+ で State 暗号化機能],
  [Provider], [HashiCorp 公式 + コミュニティ], [Terraform Registry も利用可],
)

新規プロジェクトは要件次第。OpenTofu は OSS 純度・将来性、Terraform は HCP 統合・成熟度。

== 基本構造

```
my-project/
├ main.tf
├ variables.tf
├ outputs.tf
├ versions.tf
├ terraform.tfvars
├ modules/
│  ├ vpc/
│  └ alb/
└ environments/
   ├ dev/
   └ prod/
```

```hcl
# versions.tf
terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.70" }
  }
  backend "s3" {
    bucket       = "my-tfstate"
    key          = "myapp/terraform.tfstate"
    region       = "ap-northeast-1"
    use_lockfile = true     # Terraform 1.10+ S3 ネイティブロック
    encrypt      = true
  }
}

provider "aws" {
  region = "ap-northeast-1"
  default_tags {
    tags = {
      Project     = "myapp"
      Environment = var.env
      ManagedBy   = "terraform"
    }
  }
}
```

== State 管理

=== Local backend vs Remote backend

- *Local*：`terraform.tfstate` をローカルに置く。個人検証のみ
- *Remote*：S3 / HCP / Consul / Postgres 等。複数人 / CI 必須

=== S3 backend + ロック

Terraform 1.10 以降、S3 ネイティブロック（`use_lockfile = true`）が GA。それ以前は DynamoDB テーブルを併用していた。

```hcl
backend "s3" {
  bucket         = "tfstate-prod"
  key            = "network/terraform.tfstate"
  region         = "ap-northeast-1"
  use_lockfile   = true      # 1.10+ 推奨
  # 旧形式（1.9以前）：
  # dynamodb_table = "tfstate-lock"
  encrypt        = true
  kms_key_id     = "arn:aws:kms:..."
}
```

=== State の論理分割

サービス・チーム・環境ごとに State を分けるのが鉄則。

- *環境分離*：`dev / staging / prod` で別 State
- *レイヤ分離*：network / data / compute / app
- *ライフサイクル分離*：頻繁に変わるもの vs 静的なもの

```
S3 backend keys:
  network/dev/terraform.tfstate
  network/prod/terraform.tfstate
  app/api/dev/terraform.tfstate
  app/api/prod/terraform.tfstate
```

=== State 操作（注意して使う）

```bash
terraform state list
terraform state show aws_s3_bucket.app
terraform state mv aws_s3_bucket.app aws_s3_bucket.legacy
terraform state rm aws_s3_bucket.legacy        # state からのみ削除（実体は残る）
terraform state pull > backup.tfstate
terraform import aws_s3_bucket.app my-bucket  # 既存リソースを state に取り込み
```

=== Workspace

```bash
terraform workspace new dev
terraform workspace select prod
```

State を `terraform.tfstate.d/<workspace>/` に分離。シンプルな環境分けに使えるが、*複雑な環境差異には不向き*。ディレクトリ分離 + 別 State の方が保守しやすい。

== モジュール

`modules/<name>/{main.tf,variables.tf,outputs.tf}` の構造。

=== 呼び出し

```hcl
module "vpc" {
  source = "./modules/vpc"
  cidr   = "10.0.0.0/16"
  azs    = ["ap-northeast-1a", "ap-northeast-1c"]
}
```

=== Source の種類

- ローカル：`./modules/vpc`
- Git：`git::https://example.com/modules.git//vpc?ref=v1.2.3`
- Terraform Registry：`terraform-aws-modules/vpc/aws`
- S3 / GCS：`s3::https://s3-...`

=== コミュニティモジュール

`terraform-aws-modules/*` が定番。

```hcl
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"
  name = "my-vpc"
  cidr = "10.0.0.0/16"
  azs              = ["ap-northeast-1a", "ap-northeast-1c"]
  private_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets   = ["10.0.101.0/24", "10.0.102.0/24"]
  enable_nat_gateway = true
}
```

実装の手間を大幅に削減。バージョン pin が重要。

=== 自社モジュールの設計指針

- *Single Responsibility*：1モジュール = 1責務
- *最小限の Variable*：不要なオプション乱発しない
- *Default 値* で使いやすく
- *Output* で必要な属性を公開
- *バージョニング*：Git tag で管理
- *README と examples ディレクトリ*：使い方を必ず添える

== Provider

```hcl
provider "aws" {
  region = "ap-northeast-1"
  alias  = "tokyo"
}

provider "aws" {
  region = "us-east-1"
  alias  = "us-east"   # CloudFront / ACM 用
}

resource "aws_acm_certificate" "cf" {
  provider = aws.us-east
  ...
}
```

複数リージョン・複数アカウントを1 State で扱う場合に。

=== Cross-account（Assume Role）

```hcl
provider "aws" {
  region = "ap-northeast-1"
  assume_role {
    role_arn     = "arn:aws:iam::123456789012:role/TerraformRole"
    session_name = "terraform"
  }
}
```

== ワークフロー

=== コマンド一覧

```bash
terraform init       # provider / module / backend 初期化
terraform fmt        # コード整形
terraform validate   # 構文チェック
terraform plan       # 差分プレビュー
terraform apply      # 適用
terraform destroy    # 全削除
terraform output     # Outputs 表示
terraform refresh    # 実リソースから state 更新（plan に統合済み）
terraform taint      # リソースを再作成対象にマーク（非推奨、state replace に置換）
```

=== Plan / Apply の本格運用

```bash
terraform plan -out=plan.tfplan
terraform apply plan.tfplan
```

`-out` で plan 結果を保存し、Apply 時にそれを再利用。CI/CD で *レビュー後の plan を厳密に適用* するパターン。

== CI/CD 統合

=== GitHub Actions（OIDC + Plan/Apply）

```yaml
name: terraform
on:
  pull_request:
  push: { branches: [main] }
permissions:
  id-token: write
  contents: read
  pull-requests: write
jobs:
  plan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-terraform@v3
        with: { terraform_version: 1.10.0 }
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::...:role/github-tf
          aws-region: ap-northeast-1
      - run: terraform init
      - run: terraform plan -out=plan.tfplan
      - uses: actions/upload-artifact@v4
        with: { name: tfplan, path: plan.tfplan }

  apply:
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    needs: plan
    runs-on: ubuntu-latest
    environment: prod
    steps:
      - uses: actions/checkout@v4
      - uses: actions/download-artifact@v4
        with: { name: tfplan }
      - uses: hashicorp/setup-terraform@v3
      - uses: aws-actions/configure-aws-credentials@v4
        with: { role-to-assume: arn:aws:iam::...:role/github-tf, aws-region: ap-northeast-1 }
      - run: terraform init
      - run: terraform apply plan.tfplan
```

`environment: prod` で GitHub の承認待ちを挟める。

=== HCP Terraform / Terraform Enterprise

HashiCorp 公式の SaaS / オンプレ管理。State 管理、Plan/Apply 自動化、コスト見積、Sentinel ポリシー、Variables / Workspaces 管理を統合提供。

=== Atlantis / OpenTofu のコミュニティツール

PR ごとに `atlantis plan` でコメント、承認後に `atlantis apply`。OSS で自前運用可。

== テスト

=== `terraform test`（v1.6+）

```hcl
# tests/vpc.tftest.hcl
run "create_vpc" {
  command = plan

  variables {
    cidr = "10.0.0.0/16"
  }

  assert {
    condition     = aws_vpc.this.cidr_block == "10.0.0.0/16"
    error_message = "CIDR mismatch"
  }
}
```

= Terratest（Go ベース）

実 AWS にデプロイして E2E テスト。本格的な検証に。

== Drift と State の整合

=== Drift Detection

```bash
terraform plan -refresh-only
```

実環境と state の差分を確認（リソース更新は加えない）。手動変更を検知。

=== State Refresh と Lock

`terraform refresh` は内部的に呼ばれる。State Lock がかかる（DynamoDB / S3 lockfile）ので、複数同時実行は安全。

== セキュリティ

- *State に機密情報が含まれる*：S3 + KMS 暗号化、IAM で読み取り権限を絞る
- *Provider credentials*：環境変数 / IAM Role / OIDC、ハードコード禁止
- *秘密の入力*：Variables の `sensitive = true`、HCP Variables、Vault との統合
- *tfsec / checkov / trivy / OPA / Sentinel*：静的解析でセキュリティ違反検知

```bash
tfsec .
checkov -d .
```

== コスト

- *Infracost*：Plan からコスト見積
- HCP Terraform にも統合あり

```bash
infracost breakdown --path .
```

PR ごとに「この変更で月 +\$120」のような表示が可能。

== 高度な機能

=== Dynamic Block

```hcl
resource "aws_security_group" "app" {
  name = "app"
  vpc_id = var.vpc_id

  dynamic "ingress" {
    for_each = var.allowed_ports
    content {
      from_port   = ingress.value.port
      to_port     = ingress.value.port
      protocol    = "tcp"
      cidr_blocks = ingress.value.cidrs
    }
  }
}
```

=== for_each / count

```hcl
resource "aws_subnet" "public" {
  for_each = toset(var.azs)
  vpc_id            = aws_vpc.this.id
  availability_zone = each.value
  cidr_block        = cidrsubnet(var.cidr, 8, index(var.azs, each.value))
}
```

`for_each` は *map / set*、`count` は *number*。`for_each` の方が安全（リソースが Move しても影響少）。

=== Locals / Functions

```hcl
locals {
  common_tags = {
    Environment = var.env
    Project     = "myapp"
  }
  azs = data.aws_availability_zones.available.names
}
```

=== Data Source

```hcl
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}
```

実環境を *読み取って* 使う。`aws_caller_identity`、`aws_region`、`aws_iam_policy_document` などが頻出。

=== Lifecycle

```hcl
resource "aws_db_instance" "this" {
  # ...
  lifecycle {
    prevent_destroy       = true             # 削除を防ぐ
    create_before_destroy = true             # 置き換え時、新を先に作る
    ignore_changes        = [password]       # 指定属性の変更を無視
  }
}
```

== 組織運用パターン

=== Mono-repo vs Multi-repo

- *Mono-repo*：すべての IaC を1リポジトリ。検索性高、変更影響を一元把握
- *Multi-repo*：チーム / サービス単位で分離。権限・CI/CD を独立化

=== ディレクトリ構造の典型

```
infra/
├ modules/                  共通モジュール
├ live/
│  ├ network/
│  │  ├ dev/
│  │  └ prod/
│  ├ data/
│  └ apps/
│     ├ web/
│     │  ├ dev/
│     │  └ prod/
│     └ batch/
└ tools/                    スクリプト・helper
```

`live/<layer>/<env>/` の各ディレクトリが *独立した State*。

=== Terragrunt

Terraform のラッパー。DRY 化（重複削減）と環境別設定の管理を強化。

```hcl
# terragrunt.hcl
remote_state {
  backend = "s3"
  config = {
    bucket = "tfstate-${get_aws_account_id()}"
    key    = "${path_relative_to_include()}/terraform.tfstate"
    region = "ap-northeast-1"
  }
}
```

`run-all` で全環境一括実行も可。組織が大きくなるなら検討。

== AWS Provider のヒント

- *リソース名は API 名* を意識（`aws_instance` → `RunInstances`）
- *バージョン pin* は `~> 5.70` のように厳密に
- *Default Tags*（provider レベル）でタグ漏れ防止
- *Aliases* でマルチリージョン
- *新サービスはリリース直後 Provider が遅れることがある*

== よくあるトラブル

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*症状*], [*対処*]),
  [State Lock 失敗], [DynamoDB / S3 lockfile 確認、`terraform force-unlock`（慎重に）],
  [Plan が大量変更を出す], [Provider バージョン違い、refresh 結果、手動変更],
  [Apply が AccessDenied], [IAM ロール、Assume Role、KMS 鍵権限],
  [Cycle error], [リソース間の循環依存、間に depends\_on を整理],
  [既存リソースを取り込みたい], [`terraform import`、新形式の `import {}` ブロック (v1.5+)],
  [State 破損], [S3 versioning でロールバック、定期バックアップ習慣],
  [for\_each で order 変わる], [集合型なので順序保証なし、index/key を安定化],
  [モジュール更新で破壊的変更], [バージョン pin、changelog 確認、staging で検証],
)
