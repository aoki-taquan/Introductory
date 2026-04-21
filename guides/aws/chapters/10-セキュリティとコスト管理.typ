= セキュリティとコスト管理

AWS は「使ってみる」ハードルは低いが、*放置すると事故になる* 代表例がセキュリティとコストである。本章では、運用を続けるうえで欠かせない両領域のサービスと、運用プラクティスをまとめる。

== セキュリティの全体像

AWS のセキュリティは層状に構成される。

```
[アイデンティティ層]  IAM / Identity Center / MFA / Access Analyzer
[データ層]             KMS / Secrets Manager / S3 暗号化 / EBS 暗号化
[ネットワーク層]       SG / NACL / WAF / Shield / PrivateLink
[検知・監査層]         CloudTrail / Config / GuardDuty / Security Hub
[対応層]               Systems Manager Incident Manager / EventBridge
```

個人検証ではここまで全部整える必要はないが、*本番運用では全レイヤに当たり前の対策を入れる* のが前提である。

== KMS（Key Management Service）

*KMS* は、暗号鍵を管理するマネージドサービス。S3、EBS、RDS、Secrets Manager など多数のサービスが KMS を使って暗号化する。

=== キーの種類

- *AWS マネージドキー*：サービスごとに自動生成される（例：`aws/s3`）。追加料金なし
- *カスタマーマネージドキー（CMK）*：利用者が作成・管理するキー。ローテーション、キーポリシー、IAM ポリシーを細かく制御可能
- *AWS 所有キー*：AWS 内部で完全に隠蔽されているキー

検証やシンプルな用途では AWS マネージドキーで十分。*監査要件や独立した権限管理が必要な場合は CMK* を使う。

=== キーポリシーと IAM

CMK は *キーポリシー*（KMS 鍵自身に付与するリソースベースポリシー）と IAM ポリシーの両方で制御される。鍵作成直後は、キーポリシーに明示的な許可がないと誰も使えなくなる点に注意。

=== エンベロープ暗号化

KMS は *データキー* を生成し、それで実データを暗号化する方式（エンベロープ暗号化）を推奨する。KMS 本体に大きなデータを投げず、データキーだけを守る仕組み。

== Secrets Manager と Parameter Store

=== 使い分け

#table(
  columns: (1fr, 1fr, 1fr),
  align: left,
  table.header([*項目*], [*Parameter Store*], [*Secrets Manager*]),
  [基本料金], [標準は無料], [1秘密あたり月\$0.40],
  [自動ローテーション], [なし], [あり（Lambda 連携）],
  [クロスアカウント共有], [限定], [ネイティブ対応],
  [レプリケーション], [なし], [複数リージョンへ],
  [用途], [設定値・軽い秘密], [DB パスワード等、ローテーションが必要な秘密],
)

個人検証では Parameter Store（SecureString）で十分。本番の DB パスワードなど、*ローテーション運用が必要な秘密情報* は Secrets Manager を使う。

=== DB パスワードのローテーション

Secrets Manager は RDS / Aurora / Redshift / DocumentDB と統合されていて、*ワンクリックで定期的なパスワードローテーション* を設定できる。裏では Lambda が古いパスワードで新しいパスワードを設定し直す。

== WAF と Shield

=== AWS WAF

Web アプリケーションファイアウォール。CloudFront、ALB、API Gateway、App Runner の前段に貼れる。

- *マネージドルール*：AWS・Marketplace ベンダが提供する既製ルールセット
- *レート制限*：特定 IP からの過剰リクエストをブロック
- *Bot Control*：自動化された不正アクセスの検出
- *Geo ブロック*：国単位でアクセス制御

=== Shield / Shield Advanced

- *Shield Standard*：AWS ユーザー全員が無料で利用。L3/L4 の基本 DDoS 対策
- *Shield Advanced*：有償。L7 対策の強化、DDoS Response Team（DRT）、急増課金のクレジット保護

個人利用では Standard で十分。大規模・公開サービスで攻撃リスクが高い場合のみ Advanced を検討。

== GuardDuty / Inspector / Macie / Security Hub

=== GuardDuty

*脅威検知* サービス。CloudTrail、VPC Flow Logs、DNS ログを ML で分析し、不審な動きを検知する。

- Crypto マイニング痕跡、通信先の悪性 IP、IAM キー漏洩の兆候など
- アカウント単位でワンクリック有効化
- 個人検証なら最初の30日間は無料。その後も *月数ドル程度*

