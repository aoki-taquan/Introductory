= Well-Architected Framework

AWS Well-Architected Framework は、クラウドシステムを評価する AWS 公式フレームワーク。*6本の柱* でシステム設計をレビューし、改善点を体系的に洗い出す。本章は各柱の要点と、Well-Architected Tool の使い方をまとめる。

== 6本の柱

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*柱*], [*問い*]),
  [Operational Excellence（運用上の優秀性）], [運用をどう改善し続けるか],
  [Security（セキュリティ）], [情報・資産をどう守るか],
  [Reliability（信頼性）], [期待された機能を正しく実行し続けられるか],
  [Performance Efficiency（パフォーマンス効率）], [リソースを効率的に使えているか],
  [Cost Optimization（コスト最適化）], [必要以上に払っていないか],
  [Sustainability（持続可能性）], [環境負荷を最小化しているか],
)

== Operational Excellence（運用上の優秀性）

=== 主要設計原則

- *運用をコード化* する（Infrastructure as Code、Configuration as Code）
- *小さく頻繁な可逆変更* を行う
- *手順を定期的に見直す*
- *障害を予見し対応する*
- *運用失敗から学ぶ*

=== 実践

- CloudFormation / CDK / Terraform ですべてを定義
- CI/CD パイプライン（CodePipeline / GitHub Actions）
- ブルーグリーン・カナリアデプロイ
- CloudWatch Dashboard、X-Ray、Application Signals
- Systems Manager Automation で運用手順の自動化
- 定期的な *Game Day*、ポストモーテム文化
- *Runbook* と *Playbook* の整備

== Security（セキュリティ）

=== 主要設計原則

- 強固なアイデンティティ基盤
- トレーサビリティを有効化
- すべての層にセキュリティ
- セキュリティのベストプラクティスを自動化
- 転送中・保管中のデータ保護
- データに人を近づけない（アクセスを絞る）
- セキュリティイベントに備える

=== 実践

- *IAM Identity Center* + passkey/FIDO2
- *CloudTrail / Config / GuardDuty / Security Hub* を全リージョン・全アカウントで
- *KMS* で暗号化、*Secrets Manager* で秘密管理
- *WAF + Shield*、*Network Firewall*
- *SCP* でガードレール、*Permission Boundary*
- *IAM Access Analyzer* で外部公開検知
- インシデント対応 *Runbook* を Systems Manager Automation に
- 19章のセキュリティサービスを組織的に運用

== Reliability（信頼性）

=== 主要設計原則

- 障害からの自動復旧
- 回復手順のテスト
- 水平方向のスケーリング
- キャパシティの推測を止める
- 変更管理を自動化

=== 実践

- *マルチ AZ* を前提に設計（EC2 / RDS / Aurora / ALB / EFS）
- *Auto Scaling* で水平スケール
- *AWS Backup* + DR 戦略（27章）
- *ヘルスチェック* と *サーキットブレーカ*
- *Chaos Engineering*：AWS Fault Injection Service（FIS）で障害注入
- *Service Quotas* の管理、プロアクティブな上限緩和
- *Resilience Hub* でレジリエンス評価

== Performance Efficiency（パフォーマンス効率）

=== 主要設計原則

- 新技術を民主化する（マネージドサービス活用）
- グローバル展開を数分で
- サーバーレスアーキテクチャ利用
- 頻繁に実験
- 機械的共感を持つ（OS・HW の特性を理解）

=== 実践

- *適切なインスタンスタイプ*：Graviton、最新世代
- *キャッシュ*：ElastiCache、CloudFront、DynamoDB DAX、Global Accelerator
- *サーバーレス*：Lambda、Fargate、Aurora Serverless
- *Compute Optimizer* で右サイジング推奨
- *Performance Insights*（RDS/Aurora のパフォーマンス診断）
- *CloudWatch Application Signals* でレイテンシ可視化
- 負荷試験（Distributed Load Testing on AWS）

== Cost Optimization（コスト最適化）

=== 主要設計原則

- クラウド財務管理（CCOE 的組織）
- 消費モデルを採用（使った分だけ）
- 全体効率を測定
- 重労働を AWS に寄せる
- コストを分析・帰属させる

=== 実践

- *Budgets* + *Cost Explorer*
- *Compute Savings Plans / RI*
- *Spot Instance* / *Fargate Spot*
- *Aurora Serverless v2* で低負荷時 0 ACU
- *S3 Intelligent-Tiering* / ライフサイクル
- *CloudWatch Logs 保持期間*
- *Compute Optimizer* / *Trusted Advisor*
- *コスト配分タグ* + Cost Categories
- *AWS Cost Optimization Hub*（2023〜）

== Sustainability（持続可能性）

2021年追加。環境負荷（CO2 排出量）を意識した設計。

=== 主要設計原則

- 影響を理解する
- 持続可能性目標を設定
- 使用率を最大化する
- より効率的なハードウェアを採用
- 不要なタスクを減らす
- マネージドサービスを使う

=== 実践

- *Customer Carbon Footprint Tool* で排出量可視化
- *Graviton / Inferentia / Trainium* は従来比 CO2 削減
- *Spot Instance* で遊休 HW を活用
- *適切なインスタンスサイズ*（オーバープロビジョニング回避）
- *サーバーレス・マネージド化* で共用インフラの効率化
- *データライフサイクル*（古いデータは低炭素な層へ）

