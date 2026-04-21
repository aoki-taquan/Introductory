= 認定資格と学習リソース

本書の締めくくりとして、AWS の知識を体系的に深めるための *認定資格* と *学習リソース* を紹介する。これから長く AWS を使い続ける上での「次の一歩」を具体化する。

== AWS 認定資格の全体像

=== カテゴリ

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*カテゴリ*], [*資格*]),
  [Foundational], [Cloud Practitioner (CLF)、AI Practitioner (AIF)],
  [Associate], [Solutions Architect (SAA)、Developer (DVA)、SysOps (SOA)、Data Engineer (DEA)、Machine Learning Engineer (MLA)],
  [Professional], [Solutions Architect Pro (SAP)、DevOps Engineer Pro (DOP)],
  [Specialty], [Advanced Networking (ANS)、Security (SCS)、Machine Learning (MLS)],
)

2024〜2025 年にかけて大きく整理された。旧 Data Analytics / Database Specialty は廃止、Data Engineer Associate に統合。AI Practitioner / ML Engineer Associate が新設。

=== 受験制度

- *オンライン受験*（Pearson VUE の自宅監督型）または *テストセンター受験*
- *所要時間*：Foundational 90分、Associate 130分、Professional/Specialty 180分
- *料金*：Foundational \$100、Associate \$150、Professional/Specialty \$300
- *合格ライン*：おおむね 70%（資格により差あり）
- *有効期間*：3年間。同じか上位資格の合格で自動更新

=== 公式リソース

- *AWS Skill Builder*：公式学習プラットフォーム（無料＋Subscription）
- *Exam Readiness コース*：各資格の試験対策コース
- *Sample Questions*：10問程度の公式サンプル
- *Exam Guide*：試験範囲・配点の公式ドキュメント
- *Practice Exam*（Skill Builder Subscription 含む）

== おすすめ学習順序

=== 入門パス

```
[目安3か月]
  1. Cloud Practitioner (CLF)  … 本書で大部分カバー済み
       ↓
  2. Solutions Architect Associate (SAA)  … アーキテクチャ全般の必携
```

これで AWS 全体の基盤が身につく。

=== 開発者パス

```
  CLF → SAA → Developer (DVA)  → DevOps Engineer Pro (DOP)
```

DVA は Lambda / DynamoDB / CI/CD / アプリ統合が中心。

=== 運用パス

```
  CLF → SAA → SysOps (SOA)  → DevOps Engineer Pro (DOP)
```

SOA は唯一 *ラボ試験*（実機操作）があったが、2023年以降ラボ部分は削除されマルチプルチョイスに一本化。

=== アーキテクトパス

```
  CLF → SAA → Solutions Architect Pro (SAP)
```

SAP は難関。200問以上のシナリオ問題、広範囲。

=== 分野特化

```
  SAA → Advanced Networking (ANS)     … ネットワーク設計
      → Security (SCS)                 … セキュリティ運用
      → Data Engineer (DEA)            … データ基盤
      → Machine Learning Engineer (MLA) … ML ワークフロー
      → AI Practitioner (AIF)          … 生成 AI 基礎
      → Machine Learning Specialty (MLS) … ML 深掘り
```

== 資格別の勉強法

=== Cloud Practitioner (CLF)

- *対象*：AWS の基本概念、主要サービス、請求、サポート
- *期間*：初学者で 2〜4週間
- *教材*：本書 + AWS Skill Builder「Cloud Practitioner Essentials」+ サンプル問題
- *実機*：Free Tier で EC2 / S3 / IAM を触るだけで合格ライン届く

=== Solutions Architect Associate (SAA)

- *対象*：アーキテクチャ設計（信頼性・可用性・パフォーマンス・コスト・セキュリティ）
- *期間*：1〜3か月
- *教材*：Skill Builder、Udemy（Stephane Maarek、Adrian Cantrill）、Tutorials Dojo の模擬試験、AWS 公式 Exam Readiness
- *実機*：VPC / EC2 / ELB / Auto Scaling / RDS / S3 / CloudFront / Route 53 / IAM は手を動かす