*アカウント作成直後に有効化することを強く推奨*。

=== Inspector

脆弱性スキャナ。EC2、ECR、Lambda を対象にパッケージ脆弱性（CVE）を継続検出する。

- EC2 は SSM エージェント経由
- ECR は push 時と定期
- 重大な脆弱性を EventBridge 経由で通知

=== Macie

S3 の *機密データ発見* を行う。個人情報（PII）やクレジットカード番号などのパターンを機械学習で検出。

=== Security Hub

上記のセキュリティ検知を *集約・統合* するハブ。CIS や PCI DSS などのセキュリティ基準に対するスコアも出す。

マルチアカウント環境では、*監査専用アカウントに Security Hub を集約* して組織全体を見るのが一般的。

== IAM Access Analyzer

IAM のリソース共有・外部公開を検出するサービス。

- 外部公開されている S3 バケット、Lambda、ロールを洗い出す
- 想定外のクロスアカウントアクセスを警告
- CloudFormation にポリシー検証機能を組み込める

有効化コストは無料に近く、*アカウント作成直後に ON* にしておくと誤公開事故に早く気づける。

== AWS Organizations と SCP

複数アカウントを運用する場合は *AWS Organizations* が中心になる。

=== 管理構造

```
[管理アカウント (payer)]
 └── OU: Security
      ├── 監査ログ用アカウント
      └── セキュリティツール用アカウント
 └── OU: Workloads
      ├── OU: Prod
      │    └── prod-web アカウント
      └── OU: Dev
           └── dev-sandbox アカウント
```

- 各アカウントは *リソース・権限の隔壁* として機能
- *一括請求*（Consolidated Billing）：親アカウントに支払いを集約
- *Organizations 証跡* で CloudTrail を一括管理

=== SCP（サービスコントロールポリシー）

OU / アカウント単位で、*そもそも使えるサービスや API を制限* する。IAM ポリシーより上位の「絶対の壁」として機能する。

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Deny",
    "Action": "*",
    "Resource": "*",
    "Condition": {
      "StringNotEquals": {
        "aws:RequestedRegion": ["ap-northeast-1", "ap-northeast-3"]
      }
    }
  }]
}
```

このような SCP を付けておけば、*東京・大阪以外のリージョンで誤ってリソースが作られる* 事故を防げる。放置されたリソースがアラートに引っかからず料金が膨らむ、という典型事故の対策になる。

=== Control Tower

新規に組織を作るなら *AWS Control Tower* を使うと、Organizations / IAM Identity Center / ログアーカイブ構成 / ベースラインの SCP が一括で展開される。

== コスト管理サービス

=== AWS Budgets

2章でも触れた *予算アラート*。個人利用で最初に設定するサービス。

- *コスト予算*：月次・四半期・年次の金額上限
- *使用量予算*：EC2 時間、データ転送量など
- *Reservation 予算*：RIや Savings Plans の使用率管理
- アラートはメール・Slack（SNS 経由）・Chatbot

*必ず「予測」ベースのアラートも入れる*。実測が閾値に達してから通知では手遅れになる。

=== Cost Explorer

過去13か月〜（有償で長期）のコスト・使用量を可視化・分析する。

- サービス別・タグ別・リージョン別で集計
- *Savings Plans 推奨* を自動算出
- カスタムレポートの保存、CSV エクスポート

*月初に前月のコストを振り返る習慣* をつけるだけで浪費を大きく減らせる。

=== Cost and Usage Report (CUR)

*CUR 2.0*（または CUR）は、もっと詳細な使用量・料金データを S3 に出すレポート。Athena / QuickSight と組み合わせて経営層向けのダッシュボードを作る用途が多い。

=== Savings Plans と Reserved Instance

- *Compute Savings Plans*：EC2 / Fargate / Lambda 横断。最大66%
- *EC2 Instance Savings Plans*：特定ファミリーに縛る代わりに最大72%
- *Reserved Instance*：旧来の予約。新規は Savings Plans が基本

*安定的に稼働している計算リソースがあるなら、1年コミットだけでもかなり下がる*。

=== Spot Instance

Auto Scaling グループでオンデマンドと Spot を混ぜる、ECS で Fargate Spot を使う、バッチを AWS Batch で Spot に寄せる、といった使い方で大幅にコストが落ちる。中断耐性のあるワークロードから適用する。

=== コスト最適化のチェックリスト

- [ ] Budgets を設定した（実測＋予測）
- [ ] Cost Explorer を月1回見ている
- [ ] 停止した EC2 に紐づく EBS を残していないか
- [ ] 未使用の Elastic IP を解放したか
- [ ] NAT Gateway を検証用に立てっぱなしにしていないか
- [ ] CloudWatch Logs の保持期間を設定したか
- [ ] S3 バケットに Lifecycle ルールを設定したか
- [ ] Savings Plans の推奨を確認したか
- [ ] 全リージョンの「幽霊リソース」を点検したか

== セキュリティ＋コストで最低限やること

個人・小規模でも、*最初の30分で* 以下は終わらせる。

+ ルートユーザーに MFA、アクセスキーなし
+ 作業用 IAM ユーザー or Identity Center を用意
+ Budgets で予算アラート
+ Free Tier 使用量アラート
+ CloudTrail を有効化、S3 に長期保管
+ GuardDuty を有効化
+ IAM Access Analyzer を有効化
+ S3 のデフォルト暗号化をオンに
+ EBS のデフォルト暗号化をオンに
+ 全リージョン向けの SCP（使うのは東京・大阪だけなら他はブロック）

ここまでやっておけば、大事故はほぼ防げる。あとは *月1回の棚卸し* を習慣にする。

== インシデント対応の基礎

セキュリティインシデントが発生した場合の *初動* を定めておく。事前準備が運命を分ける。

=== 初動フロー（想定例）

```
1. 検知（GuardDuty Finding、CloudTrail 異常、ユーザー報告）
     ↓
