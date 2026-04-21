= ハンズオン2：3層 Web アプリ

24章とは対照的に、本章は *EC2 + ALB + RDS* の古典的な3層構成を Terraform で組み立てる。レガシーアプリの移植や「サーバーレスではないけど運用したい」ケースを想定する。

== ゴール

- *VPC* をマルチ AZ で構築
- *ALB → EC2 (Auto Scaling) → RDS (Aurora MySQL)* の3層
- *踏み台レス* で SSM Session Manager 接続
- 全構成を *Terraform* で管理
- 検証後 `terraform destroy` で完全削除

== 前提

- AWS アカウント（2章）、Terraform 1.10 以上
- AWS CLI v2、`aws sts get-caller-identity` で確認
- 想定所要時間：3〜4時間

== 構成図

```
[Browser]
   ↓ HTTPS
[Route 53] → [ALB (public subnets, multi-AZ)]
              ↓
            [EC2 × 2 (private subnets, ASG)]
              ↓ MySQL
            [Aurora MySQL Cluster (private subnets, Multi-AZ)]

接続用：開発者 → SSM Session Manager → EC2
DB 接続：開発者 → SSM ポートフォワード → RDS
```

== ステップ1：プロジェクト構造

```bash
mkdir -p ~/aws-handson/3tier && cd $_
mkdir -p modules/{vpc,alb,asg,db}
touch main.tf variables.tf outputs.tf versions.tf terraform.tfvars
```

```hcl
# versions.tf
terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.70" }
  }
  backend "s3" {
    bucket       = "my-tfstate-20260421"
    key          = "3tier/terraform.tfstate"
    region       = "ap-northeast-1"
    use_lockfile = true   # Terraform 1.10+ S3 ネイティブロック
    encrypt      = true
  }
}

provider "aws" {
  region = var.region
  default_tags {
    tags = {
      Project     = "3tier-handson"
      Environment = var.env
      ManagedBy   = "terraform"
    }
  }
}
```

```hcl
# variables.tf
variable "region"      { default = "ap-northeast-1" }
variable "env"         { default = "dev" }
variable "vpc_cidr"    { default = "10.20.0.0/16" }
variable "azs"         { default = ["ap-northeast-1a", "ap-northeast-1c"] }
variable "instance_type"  { default = "t3.small" }
variable "db_engine_version" { default = "8.0.mysql_aurora.3.07.1" }
variable "db_instance_class" { default = "db.t4g.medium" }
```

```hcl
# terraform.tfvars
env = "dev"
```

== ステップ2：VPC モジュール

```hcl
# modules/vpc/main.tf
variable "name"     {}
variable "cidr"     {}
variable "azs"      {}

locals {
  public_cidrs   = [cidrsubnet(var.cidr, 8, 0), cidrsubnet(var.cidr, 8, 1)]
  app_cidrs      = [cidrsubnet(var.cidr, 8, 10), cidrsubnet(var.cidr, 8, 11)]
  db_cidrs       = [cidrsubnet(var.cidr, 8, 20), cidrsubnet(var.cidr, 8, 21)]
}

resource "aws_vpc" "this" {
  cidr_block           = var.cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = { Name = "${var.name}-vpc" }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags = { Name = "${var.name}-igw" }
}

resource "aws_subnet" "public" {
  count = length(var.azs)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = local.public_cidrs[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = false
  tags = { Name = "${var.name}-public-${var.azs[count.index]}" }
}

resource "aws_subnet" "app" {
  count = length(var.azs)
  vpc_id            = aws_vpc.this.id
  cidr_block        = local.app_cidrs[count.index]
  availability_zone = var.azs[count.index]
  tags = { Name = "${var.name}-app-${var.azs[count.index]}" }
}

resource "aws_subnet" "db" {
  count = length(var.azs)
  vpc_id            = aws_vpc.this.id
  cidr_block        = local.db_cidrs[count.index]
  availability_zone = var.azs[count.index]
  tags = { Name = "${var.name}-db-${var.azs[count.index]}" }
}

resource "aws_eip" "nat" {
  count = length(var.azs)
  domain = "vpc"
  tags = { Name = "${var.name}-nat-eip-${count.index}" }
}

resource "aws_nat_gateway" "this" {
  count = length(var.azs)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  tags = { Name = "${var.name}-nat-${count.index}" }
  depends_on = [aws_internet_gateway.this]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
  tags = { Name = "${var.name}-rt-public" }
}

resource "aws_route_table_association" "public" {
  count = length(var.azs)
  subnet_id = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "app" {
  count = length(var.azs)
  vpc_id = aws_vpc.this.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this[count.index].id
  }
  tags = { Name = "${var.name}-rt-app-${count.index}" }
}

resource "aws_route_table_association" "app" {
  count = length(var.azs)
  subnet_id = aws_subnet.app[count.index].id
  route_table_id = aws_route_table.app[count.index].id
}

# DB サブネットはインターネット接続不要
resource "aws_route_table" "db" {
  vpc_id = aws_vpc.this.id
  tags = { Name = "${var.name}-rt-db" }
}

resource "aws_route_table_association" "db" {
  count = length(var.azs)
  subnet_id = aws_subnet.db[count.index].id
  route_table_id = aws_route_table.db.id
}

# S3 ゲートウェイエンドポイント（無料）
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${data.aws_region.this.name}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = concat([aws_route_table.app[0].id, aws_route_table.app[1].id, aws_route_table.db.id])
}

data "aws_region" "this" {}

output "vpc_id"       { value = aws_vpc.this.id }
output "public_subnets" { value = aws_subnet.public[*].id }
output "app_subnets"  { value = aws_subnet.app[*].id }
output "db_subnets"   { value = aws_subnet.db[*].id }
```

