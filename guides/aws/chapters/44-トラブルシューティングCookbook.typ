= トラブルシューティング Cookbook

実務でよく遭遇するトラブルと *診断手順* のレシピ集。本書各章の末尾にサービス別 Tips はあるが、本章は *症状別* に横断整理する。

== 診断の基本フロー

どのトラブルも以下の流れ：

+ *症状の特定*：エラーメッセージ、HTTP ステータス、再現手順
+ *影響範囲*：自分だけか、全ユーザーか、特定リソースか
+ *最近の変更*：デプロイ、IAM 変更、設定変更、新規リージョン
+ *ログ確認*：CloudTrail、CloudWatch Logs、アプリログ
+ *メトリクス確認*：CloudWatch、X-Ray、Application Signals
+ *仮説と検証*：小さく試す
+ *修復とドキュメント*：Runbook 化、再発防止

== IAM / 権限エラー

=== `AccessDenied` / `User is not authorized`

CloudTrail でエラー詳細を確認：

```bash
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=Username,AttributeValue=my-user \
  --max-results 10 \
  --query 'Events[*].[EventTime,EventName,ErrorCode,CloudTrailEvent]'
```

エラーメッセージで必要アクションが分かる：

```
User: arn:aws:iam::.../Alice is not authorized to perform:
ec2:TerminateInstances on resource: ...
because no identity-based policy allows the ec2:TerminateInstances action
```

→ Alice に `ec2:TerminateInstances` を付与、または Condition を確認。

=== 明示的 Deny

全 Allow を上書きする `Deny`。SCP、バケットポリシー、IAM Policy をチェック：

```bash
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::...:user/Alice \
  --action-names ec2:TerminateInstances \
  --resource-arns arn:aws:ec2:ap-northeast-1:123456789012:instance/i-0abc
```

Simulator で `implicitDeny` / `explicitDeny` を確認。

=== Assume Role 失敗

- 信頼ポリシーの Principal
- `ExternalId` の一致
- `SourceIdentity` の伝播
- Role Session Tag の競合

=== MFA 必須の Deny

SCP で `aws:MultiFactorAuthPresent` が強制されていると、MFA なし CLI セッションは全操作拒否。

```bash
aws sts get-session-token \
  --serial-number arn:aws:iam::...:mfa/Alice \
  --token-code 123456
# 返ってきた一時認証情報で再試行
```

== ネットワーク接続問題

=== EC2 に SSH できない

チェック順：

+ パブリック IP を持っているか（Public Subnet、`associate_public_ip=true`）
+ SG のインバウンド 22 番が開いているか
+ NACL の許可
+ ルートテーブル（Public Subnet なら IGW、Private なら SSM）
+ SSH 鍵・認証方法
+ OS のファイアウォール（`firewalld` / `ufw`）

*SSM Session Manager* の方が安全で、これらの多くを回避できる。

=== ALB → EC2 でヘルスチェック失敗

- SG（ALB → EC2 のヘルスチェックポート）
- ヘルスチェックパス（例：`/health`）が 200 を返すか
- タスク / アプリが起動猶予期間内に立ち上がるか
- `Cross-Zone Load Balancing`、ENI 設定
- Target Type（`instance` / `ip`）と Pod IP の整合

=== 別 VPC のリソースに到達できない

- VPC Peering / Transit Gateway の接続
- 双方の Route Table エントリ
- 双方の SG / NACL
- *推移的ルーティング*（Peering は非対応、TGW は対応）

=== DNS 解決しない

```bash
dig +short api.example.com
dig @169.254.169.253 api.example.com   # AWS VPC Resolver
```

- Route 53 Hosted Zone のレコード
- VPC 設定（`enableDnsSupport`、`enableDnsHostnames`）
- DNS Firewall でブロック
- オンプレ DNS との統合（Resolver Rule）

== EC2 固有

=== 起動直後に Stopped / Terminated

- インスタンスタイプの *容量枯渇*（別 AZ / 別タイプを試す）
- User Data エラー：`/var/log/cloud-init.log`
- IAM Instance Profile の権限不足
- AMI とインスタンスタイプの *アーキテクチャ不一致*（x86 vs ARM）

=== 起動が `Pending` のまま

- AZ キャパ不足
- EBS 作成遅延
- Subnet の IP 枯渇

=== ディスク容量不足

```bash
df -h
lsblk
sudo growpart /dev/nvme0n1 1
sudo xfs_growfs -d /
```

