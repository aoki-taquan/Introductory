= 運用と監視

AWS で動くシステムを安定運用するには、*メトリクス・ログ・監査・設定・構成管理* の各観点で仕組みを整える必要がある。本章では CloudWatch、CloudTrail、Config、Systems Manager を中心に解説する。

== CloudWatch

*CloudWatch* は AWS の監視基盤である。メトリクス、ログ、アラーム、イベントをまとめて扱う。

=== CloudWatch Metrics

- AWS サービスから *標準メトリクス* が自動的に流れてくる（EC2 の CPU、ELB のリクエスト数など）
- *カスタムメトリクス* をアプリから `PutMetricData` で送れる
- EC2 標準メトリクスは *5分間隔*、*詳細モニタリング* を有効化すると1分間隔。カスタム高解像度メトリクスは最短1秒粒度
- *15か月間保持*（古いほど粗い粒度に丸まる）

=== アラーム

メトリクスに対してしきい値を設定し、違反時にアクションを発動する。

- アクション：SNS 通知（メール、Slack 連携）、Auto Scaling、EC2 停止など
- *複合アラーム*：複数アラームの AND/OR 合成
- *異常検出*：機械学習による動的しきい値

```bash
# CPU 80% 超で通知するアラームの作成例
aws cloudwatch put-metric-alarm \
  --alarm-name web-cpu-high \
  --metric-name CPUUtilization \
  --namespace AWS/EC2 \
  --statistic Average \
  --period 300 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2 \
  --dimensions Name=InstanceId,Value=i-0abc123 \
  --alarm-actions arn:aws:sns:ap-northeast-1:123456789012:ops-alerts
```

=== CloudWatch Logs

サービスやアプリのログを集約する。

- *ロググループ* と *ログストリーム* の2階層
- *保持期間* を明示的に設定しないと無期限（料金が際限なく伸びる）
- 収集源：Lambda（自動）、ECS / EKS のタスク、EC2 の CloudWatch エージェント、VPC Flow Logs 等

=== Logs Insights

CloudWatch Logs への独自クエリ言語。

```
fields @timestamp, @message
| filter @message like /ERROR/
| sort @timestamp desc
| limit 100
```

SQL 的な書き味で、*急な障害解析に強い*。Athena + S3 に流し込む構成にしておくと、長期保管と分析を両立できる。

=== ダッシュボード

メトリクスとログの可視化をカスタマイズできる。1アカウント3ダッシュボードまで無料。

=== CloudWatch Alarms の通知をメール以外に

- SNS → *Chatbot* 経由で Slack / Teams
- SNS → Lambda でカスタムフォーマット
- EventBridge → 任意の AWS アクションに分岐

== CloudTrail

CloudTrail は *「誰が・いつ・何を」の監査ログ* を記録するサービスである。*CloudTrail コンソールの「Event history」では直近90日分の管理イベントが自動で閲覧可能*。ただしこれは *証跡（Trail）そのものではなく、ビュー* に過ぎず、長期保存・S3 保管・検索・通知には次節の証跡を別途作成する必要がある。

=== イベント種別

- *管理イベント*：API 操作（`CreateBucket`、`TerminateInstances` など）
- *データイベント*：S3 の `GetObject` / `PutObject`、Lambda の `Invoke` など高頻度イベント
- *インサイトイベント*：異常な API 呼び出しパターンの検知

=== 証跡（Trail）

長期保存や複数リージョン集約には *証跡* を作成する。

- S3 に保存（推奨はログアーカイブ専用アカウント）
- *ログファイル検証* を有効にして改ざん検知
- CloudWatch Logs へ流して Logs Insights で検索
- EventBridge と組み合わせて重要操作を即時通知

組織全体の監査ログは *Organizations 証跡* で一括管理できる。

=== 主要ログフィールド

- `eventName`、`eventTime`、`sourceIPAddress`
- `userIdentity`（IAMユーザーかロールかルートか、引き受けた経路）
- `userAgent`（AWS CLI、Console、SDK）
- `requestParameters` / `responseElements`