== ステップ3：ALB モジュール

```hcl
# modules/alb/main.tf
variable "name"      {}
variable "vpc_id"    {}
variable "subnets"   {}

resource "aws_security_group" "alb" {
  name   = "${var.name}-alb-sg"
  vpc_id = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb" "this" {
  name               = "${var.name}-alb"
  load_balancer_type = "application"
  subnets            = var.subnets
  security_groups    = [aws_security_group.alb.id]
}

resource "aws_lb_target_group" "app" {
  name        = "${var.name}-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"
  health_check {
    path                = "/health"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

output "alb_sg_id"        { value = aws_security_group.alb.id }
output "target_group_arn" { value = aws_lb_target_group.app.arn }
output "alb_dns_name"     { value = aws_lb.this.dns_name }
```

== ステップ4：ASG モジュール

```hcl
# modules/asg/main.tf
variable "name"          {}
variable "vpc_id"        {}
variable "subnets"       {}
variable "instance_type" {}
variable "alb_sg_id"     {}
variable "tg_arn"        {}
variable "db_sg_id"      {}

data "aws_ssm_parameter" "ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_security_group" "app" {
  name   = "${var.name}-app-sg"
  vpc_id = var.vpc_id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [var.alb_sg_id]
  }
  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_role" "ec2" {
  name = "${var.name}-ec2-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${var.name}-ec2-profile"
  role = aws_iam_role.ec2.name
}

resource "aws_launch_template" "app" {
  name_prefix   = "${var.name}-lt-"
  image_id      = data.aws_ssm_parameter.ami.value
  instance_type = var.instance_type

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2.name
  }

  metadata_options {
    http_tokens                 = "required"   # IMDSv2 必須
    http_put_response_hop_limit = 2
    http_endpoint               = "enabled"
    instance_metadata_tags      = "enabled"
  }

  network_interfaces {
    security_groups             = [aws_security_group.app.id]
    associate_public_ip_address = false
  }

  user_data = base64encode(<<-EOT
    #!/bin/bash
    dnf update -y
    dnf install -y nginx
    cat > /usr/share/nginx/html/index.html <<EOF
    <h1>Hello from $(hostname)</h1>
    EOF
    cat > /usr/share/nginx/html/health <<EOF
    OK
    EOF
    systemctl enable --now nginx
  EOT
  )

  tag_specifications {
    resource_type = "instance"
    tags = { Name = "${var.name}-app" }
  }
}

resource "aws_autoscaling_group" "app" {
  name                = "${var.name}-asg"
  min_size            = 2
  max_size            = 4
  desired_capacity    = 2
  vpc_zone_identifier = var.subnets
  target_group_arns   = [var.tg_arn]
  health_check_type   = "ELB"
  health_check_grace_period = 60

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.name}-app"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "cpu" {
  name                   = "${var.name}-cpu-policy"
  autoscaling_group_name = aws_autoscaling_group.app.name
  policy_type            = "TargetTrackingScaling"
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 60
  }
}

# DB SG への許可（DB 側で受ける）
resource "aws_security_group_rule" "to_db" {
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  security_group_id        = var.db_sg_id
  source_security_group_id = aws_security_group.app.id
}

output "app_sg_id" { value = aws_security_group.app.id }
```

== ステップ5：DB モジュール

```hcl
# modules/db/main.tf
variable "name"        {}
variable "vpc_id"      {}
variable "subnets"     {}
variable "engine_version" {}
variable "instance_class"  {}

resource "aws_security_group" "db" {
  name   = "${var.name}-db-sg"
  vpc_id = var.vpc_id
  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-dbsg"
  subnet_ids = var.subnets
}

resource "random_password" "master" {
  length  = 24
  special = true
}

resource "aws_secretsmanager_secret" "db" {
  name                    = "${var.name}/db/master"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({
    username = "admin"
    password = random_password.master.result
  })
}

resource "aws_rds_cluster" "this" {
  cluster_identifier   = "${var.name}-aurora"
  engine               = "aurora-mysql"
  engine_version       = var.engine_version
  database_name        = "appdb"
  master_username      = "admin"
  master_password      = random_password.master.result
  db_subnet_group_name = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.db.id]
  storage_encrypted    = true
  skip_final_snapshot  = true
  deletion_protection  = false
  serverlessv2_scaling_configuration {
    min_capacity = 0.5
    max_capacity = 4
  }
}

resource "aws_rds_cluster_instance" "writer" {
  identifier         = "${var.name}-aurora-1"
  cluster_identifier = aws_rds_cluster.this.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.this.engine
  engine_version     = aws_rds_cluster.this.engine_version
}

output "db_sg_id"   { value = aws_security_group.db.id }
output "endpoint"   { value = aws_rds_cluster.this.endpoint }
output "secret_arn" { value = aws_secretsmanager_secret.db.arn }
```