EBS ボリューム拡張後、OS 側で拡張処理が必要。

== RDS / Aurora

=== 接続できない

- SG（アプリ → DB の 3306 / 5432）
- DB のパブリックアクセス設定
- DB Subnet Group の AZ
- Endpoint が正しいか（Cluster / Instance / Reader）
- パスワード（Secrets Manager ローテーション後ずれ）

=== 遅いクエリ

- *Performance Insights* で Top SQL
- `EXPLAIN ANALYZE`
- インデックス見直し
- 統計情報更新（`VACUUM ANALYZE`）
- ロック・待ち状態

=== Failover で接続切れ

- クラスタエンドポイント使用（DNS 切替追従）
- リトライロジック
- *RDS Proxy* で高速フェイルオーバ

=== Storage Full

- 自動拡張を有効化
- 古いデータ削除
- CloudWatch アラームで事前検知

== Lambda

=== Cold Start が遅い

- SnapStart（対応ランタイム）
- Provisioned Concurrency
- パッケージサイズ削減
- 依存の初期化を lazy に
- ARM 化

=== Timeout

```
Task timed out after 30.00 seconds
```

- Timeout 設定を伸ばす（最大 15 分）
- 外部 API 呼び出しの timeout 設定
- メモリ増で CPU 比例増 → 短縮

=== Throttling

- Reserved Concurrency 設定
- Account 同時実行上限緩和申請
- SQS + Lambda の Maximum Concurrency

=== VPC 内 Lambda が外部に行けない

- NAT Gateway、VPC エンドポイント
- セキュリティグループの egress

=== `Cannot find module`

- Node.js：`node_modules` がパッケージに含まれているか
- Python：`requirements.txt` の依存が bundle されているか
- Layer のバージョン不一致

== S3

=== 403 AccessDenied

優先順位で確認：

+ Block Public Access（アカウント・バケット）
+ バケットポリシー
+ IAM ポリシー
+ Object ACL（非推奨、無効化推奨）
+ KMS キーポリシー
+ VPC エンドポイントポリシー

=== 遅い・スロットル

- Prefix あたり 3,500 PUT / 5,500 GET/秒の上限
- *キー設計*：ホットスポットを避ける
- Transfer Acceleration
- 並列化（マルチパート、複数クライアント）

=== 削除できない

- バージョニング有効時は *全バージョンと DeleteMarker* を削除
- Object Lock（Compliance モードは削除不可）
- バケットポリシーで `s3:Delete*` Deny

=== 料金が想定外

- Cost Explorer で「S3 リクエスト」「データ転送」「ストレージ」を分解
- *不完全マルチパート破片*：ライフサイクル必須
- *非現行バージョン*：ライフサイクル
- *Intelligent-Tiering のモニタリング料*
- *リージョン間レプリケーション*

== DynamoDB

=== スロットル

- On-Demand → 上限に達した、Burst 消費（通常は自動回復）
- Provisioned → RCU/WCU 不足
- *Hot Partition*：PK 設計見直し

=== 書き込み直後に読めない

- Eventually Consistent Read（デフォルト）
- `ConsistentRead=true` で強整合性読み取り
- GSI は常に Eventually Consistent

=== スキャンが遅い・高い

- Scan は *全件走査*
- Query に置き換え（GSI 追加検討）
- Parallel Scan

=== Item サイズ超過

- 400KB 上限
- 大きなフィールドを S3 に移動、参照だけ格納

== CloudFormation / CDK

=== ROLLBACK\_FAILED

- Events タブで失敗理由を特定
- 手動で依存リソース削除後、`continue-update-rollback`
- 最悪は *手動で delete\-stack*（リソース残存）

=== Circular dependency

- リソース同士が相互参照
- 片方を別スタックに分離、または `depends_on` で順序解決

=== Custom Resource で Stuck

- Lambda がタイムアウト前に SUCCESS/FAILED 返す必要
- CloudFormation Response URL にポスト失敗

=== Drift 大量

- 手動変更を IaC に取り込み
- SCP で手動操作禁止
- `cdk deploy` で同期

== コンテナ（ECS/EKS）

=== Task が Stopped

- `stoppedReason` を確認
- ECR pull 失敗（権限・ネットワーク）
- コンテナ即死（ヘルスチェック）
- メモリ OOM

=== Pod が Pending

```bash
kubectl describe pod <name>
```