「ルートユーザーからの API が実行されたら即通知」のような監査アラートは、CloudTrail + EventBridge でよく組まれる。

== AWS Config

*AWS Config* は、*リソースの構成変更を時系列で記録し、ルール違反を検知する* サービスである。

- 全リソースの *設定履歴* を S3 / DynamoDB に保存
- *マネージドルール*（例：「S3 バケットが公開されていないこと」「EBS が暗号化されていること」）
- *カスタムルール*（Lambda / Guard DSL で書く）
- *コンフォーマンスパック*：ルールの束（CIS ベンチマーク、PCI DSS など）

=== 典型的な利用シーン

- セキュリティ基準違反の検知（公開 S3、未暗号化 EBS、MFA なしユーザー）
- 構成変更の時系列追跡（「このセキュリティグループはいつ誰が変えた？」）
- コンプライアンスレポートの自動生成

コストは *記録対象リソース数 × 変更回数* で増えるため、マルチアカウント環境では *Config アグリゲータ* で全体可視化と、必要なルールだけ有効化するバランスが重要。

== Systems Manager（SSM）

*AWS Systems Manager* は、EC2 やオンプレサーバの *構成管理・運用自動化* を統合するサービス群である。非常に広いので主要コンポーネントを押さえる。

=== 主要機能

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*コンポーネント*], [*用途*]),
  [Fleet Manager], [インスタンスの一覧管理・インベントリ取得],
  [Session Manager], [ブラウザ／CLI からインスタンスへ安全に接続],
  [Run Command], [複数台にコマンドを一斉実行],
  [Patch Manager], [OS パッチの自動適用],
  [Parameter Store], [設定値・秘密情報の保存（階層型）],
  [State Manager], [定期的に構成をあるべき姿に収束],
  [Automation], [多段の運用タスクを Runbook 化],
  [OpsCenter], [運用インシデントの一元管理],
  [Change Manager], [変更申請・承認ワークフロー],
)

=== Session Manager のメリット

前章の EC2 でも触れたが、*SSH 22 番を閉じたまま* 接続できる現代的な運用の起点になる。

- SSH 鍵管理が不要
- 22 番ポートをセキュリティグループで閉じられる
- すべての操作が CloudTrail に残る
- ポートフォワーディングで RDS やプライベート LB への接続も可能

=== Parameter Store

アプリケーションの設定値や認証情報を階層パスで保存する。

```bash
# パラメータの登録（暗号化）
aws ssm put-parameter \
  --name "/app/prod/db_password" \
  --value "supersecret" \
  --type SecureString

# 取得
aws ssm get-parameter \
  --name "/app/prod/db_password" \
  --with-decryption \
  --query Parameter.Value --output text
```

シンプルな設定値なら Parameter Store、より高機能なローテーションが必要なら *Secrets Manager*（次章で扱う）を使い分ける。

=== Patch Manager

EC2 の OS パッチを定期適用する仕組み。

- *パッチベースライン*（どのパッチを当てるか）
- *メンテナンスウィンドウ*（いつ当てるか）
- *パッチグループ*（どのインスタンスに当てるか）

数台なら手動で十分だが、100台規模になると必須。

== 監視・運用の全体像

AWS 上の典型的な構成では、以下が組み合わさる。

```
[アプリ] → CloudWatch Logs (アプリログ)
         ↓
         メトリクス → CloudWatch Alarms → SNS → Slack/メール
         ↓
         CloudTrail (API監査) → S3 / CloudWatch Logs
         ↓
         Config (構成変更) → S3 / ルール違反検知
```

これらをまとめて俯瞰する上位のサービスも存在する。