== ステップ6：ルートで配線

```hcl
# main.tf
module "vpc" {
  source = "./modules/vpc"
  name = "${var.env}-3tier"
  cidr = var.vpc_cidr
  azs  = var.azs
}

module "alb" {
  source  = "./modules/alb"
  name    = "${var.env}-3tier"
  vpc_id  = module.vpc.vpc_id
  subnets = module.vpc.public_subnets
}

module "db" {
  source         = "./modules/db"
  name           = "${var.env}-3tier"
  vpc_id         = module.vpc.vpc_id
  subnets        = module.vpc.db_subnets
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class
}

module "asg" {
  source        = "./modules/asg"
  name          = "${var.env}-3tier"
  vpc_id        = module.vpc.vpc_id
  subnets       = module.vpc.app_subnets
  instance_type = var.instance_type
  alb_sg_id     = module.alb.alb_sg_id
  tg_arn        = module.alb.target_group_arn
  db_sg_id      = module.db.db_sg_id
}

# outputs.tf
output "alb_dns" { value = module.alb.alb_dns_name }
output "db_endpoint" { value = module.db.endpoint }
output "db_secret_arn" { value = module.db.secret_arn }
```

== ステップ7：適用

```bash
terraform init
terraform plan
terraform apply -auto-approve
```

`alb_dns` の出力（`xxx.ap-northeast-1.elb.amazonaws.com`）にブラウザでアクセスして「Hello from ip-...」が見えれば成功。

== ステップ8：SSM 接続

EC2 にログインしたい場合：

```bash
aws ssm start-session --target i-0abc123...
```

DB に接続したい場合（手元の端末から）：

```bash
aws ssm start-session \
  --target i-0bastionが必要ならここに（or app EC2 を踏み台にしてもよい） \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters "host=$(terraform output -raw db_endpoint),portNumber=3306,localPortNumber=13306"
```

別タームで：

```bash
SECRET=$(aws secretsmanager get-secret-value --secret-id $(terraform output -raw db_secret_arn) --query SecretString --output text)
PASS=$(echo $SECRET | jq -r .password)
mysql -h 127.0.0.1 -P 13306 -u admin -p$PASS appdb
```

== ステップ9：HTTPS 化

ACM 証明書を *同一リージョン*（ALB 用なので東京）で取得し、ALB リスナーを HTTPS（443）に切替、80 は 443 にリダイレクト。Route 53 Alias で `app.example.com` を ALB に向ける。

```hcl
resource "aws_acm_certificate" "alb" {
  domain_name       = "app.example.com"
  validation_method = "DNS"
}

# ... DNS 検証レコード追加（aws_route53_record）と aws_acm_certificate_validation

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate_validation.alb.certificate_arn
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# 80 → 443 リダイレクト（既存 listener の default_action を redirect に変更）
```

== ステップ10：後片付け

```bash
terraform destroy -auto-approve
```

NAT Gateway があるため、destroy せずに放置すると *月数千円〜数万円* かかる。必ず実行する。

S3 backend の state ファイルは残る（再利用するため）。本当に不要なら手動で削除。

== 学んだこと

- *VPC のマルチ AZ 構築*：パブリック / アプリ / DB の3層サブネット
- *NAT Gateway* と *S3 ゲートウェイエンドポイント* の併用
- *ALB → ASG → EC2* の伝統的構成
- *Aurora Serverless v2* で 0.5 ACU から自動スケール
- *IMDSv2 必須化*、*SSM Session Manager*、*Secrets Manager* で安全運用
- Terraform モジュール構造、S3 ネイティブロック

== 発展課題

- WAF を ALB に紐付け
- Auto Scaling のスケジュールスケーリング（朝起動・夜縮退）
- CloudWatch Synthetics で外形監視
- Aurora にリードレプリカ追加、アプリで Reader/Writer 分割
- CodeDeploy で Blue/Green デプロイ
- Backup でクロスリージョンスナップショット

== トラブルシューティング

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*症状*], [*対処*]),
  [`terraform apply` で AccessDenied], [プロファイル、IAM 権限、ロール Assume],
  [ALB ヘルスチェックが OutOfService], [SG（ALB→EC2 80）、`/health` 200、起動猶予時間],
  [EC2 が起動直後に終了], [User Data エラーを `cloud-init` ログで確認],
  [SSM start-session が失敗], [SSM エージェント、IAM ロール、VPC エンドポイント],
  [DB に接続できない], [SG（App→DB 3306）、Subnet group、Secret パスワード],
  [destroy で詰まる], [S3 バケットの空化、ENI 残存、依存関係の手動解除],
)
