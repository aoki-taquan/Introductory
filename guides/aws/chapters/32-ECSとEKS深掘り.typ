= ECS と EKS 深掘り

8章でコンテナ系の概要を扱った。本章では ECS / EKS / Fargate の本格運用に必要な知識を深掘りする。タスク・サービス・ネットワーキング・スケーリング・セキュリティ・監視・トラブルシュート。

== ECS と EKS の選び方再考

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*基準*], [*推奨*]),
  [AWS だけで完結 / シンプルさ重視], [ECS],
  [Kubernetes エコシステム必要], [EKS],
  [複数クラウド・移植性重視], [EKS],
  [運用人員少ない], [ECS],
  [CD ツール・operator 多用], [EKS],
  [サーバ管理ゼロ], [いずれも Fargate],
  [GPU・特殊計算], [EKS（Karpenter + GPU AMI）],
)

== ECS の本格運用

=== クラスタ／サービス／タスク

```
[Cluster]
 └ [Service-A]
    ├ Task-A1 (replica)
    ├ Task-A2 (replica)
    └ Task Definition で定義
 └ [Service-B]
    └ Task-B1
```

- *タスク定義*：1〜複数コンテナ、CPU/メモリ、IAM ロール、ネットワークモード、ボリューム
- *サービス*：タスク定義のレプリカを *N 個維持*、ELB 連携、Auto Scaling
- *タスク*：実行中のコンテナグループ。スタンドアロンでも実行可

=== タスク定義のキー要素

```json
{
  "family": "web",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "1024",
  "memory": "2048",
  "executionRoleArn": "arn:aws:iam::...:role/ecsTaskExecutionRole",
  "taskRoleArn": "arn:aws:iam::...:role/ecsTaskRole",
  "runtimePlatform": {
    "cpuArchitecture": "ARM64",
    "operatingSystemFamily": "LINUX"
  },
  "containerDefinitions": [{
    "name": "app",
    "image": "123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/app:v1.0",
    "essential": true,
    "portMappings": [{ "containerPort": 8080, "protocol": "tcp" }],
    "environment": [{ "name": "ENV", "value": "prod" }],
    "secrets": [{ "name": "DB_PASS", "valueFrom": "arn:aws:secretsmanager:..." }],
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "/ecs/web",
        "awslogs-region": "ap-northeast-1",
        "awslogs-stream-prefix": "web",
        "awslogs-create-group": "true"
      }
    },
    "healthCheck": {
      "command": ["CMD-SHELL", "curl -f http://localhost:8080/health || exit 1"],
      "interval": 30, "timeout": 5, "retries": 3, "startPeriod": 60
    }
  }]
}
```

=== executionRoleArn vs taskRoleArn

- *executionRoleArn*：ECS サービス自体が ECR pull・CloudWatch Logs 書き込み・Secrets 取得に使う
- *taskRoleArn*：タスク内のアプリケーションコードが AWS API を呼ぶときの権限

混同しやすい。アプリ側に S3 書き込み権限が要るなら *taskRoleArn* に付ける。

=== ネットワークモード

- *awsvpc*：タスクごとに ENI を割当（Fargate は必須）。SG をタスク単位で
- *bridge*：従来 Docker のブリッジネットワーク（EC2 のみ）
- *host*：ホストのネットワークを直接（EC2 のみ、ポート競合注意）

== サービス・ロードバランシング

ALB / NLB と統合。サービス更新時に新タスクを起動・古いを停止する *デプロイ* が走る。

=== デプロイ戦略

- *Rolling*（標準）：`minimumHealthyPercent` / `maximumPercent` で段階更新
- *Blue/Green*（CodeDeploy 統合）：Blue（旧）/ Green（新）で切替、ロールバック容易
- *External*：自前のオーケストレーション

=== Service Discovery

- *AWS Cloud Map*：サービス名 → タスク IP の DNS 解決
- *Service Connect*：Envoy ベースの新統合方式（推奨）。HTTP/2、retry、observability