- ノードリソース不足（CPU/Mem）
- Selector / Taint / Toleration 不整合
- ENI 上限（VPC CNI）

=== DNS / 通信不能（EKS）

- CoreDNS Pod の健全性
- `nslookup`, `dig` でテスト
- `VPC CNI` の設定、ENI 上限

=== IRSA / Pod Identity 失敗

- ServiceAccount アノテーション
- OIDC プロバイダ
- 信頼ポリシー
- aws-iam-authenticator / Pod Identity Agent バージョン

== API Gateway

=== 502 / 504

- Lambda タイムアウト（29秒）
- Lambda エラー
- バックエンド（ALB / EC2）エラー

=== CORS エラー

- API Gateway の CORS 設定 + Lambda レスポンスヘッダの両方必要
- Preflight（OPTIONS）が通っているか

=== Throttling 429

- Usage Plan のレート
- アカウント全体上限（10,000 req/s）

== CloudFront

=== 403

- OAC のバケットポリシー未設定
- Origin Path の typo
- 署名付き URL の期限切れ
- WAF で Block

=== 古いコンテンツ

- TTL
- Invalidation 到達待ち（数分）
- ブラウザキャッシュ

=== HTTPS 動かない

- ACM 証明書は us-east-1 か
- ドメイン検証完了か
- CNAME と ACM のドメイン一致

== 認証・Cognito

=== Hosted UI ドメイン取れない

- グローバル一意
- AWS 既存の予約語

=== SAML 連携失敗

- IdP 側の ACS URL、Audience URI
- Attribute Mapping（`https://aws.amazon.com/SAML/Attributes/Role`）
- Claim / Group マッピング

=== `User does not exist`

- サインインフロー（`USER_PASSWORD_AUTH`）が有効化されているか
- ユーザー存在検出設定（セキュリティのため隠す設定）

=== JWT Authorizer 401

- `iss` / `aud` の一致
- JWT の期限切れ
- 署名鍵（JWKS URI）取得

== コスト

=== 想定外の請求

- Cost Explorer → サービス別・リージョン別・タグ別
- Cost Anomaly Detection
- 典型的な原因：NAT Gateway、Elastic IP、CloudWatch Logs、OpenSearch Serverless、停止中インスタンスの EBS

=== 予算アラートが来ない

- Budgets のしきい値設定
- 通知先メール確認
- Free Tier アラート有効化
- SNS 経由 → Chatbot → Slack 連携

== 汎用的な診断ツール

- *AWS Health Dashboard*：AWS 側の障害情報
- *CloudTrail Lake*：SQL で監査ログ検索
- *CloudWatch Logs Insights*：ログ検索
- *X-Ray Service Map*：依存関係の可視化
- *IAM Access Analyzer*：外部公開・未使用アクセス
- *Trusted Advisor*：設定チェック
- *VPC Reachability Analyzer*：ネットワーク経路検証
- *Systems Manager Fleet Manager*：インスタンス状態

== よくある「とりあえず再起動」で直る問題

システム側の一時問題の可能性：

- EC2 System Status Check 失敗 → Retire＋再起動
- CloudFormation STATE\_UNKNOWN → stack events 待つ
- Auto Scaling が追従遅い → 新インスタンス手動起動
- Elastic Beanstalk がストール → 環境を再構築

ただし *根本原因を調査せず再起動で済ませない*。Runbook に記録。

== ポストモーテム文化

重大インシデント後は *非難なしの振り返り* を：

+ *何が起きたか*（時系列）
+ *影響*（ユーザー数、時間、金銭）
+ *根本原因*（5 Whys）
+ *対応*（何をして復旧したか）
+ *再発防止策*（検知強化、設計変更、プロセス改善）

*Blameless*：個人を責めず、システム・プロセスの改善に集中する。Incident Manager の Post-incident analysis 機能を活用。

== 問題解決のマインドセット

- *仮説ドリブン*：「遅い」ではなく「DB 接続が原因と推測」
- *小さく検証*：本番に大改修を入れる前にステージング
- *切り分け*：二分探索的に問題を絞り込む
- *書き残す*：GitHub Issue、Wiki、Runbook に
- *チームに共有*：独自解決で知見を閉じ込めない
- *急ぐ時ほど慎重に*：リカバリで二次災害を起こさない

トラブルシューティングは *技術力 + 冷静さ + 経験知* の総合力。日常から観察し、記録し、共有することで鍛えられる。