=== Developer Associate (DVA)

- *対象*：Lambda、API Gateway、DynamoDB、SAM、CloudFormation、CodeCommit/Build/Deploy/Pipeline
- *期間*：1〜2か月（SAA 取得後なら）
- *実機*：24章のハンズオンに近い構成を自作

=== SysOps Administrator Associate (SOA)

- *対象*：監視、運用自動化、セキュリティ、高可用性、コスト最適化
- *期間*：1〜2か月
- *実機*：CloudWatch、Systems Manager、Config、CloudTrail

=== Solutions Architect Professional (SAP)

- *対象*：大規模エンタープライズアーキテクチャ、マルチアカウント、移行、ハイブリッド、高度な運用
- *期間*：3〜6か月
- *難易度*：最難関クラス。シナリオが長文、選択肢の差が微妙
- *教材*：Adrian Cantrill の詳細コース、Tutorials Dojo、AWS 公式 Exam Readiness
- *体験ベース*：実務で大規模設計を経験している人は強い

=== Specialty 全般

- 専門領域に絞った深い知識
- SAA / SAP 合格後が一般的
- 実務経験が活きる傾向

== 学習リソース

=== 公式

- *AWS Skill Builder*：https://skillbuilder.aws/
  - 無料コース多数、Subscription（Individual \$29/月、Team \$449/年）でラボ・Practice Exam
  - *AWS Jam*：ゲーム形式のスキルチャレンジ
  - *AWS Cloud Quest*：ロールプレイ形式の学習
- *AWS Documentation*：https://docs.aws.amazon.com/
  - *User Guide / Developer Guide / API Reference*
  - *Whitepapers*：Well-Architected、Security Pillar、コスト最適化など
- *AWS Blog*：https://aws.amazon.com/blogs/
  - 新機能・ベストプラクティス
- *AWS Architecture Center*：参照アーキテクチャ集
- *AWS Solutions Library*：すぐ使える CloudFormation テンプレート
- *AWS Prescriptive Guidance*：テーマ別の設計ガイド
- *AWS Samples (GitHub)*：サンプルコード

=== re\:Invent / Summit

- *AWS re\:Invent*：年次グローバルカンファレンス（11月末〜12月上旬、ラスベガス）
  - セッション動画は YouTube で無料公開（数千本）
  - *Keynote*、*400 / 500 レベルセッション*
- *AWS Summit*：各国の地域カンファレンス（日本では毎年春〜夏）
- *AWS Innovate*：オンラインテーマ別カンファレンス

=== コミュニティ

- *AWS User Group*：JAWS-UG（日本）など世界中に
- *AWS Community Builders*：AWS 公式のアドボケイトプログラム
- *AWS Heroes*：長期貢献者の公式認定
- *Twitter / X の AWS コミュニティ*：\@awsreinvent、\@jeffbarr
- *Reddit*：r/aws、r/awscertifications
- *Stack Overflow*：aws タグ

=== 独立系メディア・ブログ

- *AWS What's New*：公式の機能発表 RSS
- *Last Week in AWS*（Corey Quinn）：毒舌だが洞察深いニュースレター
- *A Cloud Guru / Pluralsight*：動画コース
- *acloud.guru blog*
- *Medium の AWS タグ*

=== 日本語リソース

- *AWS Black Belt Online Seminar*：AWS JP SA による公式シリーズ
- *classmethod.jp 技術ブログ（DevelopersIO）*：圧倒的な AWS 情報量
- *NRI ネットコム技術ブログ*
- *JAWS-UG*：地域・テーマ別の勉強会
- *書籍*：翔泳社・技術評論社・O'Reilly Japan の AWS 本

=== 有料トレーニング

