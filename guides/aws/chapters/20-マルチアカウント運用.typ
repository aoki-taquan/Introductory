= マルチアカウント運用

組織で AWS を本格利用するときに必須となる、複数アカウントを束ねた管理基盤を扱う。Organizations / Control Tower / Landing Zone / Resource Access Manager / Account Management API、コスト按分・SCP・委任管理の実例まで踏み込む。

== なぜマルチアカウントか

AWS では *アカウントが最強の隔壁* である。1つのアカウントに何でも詰め込むと、以下の問題が起こる。

- *爆風範囲が大きい*：誤操作で本番が止まる、不正アクセスの被害が全業務に及ぶ
- *コストが混在*：プロジェクトごとの請求按分が困難
- *権限が複雑化*：IAM ポリシーが肥大化、誰が何を触れるか把握できない
- *リソース上限に当たる*：1アカウントの API レート、リソース数に達する
- *監査・コンプライアンス対応が困難*：環境ごとに違う基準を1アカウントで満たすのは現実的でない

これらを解決する基本戦略が *環境・組織単位での分離*。本番／検証／開発／監査用／ログ保管用、といった単位で別アカウントに切り出す。

== AWS Organizations

複数アカウントを束ねる基盤サービス。

=== 基本構造

```
[Management アカウント（Payer / Root）]
├ OU: Security
│  ├ Log Archive アカウント
│  └ Security Tooling アカウント
├ OU: Workloads
│  ├ OU: Prod
│  │  ├ prod-web アカウント
│  │  └ prod-data アカウント
│  └ OU: NonProd
│     ├ dev アカウント
│     └ staging アカウント
├ OU: Sandbox
│  └ sandbox-* アカウント
└ OU: Suspended
   └ 解約予定アカウント
```

=== 主な機能

- *一括請求（Consolidated Billing）*：管理アカウントに支払い集約。ボリューム割引・Savings Plans を組織全体で共有
- *SCP（Service Control Policy）*：OU・アカウント単位で「使えるサービス・API」を制限
- *委任管理者*：セキュリティ系・ネットワーク系サービスを管理アカウント以外で運用可能
- *タグポリシー*：必須タグ・タグ値の強制
- *バックアップポリシー*：AWS Backup の設定を組織レベルで配布
- *AI サービスオプトアウトポリシー*：AI サービスでのデータ利用許可・拒否

=== 管理アカウントの守り方

管理アカウント（旧称 Master）は *最も重要なアカウント*。請求・SCP・組織自体の管理権限を持つ。

- *ワークロードを置かない*：Organizations / 請求 / セキュリティ管理ツールだけ
- *ルートユーザーには passkey 必須、アクセスキーなし*
- *人は IAM Identity Center 経由でしかアクセスしない*
- 緊急用 Break Glass 手順を別途確立（金庫保管の認証情報など）

=== SCP の設計パターン

SCP は *Allow を絞る* のではなく、*禁止事項を明確化* するのに使うのが基本（`FullAWSAccess` をデフォルトで継承し、危険な操作を Deny で塞ぐ）。

```json
// SCP: Sandbox OU の許容リージョン制限
{
  "Version": "2012-10-17",
  "Statement": [{
    "Sid": "DenyOutsideAllowedRegions",
    "Effect": "Deny",
    "NotAction": [
      "iam:*", "sts:*", "support:*", "organizations:*",
      "cloudfront:*", "route53:*", "globalaccelerator:*",
      "waf:*", "wafv2:*", "shield:*", "trustedadvisor:*"
    ],
    "Resource": "*",
    "Condition": {
      "StringNotEquals": {
        "aws:RequestedRegion": ["ap-northeast-1", "ap-northeast-3"]
      }
    }
  }]
}
```

その他典型的な SCP：

- ルートユーザーの利用禁止（`Condition: aws:PrincipalArn = root`）
- 組織から離脱不可（`organizations:LeaveOrganization` の Deny）
- CloudTrail / Config の停止禁止
- Region 制限
- 大型インスタンスタイプの利用制限（`ec2:RunInstances` + Condition）
- *MFA なしでの API 拒否*

=== タグポリシー

組織で必須タグ（Project、Environment、Owner、CostCenter）を強制。違反タグの自動修復は別途。

== Control Tower

*ベストプラクティスに沿った Landing Zone* を自動構築するサービス。

