= 運用と監視

AWS で動くシステムを安定運用するには、*メトリクス・ログ・監査・設定・構成管理* の各観点で仕組みを整える必要がある。本章では CloudWatch、CloudTrail、Config、Systems Manager を中心に解説する。

== CloudWatch

*CloudWatch* は AWS の監視基盤である。メトリクス、ログ、アラーム、イベントをまとめて扱う。

=== CloudWatch Metrics

- AWS サービスから *標準メトリクス* が自動的に流れてくる（EC2 の CPU、ELB のリクエスト数など）
- *カスタムメトリクス* をアプリから `PutMetricData` で送れる
- 標準は1分間隔、詳細モニタリングで1分、カスタムで最短1秒粒度
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

CloudTrail は *「誰が・いつ・何を」の監査ログ* を記録するサービスである。AWS アカウント作成時点でデフォルトで有効（直近90日分）。

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

== 運用のベストプラクティス

- *最初から CloudTrail / Config / GuardDuty（次章）を有効化*
- *ログ保持期間を必ず設定* する（特に CloudWatch Logs）
- *Systems Manager Session Manager を第一の接続手段* にする
- *主要リソースに監視ダッシュボードを1枚作る*（最初の障害対応が段違いに楽になる）
- *タグ付けルールを決めて自動化する*
- *月次で Trusted Advisor / Cost Explorer を見て棚卸しする*