```yaml
# Service Connect の設定例（タスク定義 + サービス）
serviceConnectConfiguration:
  enabled: true
  namespace: prod
  services:
    - portName: web
      clientAliases:
        - port: 80
```

== Auto Scaling

=== Service Auto Scaling

タスク数を自動増減。

- *Target Tracking*：CPU 70%、メモリ 70%、ALB Request Count Per Target など
- *Step Scaling*：閾値段階的
- *Scheduled*：時刻ベース

=== Cluster Capacity Provider

EC2 起動タイプの場合、ノード台数を *タスク需要に応じて* 自動調整。

- *FARGATE / FARGATE_SPOT*：完全マネージド
- *EC2 ASG*：自前の ASG をキャパシティプロバイダ化

=== Fargate Spot

Fargate でも Spot 価格が利用可能（最大 70% 割引）。中断耐性のあるワークロード（バッチ、ステートレス Web の冗長部分）で。

== EKS の基本

=== クラスタ構成

```
[EKS Control Plane]   AWS マネージド、SLA 99.95%
       ↓
[Worker Node]
 ├ Managed Node Group     EC2 Auto Scaling、AWS が更新管理
 ├ Self-Managed Node      自前 EC2、フルコントロール
 └ Fargate                サーバーレス、Pod 単位
```

クラスタは VPC に紐付く。コントロールプレーンとワーカーノードは ENI で接続。

=== Add-ons

- *VPC CNI*：Pod に VPC IP を直接割当
- *CoreDNS*：クラスタ内 DNS
- *kube-proxy*
- *EBS CSI / EFS CSI / FSx CSI*：永続ボリューム
- *Pod Identity Agent*：IRSA の後継（後述）
- *AWS Load Balancer Controller*：Ingress → ALB、Service → NLB

=== EKS Auto Mode（2024年末〜）

ノード管理・スケーリング・パッチ・ストレージ・ロードバランサを *AWS が自動運用* するモード。Karpenter / VPC CNI / EBS CSI / LB Controller 等が組み込み済みで *マネージド*。EKS の運用負荷を ECS Fargate 並みに。

=== Karpenter

ノードオートスケーラー。Pod の要求に合わせて *最適なインスタンスタイプを自動選定* し、Spot とオンデマンドを混合。Cluster Autoscaler の後継。

```yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: default
spec:
  template:
    spec:
      requirements:
        - key: kubernetes.io/arch
          operator: In
          values: ["amd64", "arm64"]
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["spot", "on-demand"]
      nodeClassRef:
        group: karpenter.k8s.aws
        kind: EC2NodeClass
        name: default
  limits:
    cpu: "1000"
  disruption:
    consolidationPolicy: WhenEmptyOrUnderutilized
    consolidateAfter: 30s
```

== EKS のセキュリティ

=== IRSA（IAM Roles for Service Accounts）

Pod に IAM ロールを紐付け、AWS API を呼ぶときに *Pod 単位* で権限を絞る。EKS の OIDC プロバイダ経由。

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: my-app
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/my-app-role
```

=== EKS Pod Identity（推奨、2023〜）

IRSA の後継。OIDC プロバイダを使わず *Add-on（Pod Identity Agent）* 経由で IAM ロールを Pod に渡す。設定がシンプル、セットアップ時間が短縮。

=== aws-auth ConfigMap → Access Entries

EKS クラスタへの IAM プリンシパルマッピング。従来は `aws-auth` ConfigMap を編集していたが、現在は *Access Entries API* が推奨。

```bash
aws eks create-access-entry \
  --cluster-name my-cluster \
  --principal-arn arn:aws:iam::...:role/Admin \
  --type STANDARD

aws eks associate-access-policy \
  --cluster-name my-cluster \
  --principal-arn arn:aws:iam::...:role/Admin \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \
  --access-scope type=cluster