=== Control Tower がやってくれること

- Organizations 有効化
- IAM Identity Center 有効化
- 監査用アカウント・ログアーカイブアカウント自動作成
- CloudTrail / Config を全リージョン・全アカウントで有効化、ログを集約
- 標準 OU（Security / Sandbox など）作成
- *マンダトリーガードレール*（変更不可の SCP）と *推奨ガードレール*

=== Account Factory

新規アカウントを *セルフサービス* で作る仕組み。Service Catalog を使ったり、`AccountFactory CT API` で IaC からプロビジョニングできる。Terraform Cloud と組み合わせる例も多い。

=== AFT（Account Factory for Terraform）

Control Tower と Terraform を統合。新規アカウント作成時に Terraform モジュールが自動実行され、ベースラインを構築。

=== 既存組織への適用

すでに Organizations を運用中でも、Control Tower を「後付け」で有効化できる（Landing Zone 拡張機能）。ただし既存アカウントを Account Factory 管理下にするには Enroll 操作が必要。

== Landing Zone の典型構成

Control Tower を使うかどうかに関わらず、組織レベルでの推奨構成は以下。

```
[管理]                Organizations、請求、SCP
[Identity Center]     人のアクセスポータル
[Log Archive]         CloudTrail / Config / VPC Flow Logs を集約
[Security Tooling]    Security Hub / GuardDuty / Detective の委任管理
[Network Hub]         Transit Gateway / Direct Connect / DNS の中央管理
[Shared Services]     共通 AMI、Service Catalog、Build パイプライン
[Workloads/Prod-*]    本番ワークロードごとに分離
[Workloads/Dev-*]     開発ワークロード
[Sandbox]             個人検証
```

== Resource Access Manager（RAM）

17章で触れた RAM をマルチアカウント文脈で再整理。

=== 共有可能リソース

- *Subnet*（VPC 共有）：中央 VPC を作り、各ワークロードアカウントから Subnet を借りる
- *Transit Gateway*：中央ネットワークアカウントの TGW を全 VPC で共有
- *Resolver Rule / Route 53 Profiles*：DNS 設定の集中管理
- *Glue Database / Table*：データレイクのカタログを共有
- *Aurora Cluster snapshot*、*EBS snapshot*：バックアップを別アカウントへ
- *License Manager License Configuration*

=== VPC 共有の実例

中央ネットワークアカウントで VPC + Subnet を作成 → RAM で各ワークロードアカウントに共有。各ワークロードは「自分の VPC のように」Subnet を見て EC2 / RDS を起動できる。

メリット：

- ネットワーク変更を中央集約
- IP アドレス管理が一元化
- データ転送コストの削減（同一 VPC 内通信になる）

== 委任管理者（Delegated Administrator）

管理アカウントで全部やるとリスクが高いため、サービスごとに *委任管理者アカウント* を指定して運用を委譲する。

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*サービス*], [*委任先（典型）*]),
  [GuardDuty], [Security Tooling],
  [Security Hub], [Security Tooling],
  [Detective], [Security Tooling],
  [Inspector], [Security Tooling],
  [Macie], [Security Tooling],
  [Audit Manager], [Security Tooling],
  [IAM Access Analyzer], [Security Tooling],
  [Config], [Log Archive],
  [CloudTrail（組織証跡）], [Log Archive],
  [Firewall Manager], [Network Hub],
  [Network Manager / Cloud WAN], [Network Hub],
  [License Manager], [License 管理アカウント],
  [Service Catalog], [Shared Services],
  [Cost Optimization Hub], [Finance],
)

委任管理者は管理アカウントから `aws organizations register-delegated-administrator` で指定。

== Account Management API

近年（2023〜2024）追加された API で、*別アカウントの代替連絡先・プライマリ連絡先・地域オプトイン* などを Organizations 越しに管理できる。新規アカウント作成時のメタデータ整備に有用。

=== Region オプトイン

2019年以降の新リージョン（メキシコ、ハイデラバード、ジャカルタ、メルボルン、テルアビブ、UAE、チューリッヒ、スペイン、マラガなど）は *opt-in が必要*。SCP で許可リージョンを絞っているなら、新リージョン追加前に opt-in 解除も検討。

== 集中ロギング

組織内のログを *Log Archive アカウント* に集約する。

=== CloudTrail