- *CloudWatch Application Insights*：自動でアプリの健全性を検出
- *X-Ray*：分散トレーシング
- *Application Signals*：CloudWatch に統合された APM
- *Amazon Managed Grafana / Prometheus*：OSS エコシステムをマネージドで
- *Security Hub*：セキュリティ観点の検知を集約（次章）
- *CloudWatch Synthetics*：外形監視（canary によるエンドツーエンド確認）

== タグ戦略

運用を楽にする最大の投資が *タグ戦略* である。

- *Name*：人間が識別するための名前
- *Environment*：`prod` / `staging` / `dev`
- *Owner*：運用責任者／チーム
- *CostCenter* / *Project*：費用按分用
- *ManagedBy*：`terraform` / `cdk` / `manual`

タグはリソース作成時に付けるのが鉄則。後から入れようとすると数百リソースを見直すことになる。*Organizations のタグポリシー* で必須タグを強制できる。

== アラート疲れを防ぐ

監視を入れて数週間経つと、*アラートが日常の雑音になって誰も見なくなる* 現象が起きる。

- *本当に起こすべきもの* だけをアラート化する（夜間に叩き起こされる価値があるか？）
- *シビアリティを分ける*：警告は Slack、緊急は PagerDuty
- *抑制・まとめ*：同じアラートが1時間で100件来たら1件に集約
- *アクションを明文化* する：ランブックを Runbook として Automation に登録

== X-Ray（分散トレーシング）

マイクロサービス構成でボトルネック特定に不可欠。

- リクエストごとに *トレース ID* を付与し、全サービスを串刺し
- *セグメント*（1サービス内）と *サブセグメント*（SDK 呼び出し等の内訳）
- *Service Map*：依存関係と平均レイテンシを可視化
- *Trace Analytics*：特定条件のトレースを絞り込み
- サンプリングルール：全リクエストを取ると高コスト、デフォルトは *1req/s + 5%*
- Lambda Powertools や OpenTelemetry で *自動計装*

ECS / EKS / EC2 / Lambda / API GW / SNS / SQS / DynamoDB が X-Ray と統合済み。

=== X-Ray 使用例（Lambda、Python）

```python
from aws_xray_sdk.core import xray_recorder, patch_all
patch_all()    # boto3、requests を自動計装

@xray_recorder.capture('handler')
def handler(event, context):
    with xray_recorder.in_subsegment('processing'):
        # 重い処理
        ...
```

これだけで Lambda → DynamoDB → 外部 HTTP 呼び出しが Service Map に描画される。

== CloudWatch Synthetics（外形監視）

*Canary*（Node.js / Python スクリプト）を定期実行して URL の健全性を確認。

- ブラウザ操作も可能（Puppeteer ベース）：ログイン → ダッシュボード表示確認
- 失敗時に CloudWatch Alarm 発火
- スクショと HAR ファイル取得
- APIの E2E テストとしても使える

=== Canary の例

```javascript
const { Synthetics } = require('Synthetics');

const apiCheck = async function () {
  const response = await Synthetics.executeHttpStep('check', {
    url: 'https://api.example.com/health',
  });
  if (response.statusCode !== 200) throw new Error('unhealthy');
};

exports.handler = async () => apiCheck();
```

== CloudWatch RUM（Real-User Monitoring）

ブラウザで動くクライアント側の性能・エラーを計測。

- Core Web Vitals（LCP、FID、CLS）
- JavaScript エラー
- API レイテンシ（クライアント視点）
- セッション再現
- Cognito / OIDC でユーザー識別可

フロントエンド JS に *1行 snippet* を埋めるだけで導入。

== Systems Manager の詳細