```

== Ingress / Service

=== AWS Load Balancer Controller

- *Ingress* リソース → ALB を自動作成
- *Service Type LoadBalancer* → NLB を自動作成
- TargetType `ip`（推奨、Pod IP に直接）または `instance`

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTPS":443}]'
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:...
spec:
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-app
                port: { number: 80 }
```

=== VPC Lattice + EKS

VPC Lattice の Service を EKS の Pod から呼ぶ統合（Gateway API Controller 経由）。Service Mesh の代替に。

== ストレージ

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*種類*], [*用途*]),
  [EBS CSI], [Pod 単一の永続ボリューム（StatefulSet）],
  [EFS CSI], [複数 Pod 共有のファイルシステム],
  [FSx CSI], [Lustre / OpenZFS / NetApp ONTAP],
  [S3 CSI], [S3 をファイルシステムとしてマウント（読み込み中心）],
)

== Service Mesh の選択肢

- *App Mesh*：AWS 純正。Envoy ベース。EKS / ECS / EC2 で動作。新規開発は減速気味
- *Istio*：定番 OSS、機能豊富
- *Linkerd*：軽量・シンプル
- *VPC Lattice*：マネージド、AWS 統合
- *Service Connect*（ECS）：軽量な Service Mesh 代替

複雑な mTLS / トラフィック制御が必要なら Istio、運用負荷下げたいなら VPC Lattice / Service Connect。

== 観測性（Container Insights）

- *Container Insights*：CloudWatch によるコンテナ監視（CPU/メモリ/ネットワーク/タスク数/Pod 数）
- *Container Insights with Enhanced observability*：Prometheus メトリクス自動収集、コスト・パフォーマンス可視化
- *FireLens*：Fluent Bit / Fluentd を使ったログルーティング
- *AWS Distro for OpenTelemetry（ADOT）*：Trace / Metric / Log の統合収集

== セキュリティのベストプラクティス

- *最小権限の Task Role / Pod Role*
- *Secrets Manager / Parameter Store* でシークレット注入
- *ECR の脆弱性スキャン*（Inspector 統合）
- *イメージ署名*（cosign + Notation）
- *Read-only root filesystem*、*Non-root user*
- *Security groups for Pods*（EKS）：Pod 単位 SG
- *Network Policy*（EKS）：Calico / Cilium で東西通信制御
- *Falco*（EKS）：ランタイムセキュリティ
- *IMDSv2 必須化*（ノード）

== コスト最適化

- *Fargate Spot* / *EC2 Spot*
- *Karpenter Consolidation*：未使用ノード自動整理
- *Right-sizing*：Compute Optimizer 推奨を反映
- *Cluster Autoscaler / Karpenter*：必要時のみノード追加
- *CloudWatch Logs 保持期間*
- *Container Insights サンプリング*

== トラブルシューティング

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*症状*], [*対処*]),
  [Task が起動失敗], [`Stopped reason`、IAM、ECR pull、ネットワーク],
  [Pod が `Pending`], [リソース不足（CPU/Mem）、ノード spot 中断、Karpenter ログ],
  [ALB ヘルスチェック失敗], [SG（ALB→Pod ENI）、`/health` 200、target type ip と Pod IP 整合],
  [DNS 解決失敗（EKS）], [CoreDNS Pod 数、ENI 制限、cluster-dns 設定],
  [Pod が IP を取得できない], [VPC CNI の ENI 上限、サブネット IP 枯渇、Custom Networking 検討],
  [ECS Service Connect 通信できない], [namespace、port name、Cloud Map],
  [Karpenter で起動しない], [NodePool 制約、AMI、`Instance not found` ログ],
  [IRSA / Pod Identity が効かない], [Service Account annotation、信頼ポリシー、aws-iam-authenticator バージョン],
  [Container Insights が高い], [サンプリング、Enhanced observability の取捨],
)