組織証跡を作成すると、全アカウント・全リージョンの CloudTrail が *Log Archive アカウントの S3 バケット* に集約される。バケット側でログファイル整合性検証 + ボールトロック。

=== Config

組織アグリゲータで全アカウント・全リージョンの Config レコーダ結果を Log Archive に集約。

=== VPC Flow Logs

各 VPC で Flow Logs を有効化し、共通 S3 バケット（or CloudWatch Logs）へ。Athena で分析。

=== ログのライフサイクル

S3 ライフサイクルで Standard → IA → Glacier → Deep Archive と階層化。法定保存期間（一般に7年）を超えたら自動削除。

== コスト管理（マルチアカウント視点）

=== 一括請求のメリット

- *ボリュームディスカウント*：S3、EC2、データ転送が組織全体の合計使用量で階段適用
- *Savings Plans / Reserved Instance の共有*：余剰分が組織内で再利用される
- *CloudFront の階段料金* も組織合算

=== コスト按分の方法

- *コスト配分タグ（Cost Allocation Tags）*：Project / CostCenter タグを有効化し、Cost Explorer で按分
- *Cost Categories*：複数のディメンション（アカウント・タグ・サービス）で論理的なグループを定義し、レポートやダッシュボードで使う
- *AWS Cost and Usage Report 2.0*：詳細データを S3 に配信、Athena / QuickSight で経営報告

=== Budgets の組織展開

組織レベルで「OU ごとの月次予算」「ワークロードごとの予算」を Budgets に設定し、超過時に SNS / Chatbot で通知。

=== Compute Optimizer

EC2 / Auto Scaling Group / EBS / Lambda / RDS / ECS Fargate に対して *右サイジング推奨* を機械学習で算出。組織レベルで集計可能。

== マルチアカウント自動化

=== StackSets（CloudFormation）

1テンプレートを *複数アカウント・複数リージョン* に展開。Service Managed mode（Organizations 自動連携）と Self Managed mode。

=== CDK Pipelines / Terraform マルチアカウント

CDK Pipelines は Cross-Account Cross-Region デプロイをネイティブサポート。Terraform は `provider` を Assume Role で別アカウントを指定。

=== AWS Config Conformance Pack

組織レベルでセキュリティ標準のルール束を配布。

=== EventBridge クロスアカウント

イベントバス間で別アカウントへイベント転送。「全アカウントの GuardDuty Finding を Security Tooling アカウントに集約」など。

== 委任管理 + 自動化のパターン

```
[管理アカウント]    Organizations + SCP + 請求
       ↓ 委任
[Security Tooling]  GuardDuty / SecurityHub / Inspector / Macie 集約
[Log Archive]       CloudTrail / Config / VPC Flow Logs 集約
[Network Hub]       TGW / 共有 VPC / Direct Connect / Cloud WAN
[Shared Services]   Service Catalog / 共通 AMI / CI/CD パイプライン
[Workloads/Prod]    プロダクション
[Workloads/Dev]     開発
[Sandbox]           個人実験
```

== ベストプラクティスまとめ

- *新規組織は Control Tower で開始* → 自前で Organizations を設定する手間を回避
- *管理アカウントにワークロードを置かない*
- *環境別・チーム別にアカウントを分ける*（粒度はチームの規模次第）
- *SCP はガードレール、IAM ポリシーは細かい権限* と役割分担
- *ログ集約・セキュリティ集約は専用アカウント*
- *タグ戦略を最初に決める*（後から付け回るのは大変）
- *Sandbox を提供* する（個人検証を本番から完全分離）
- *Break Glass 手順* を文書化・演習

== よくある落とし穴

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*問題*], [*対処*]),
  [SCP で全部止めた], [`FullAWSAccess` を継承前提、Deny でガードレール],
  [新規アカウントが裸], [Account Factory + AFT で baseline 自動適用],
  [請求が見えない], [子アカウントの IAM ユーザーに請求アクセス許可が必要],
  [SCP が反映されない], [親 OU から継承、変更後数分待つ、CloudTrail で確認],
  [委任管理者解除で混乱], [Resource を残したまま委任先を変えない、移管手順を踏む],
  [子アカウントを誤って解約], [解約は90日間取り消し可、待機 OU で隔離して放置でも可],
  [リージョン opt-in 漏れ], [新リージョン公開後にチーム周知、SCP 更新],
)