== Well-Architected Tool

AWS コンソールの *Well-Architected Tool* で、実際のワークロードを6本柱でレビューできる。

=== 流れ

+ *ワークロードを定義*（名前・リージョン・業界・レビュー担当者）
+ *レンズ選択*：*AWS Well-Architected Framework*（必須）+ 業界別レンズ（Serverless / ML / IoT / HPC / SaaS / Financial Services / Healthcare）
+ *質問に回答*：各柱ごとに数十問。該当ベストプラクティスを選択
+ *High Risk Issues（HRI）* と *Medium Risk Issues* が自動集計
+ *改善計画* を立てる（IaC や JIRA に連携可）

=== レンズ

特定領域向けの追加質問セット。

- *Serverless Lens*
- *SaaS Lens*
- *Machine Learning Lens*
- *IoT Lens*
- *Financial Services Industry Lens*
- *HPC Lens*
- *FTR（Foundational Technical Review）*：APN パートナー向け
- *カスタムレンズ*：自社固有の基準

=== 利点

- *外部レビュー* を受けなくても自己診断できる
- AWS SA（Solutions Architect）と組んで第三者レビュー（WAR：Well-Architected Review）も可能
- *Well-Architected Review 完了のパートナーは AWS クレジット支援* が受けられることがある

== 6本柱チェックリスト（抜粋）

=== Operational Excellence

- [ ] IaC で全リソースを管理しているか
- [ ] 変更はコードレビューを経てデプロイされるか
- [ ] CloudWatch / X-Ray で可観測性を担保しているか
- [ ] 運用手順が Runbook 化されているか
- [ ] 定期的な改善レビューがあるか

=== Security

- [ ] ルートユーザーに passkey、アクセスキーなし
- [ ] IAM Identity Center で人のアクセスを管理
- [ ] 最小権限の原則を徹底
- [ ] CloudTrail / Config / GuardDuty が全アカウント有効
- [ ] KMS / Secrets Manager で暗号化・秘密管理
- [ ] WAF / Shield で境界防御
- [ ] インシデント対応手順が文書化

=== Reliability

- [ ] マルチ AZ 前提の設計
- [ ] Auto Scaling で需要変動に追従
- [ ] バックアップ + 定期リストア演習
- [ ] DR 戦略（RPO/RTO）が明確
- [ ] Service Quotas を監視
- [ ] Chaos Engineering で障害注入テスト

=== Performance Efficiency

- [ ] 最新世代インスタンス・Graviton を評価
- [ ] キャッシュ層（CloudFront、ElastiCache）を活用
- [ ] 負荷試験を実施
- [ ] Compute Optimizer 推奨を反映
- [ ] RDS Performance Insights でクエリ最適化

=== Cost Optimization

- [ ] Budgets で予算アラート
- [ ] Savings Plans / RI を評価
- [ ] Spot / Fargate Spot をバッチに適用
- [ ] S3 ライフサイクル、Intelligent-Tiering
- [ ] CloudWatch Logs 保持期間設定
- [ ] Cost Explorer で月次レビュー
- [ ] コスト配分タグ戦略

=== Sustainability

- [ ] Customer Carbon Footprint Tool で排出量確認
- [ ] Graviton / Inferentia を検討
- [ ] 停止可能なワークロードは Spot / 夜間停止
- [ ] データライフサイクルで古いデータを低炭素層へ

== WAF（Well-Architected Framework）と他の指針

Well-Architected Framework は *抽象的な原則*。実装に落とすには：

- *AWS Prescriptive Guidance*：具体的な設計ガイド
- *AWS Solutions Library*：業界別の参照アーキテクチャ + CloudFormation テンプレート
- *AWS Architecture Center*：図解アーキテクチャ集
- *AWS Blog*：最新事例・プラクティス
- *re\:Invent セッション*：最新の深い話

Well-Architected の質問に答えながら、これらのリソースで実装ノウハウを補う。

== レビューのリズム

- *新規プロジェクト開始時*：設計前のレビュー
- *本番リリース前*：HRI をすべて解決
- *大規模変更時*：影響範囲のレビュー
- *年1回*：全体レビュー + 改善計画更新
- *インシデント後*：該当領域の再評価

== よくある誤解

- ❌ 「Well-Architected レビューは AWS に頼まないとできない」
  → ○ 自社だけでも Tool で実施可能
- ❌ 「HRI ゼロを目指す」
  → ○ リスクを理解して受容するのも判断。ゼロが必ずしも正解ではない
- ❌ 「全部のベストプラクティスを満たすべき」
  → ○ ワークロードの特性・フェーズに応じて優先順位付け
- ❌ 「1回やればOK」
  → ○ 継続的プロセス。6か月〜1年で再評価
- ❌ 「Cost Optimization だけやる」
  → ○ 6本柱はトレードオフで成立。安くして可用性を落とすのは本末転倒

== まとめ

Well-Architected Framework は *設計の共通言語*。チーム内の議論を体系化し、経営層への説明資料にもなる。小さいワークロードでも軽く通すだけで盲点が見つかる。本章を読み終えた後、今運用している（あるいは設計中の）システムで、まず *Security と Reliability* を自己評価してみることを推奨する。