9章で触れた SSM は非常に広い。代表的なサブサービス：

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*機能*], [*用途*]),
  [Fleet Manager], [インスタンス一覧・リモート操作 GUI],
  [Session Manager], [ブラウザ or CLI でシェル接続],
  [Run Command], [複数台に一括コマンド],
  [Patch Manager], [OS パッチ自動適用（ベースライン + メンテナンスウィンドウ）],
  [Parameter Store], [階層的な設定・秘密値],
  [State Manager], [定期的に望ましい構成を強制],
  [Automation], [Runbook 実行（多段タスク）],
  [Inventory], [ソフト・ハードの構成収集],
  [OpsCenter], [運用イベントの一元管理],
  [Change Manager], [変更申請・承認・実行],
  [Maintenance Windows], [定期メンテナンス時間の定義],
  [Distributor], [パッケージ配布],
  [Quick Setup], [アカウント・リージョン横断の初期セットアップ],
)

=== オンプレ SSM Managed Instance

オンプレサーバに SSM Agent を入れ、*Hybrid Activation* で登録すると、*オンプレサーバを AWS コンソールから一元管理* できる（Patch、Inventory、Run Command 等）。ハイブリッド運用の基盤。

=== Parameter Store vs Secrets Manager（再確認）

#table(
  columns: (1fr, 1fr, 1fr),
  align: left,
  table.header([*項目*], [*Parameter Store*], [*Secrets Manager*]),
  [基本料金], [Standard 無料、Advanced 有料], [秘密1個 \$0.40/月],
  [自動ローテーション], [なし], [あり（Lambda 連携）],
  [Cross-Region Replication], [手動], [自動],
  [階層アクセス], [`/app/prod/*` を一括読取], [個別],
  [バージョン履歴], [Standard は100バージョン], [—],
  [ScanLimit], [API レート控えめ], [API レート控えめ],
)

軽い設定は Parameter Store、*本番 DB パスワード等* は Secrets Manager。

== Config の深掘り

すべてのリソースの *設定変更履歴* を時系列で保管。

- *Rules*：マネージド（数百個）＋ カスタム（Lambda、Guard DSL）
- *Remediation*：違反を自動修復（SSM Automation）
- *Conformance Pack*：ルール束（CIS、PCI、HIPAA、AWS BP）
- *Aggregator*：マルチアカウント・リージョンを集約
- *Organizations 連携*：組織全体で有効化

=== 典型的なマネージドルール

- `s3-bucket-public-read-prohibited`
- `s3-bucket-server-side-encryption-enabled`
- `encrypted-volumes`
- `iam-user-mfa-enabled`
- `ec2-instance-no-public-ip`
- `rds-instance-deletion-protection-enabled`

これらを *Conformance Pack* で一括適用し、違反は Slack / メール通知。

== CloudTrail Lake

SQL で CloudTrail を検索できる。長期保管（最長10年）。監査調査が圧倒的に早くなる。

```sql
SELECT eventTime, userIdentity.userName, eventName, sourceIPAddress
FROM arn:aws:cloudtrail:ap-northeast-1:123456789012:eventdatastore/xxxx
WHERE eventTime > '2026-04-21T00:00:00Z'
  AND errorCode IS NOT NULL
  AND userIdentity.userName = 'alice'
ORDER BY eventTime DESC
LIMIT 100;
```

== ServiceQuotas

各サービスの上限値を *閲覧・緩和申請* するサービス。

- アカウント・リージョン単位
- 履歴、承認状況
- EventBridge 経由で上限到達前に通知
- CloudFormation / CDK から上限緩和も申請可

== 運用のベストプラクティス

- *最初から CloudTrail / Config / GuardDuty（次章）を有効化*
- *ログ保持期間を必ず設定* する（特に CloudWatch Logs）
- *Systems Manager Session Manager を第一の接続手段* にする
- *主要リソースに監視ダッシュボードを1枚作る*（最初の障害対応が段違いに楽になる）
- *タグ付けルールを決めて自動化する*
- *月次で Trusted Advisor / Cost Explorer を見て棚卸しする*
- *X-Ray / Application Signals* を新規サービスには最初から
- *インシデント対応 Runbook* を Systems Manager Automation に登録
- *Service Quotas* を監視して、上限手前でアラート
- *Game Day / 障害演習* を定期実施（FIS、Resilience Hub と組み合わせ）