- *AWS Training and Certification*：公式講師によるクラス
- *Cloud Academy / Pluralsight / A Cloud Guru / Adrian Cantrill*
- *Udemy*：Stephane Maarek、Adrian Cantrill、Neal Davis
- *Whizlabs / Tutorials Dojo*：模擬試験問題集

== 実務で学び続けるヒント

=== サンドボックスを持つ

個人用 AWS アカウント（または勤務先の Sandbox アカウント）を持ち、新機能が出たら手を動かす。Skill Builder Lab や Adrian Cantrill の独自 Lab 環境も有用。

=== 1つのサービスを深掘りする

広く浅くは本書で済んでいる。次は興味のあるサービス1つを *ドキュメント全部読む* くらい深く掘る。S3 の Lifecycle と Intelligent-Tiering を全部、Lambda のイベントソースマッピングの挙動を全部、など。

=== 公式ブログを定期購読

AWS What's New の RSS、各サービスブログ、*Serverless*、*Networking*、*Security*、*Database* など関心分野のブログをフィードリーダーに入れる。毎日15分で業界最前線をキャッチアップできる。

=== re\:Invent セッションを見る

年末の re\:Invent 後、1〜2か月かけて関心領域のセッションを10本程度見る。*300 / 400 レベル* が実装よりで学びが多い。

=== 他人のアーキテクチャを読む

- *AWS Architecture Blog*
- *Case Study*
- *re\:Invent の "Customer Story" 系セッション*
- *GitHub 上のオープンソース AWS プロジェクト*

自分と違う設計を見ると、自分の選択肢が広がる。

=== 小さく作って壊す

本書のハンズオン（24〜26章）のような小さなシステムを作り、あえて壊して復旧する。*学びは実機操作とトラブルシュートから*。

== AWS と周辺技術

AWS だけに閉じこもらず、以下の周辺技術も並行して学ぶとキャリアの幅が広がる。

- *Terraform / Pulumi*：マルチクラウド IaC
- *Kubernetes*：EKS だけでなく GKE / AKS / 自前でも
- *Observability*：Datadog、New Relic、Grafana、Prometheus
- *データエンジニアリング*：Snowflake、Databricks、dbt、Apache Iceberg
- *機械学習 / 生成 AI*：PyTorch、Hugging Face、LangChain、MCP（Model Context Protocol）
- *セキュリティ*：ゼロトラスト、SBOM、SLSA
- *FinOps*：クラウド財務管理の方法論

== 本書からの卒業

本書は「幅広く AWS の全体像を掴む」ことを目的に書かれた。ここまで読み通した読者は、AWS のほぼ全領域を俯瞰できる状態にある。次の学習段階として：

+ *個人アカウントで 24〜26章のハンズオンを実施*
+ *Cloud Practitioner → SAA の順で受験*（2〜4か月）
+ 興味のある特定領域（データ分析 / ML / ネットワーク / セキュリティ）の *Specialty* を目指す
+ 実務で AWS を選ぶ場面を作り、*Well-Architected Review* を通してみる
+ JAWS-UG 等の *コミュニティに参加* し、他社の事例を吸収する

AWS の進化は速い。*学び続けること* こそが最大のスキル。本書がその第一歩となれば幸いである。

== 参考：読者のフェーズ別推奨

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*読者フェーズ*], [*次にやること*]),
  [AWS 初心者、本書を読んだ], [24章ハンズオン → CLF 受験 → SAA 教材へ],
  [実務 AWS 半年], [SAA 取得 → 担当領域の Specialty 教材],
  [実務 AWS 1〜2年], [SAP、Well-Architected Review を通す、re\:Invent セッション視聴],
  [実務 AWS 3年以上], [Specialty 複数、コミュニティ登壇、OSS 貢献],
  [ML / データ系に進みたい], [DEA → MLA → MLS、Bedrock 実務、SageMaker 深掘り],
  [セキュリティに進みたい], [SCS、IAM 深掘り、Well-Architected Security Pillar],
  [独立・フリーランス], [複数認定 + ポートフォリオ、AWS Partner 個人登録検討],
)