2. 封じ込め
   - 該当 IAM ユーザー／ロールの権限停止
   - セキュリティグループを「隔離用」に切り替え
   - アクセスキーの即時 rotation
     ↓
3. 影響範囲の調査
   - CloudTrail Lake で対象プリンシパルの全 API を時系列取得
   - Detective でエンティティ関連を辿る
   - Athena で VPC Flow Logs を検索
     ↓
4. 修復
   - 侵害リソースの停止・削除
   - バックアップから復元
   - パッチ適用、設定修正
     ↓
5. 振り返り（Postmortem）
   - 根本原因、時系列、何が効いたか、再発防止策
   - Runbook に追記
```

=== Break Glass 手順

通常の認証経路（Identity Center、IAM Role）が使えない緊急時に備えて：

- *専用 IAM ユーザー*（MFA 必須、アクセスキーなし）を準備
- 認証情報は *物理金庫 or パスワードマネージャの別ボールト*
- 使用時は即座に CloudTrail 通知がチームに飛ぶ設定
- 使用後に即ローテーション・利用記録作成

=== 訓練

Game Day（障害演習）を年2回以上実施。*AWS Fault Injection Service (FIS)* で擬似障害を注入、対応フローを検証。

== コンプライアンス概観

業界・地域で求められる主な規制：

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*規制*], [*対象*]),
  [PCI DSS], [クレジットカード決済],
  [HIPAA], [米国医療情報],
  [GDPR], [EU 個人データ],
  [APPI], [日本個人情報保護法],
  [SOC 1 / 2 / 3], [サービス組織統制],
  [ISO 27001 / 27017 / 27018], [情報セキュリティ],
  [FedRAMP / IRAP], [米・豪政府クラウド],
  [CCPA], [カリフォルニア住民プライバシー],
  [PCI DSS v4], [2024年必須化の新版],
)

AWS は多くの認定を保有。利用者側は *適切な設定と運用* で自社のコンプライアンスを達成する（責任共有）。*Artifact* で AWS のレポート、*Audit Manager* で自社側の証跡収集。

== セキュリティアーキテクチャの原則

- *多層防御*：単一防御に頼らない（IAM + SG + WAF + 暗号化 ...）
- *最小権限*：必要最小限の許可
- *最小爆風範囲*：アカウント・リージョン・VPC で分離
- *ゼロトラスト*：内部も信頼しない、全通信を認証・認可
- *自動化と検出*：手動チェックは続かない
- *不変インフラ*：変更はすべて IaC 経由、踏み台上での変更禁止
- *監査可能性*：誰が何をしたか残す
- *復元可能性*：壊れても戻せる設計

これらを組み合わせて *防御・検知・対応・復旧* の全フェーズを整える。
