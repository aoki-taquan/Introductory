= 業界別アーキテクチャ

業界ごとに *特有の規制・要件・パターン* がある。本章では金融、医療、小売、ゲーム、メディア、教育、製造、公共の代表的な AWS アーキテクチャを概観する。

== 金融サービス

=== 業界要件

- *規制対応*：PCI DSS、SOC、SOX、各国金融庁ガイドライン（日本：FISC、PCI 等）
- *監査・改ざん耐性*：すべての操作のログと検証可能性
- *データ主権*：国内保管・暗号化
- *高可用性*：マルチ AZ、マルチリージョン
- *リアルタイム性*：取引、不正検知

=== 主要構成

```
[顧客] → CloudFront + WAF + Shield Advanced
       → API Gateway + Cognito（MFA 必須）
       → Lambda / ECS Fargate
       → Aurora Multi-Region + DynamoDB Global Tables
                          + ElastiCache Redis
       → KMS（CMK、Multi-Region Keys）
       → CloudTrail + S3（ログアーカイブ・WORM）
       → Audit Manager（PCI / SOC）
```

=== 関連サービス

- *AWS for Financial Services*：業界向けソリューション集
- *Amazon Forecast*：時系列予測（与信、需要予測）
- *Amazon Fraud Detector*：不正取引検知
- *AWS Clean Rooms*：データ共有・匿名化
- *FinSpace*：金融データ分析プラットフォーム
- *Lake Formation* + *Macie*：データガバナンス

=== コンプライアンス

- *AWS Config Conformance Pack*：PCI、HIPAA、CIS 等
- *Audit Manager*：定期証跡収集
- *Artifact*：AWS の SOC、PCI、ISO 報告書
- 監査ログは別アカウントの *Vault Lock* で改ざん不能

== 医療・ヘルスケア

=== 業界要件

- *HIPAA*（米国）/ 医療法・個人情報保護法（日本）
- *PHI*（Protected Health Information）の保護
- *HL7 / FHIR* の規格対応
- *監査ログ・アクセス制御*
- *長期保管*（医療記録は数十年）

=== 主要構成

```
[病院端末] → AWS HealthLake（FHIR ストア）
[ウェアラブル] → IoT Core → Kinesis → 分析
[画像] → S3 + AWS HealthImaging（DICOM）
[研究] → SageMaker（匿名化データの ML）
[請求・運用] → Aurora + Lambda + Step Functions
[アクセス] → Cognito + AWS WAF + Network Firewall
[暗号化] → KMS（CMK）、CloudHSM（厳格要件）
[監査] → CloudTrail + Audit Manager（HIPAA フレームワーク）
```

=== 関連サービス

- *AWS HealthLake*：FHIR R4 準拠の患者データレイク
- *AWS HealthImaging*：DICOM 画像
- *AWS HealthOmics*：ゲノム解析
- *Comprehend Medical*：医療テキストの NLP
- *Transcribe Medical*：医療会話の転写

=== HIPAA 適用

AWS は多くのサービスを HIPAA 対象として認定。BAA（Business Associate Addendum）を AWS と締結することで PHI を AWS で扱える。

== 小売・EC

=== 業界要件

- *スパイク対応*（セール、テレビ放映）
- *パーソナライゼーション*
- *在庫・注文管理の整合性*
- *マルチチャネル*（Web、モバイル、店舗）
- *分析・BI*

=== 主要構成

```
[顧客] → CloudFront + WAF
       → ALB → ECS Fargate（Auto Scaling）
       → Aurora（注文）+ DynamoDB（カート・セッション）
                       + OpenSearch（商品検索）
                       + ElastiCache（キャッシュ）
       → SQS / EventBridge → Step Functions（注文処理 Saga）
       → SES / SNS（通知）
       → Personalize（レコメンド）
       → Pinpoint（マーケティング）

[分析]
       Click → Kinesis → Firehose → S3
       注文 → DynamoDB Streams → Lambda → S3
       S3 → Athena / Redshift → QuickSight

[POS / 店舗]
       Outposts または DataSync で集約
```

=== スパイク対策

- *Auto Scaling*（EC2 + ECS）
- *DynamoDB On-Demand*
- *CloudFront 高キャッシュヒット率*
- *SQS でバッファリング*
- *SAA / Solution Library*：Black Friday 対応リファレンス

== ゲーム

=== 業界要件

- *低レイテンシ*（マルチプレイ、操作性）
- *グローバル展開*
- *スパイク対応*（ローンチ、イベント）
- *マッチメイキング*
- *チート対策・不正検知*

=== 主要構成

```
[Player] → Global Accelerator（Anycast）
       → GameLift FleetIQ（Spot 混合 ゲームサーバ）
       → ElastiCache（リアルタイム状態）
       → DynamoDB（プレイヤー、リーダーボード）
       → Lambda + API Gateway（メタゲームサービス）
       → S3 + CloudFront（アセット配信）
       → Cognito（アカウント認証）
       → IoT Core（一部のリアルタイム通信）
       → GuardDuty + WAF（チート・DDoS）

[分析]
       ログ → Kinesis → Athena → QuickSight
       ML → Personalize、Lookout（不正）
```

=== AWS for Games

- *GameLift Streams*：クラウドゲーミング基盤
- *Open 3D Engine*（O3DE）：オープンソースゲームエンジン
- *Lumberyard 後継*

== メディア・エンターテインメント

=== 業界要件

- *動画変換・配信*
- *リアルタイム性*（ライブ）
- *DRM*
- *ピーク時の超高並列*
- *コンテンツ管理*

=== 主要構成

=== VOD（YouTube ライク）

```
[Upload] → S3 → MediaConvert → S3（HLS/DASH）→ CloudFront → [視聴者]
                                              ↑
                                             DRM（Speke）

[メタデータ] DynamoDB / OpenSearch
[ユーザー]   Cognito
[サムネ]    Lambda → Rekognition
[分析]      Kinesis → Athena
```

=== ライブ配信

```
[配信者] RTMP → MediaLive → MediaPackage → CloudFront → [視聴者]
                       ↓
                   MediaTailor（広告挿入）
                       ↓
                   IVS（低レイテンシなら）
```

=== 関連サービス

- *Elemental シリーズ*：MediaConvert / MediaLive / MediaPackage / MediaTailor
- *IVS*：3秒以下の低レイテンシ配信
- *Nimble Studio*：クラウド制作スタジオ
- *Direct Connect*：放送局との専用線

== 教育

=== 業界要件

- *マルチテナンシー*（学校・学部・科目）
- *コスト感度*
- *アクセシビリティ*
- *モバイル中心*
- *コンテンツ配信* と *インタラクティブ要素*

=== 主要構成

```
[Student] → CloudFront + S3（教材）
         → Amplify（モバイル / Web）
         → Cognito（マルチテナント）
         → API Gateway → Lambda → DynamoDB
         → IVS（ライブ授業）
         → Bedrock（生成 AI チューター）
         → Personalize（学習推薦）

[管理]    QuickSight（学習進捗）
[コスト]  Aurora Serverless v2（夜間 0 ACU）
```

=== AWS Educate / Academy

- *AWS Educate*：学生向け学習プラットフォーム、無料クレジット
- *AWS Academy*：教育機関向けカリキュラム
- *AWS Cloud Quest*：ロールプレイ学習

== 製造

=== 業界要件

- *IoT 統合*（工場・設備のセンサー）
- *エッジ処理*（ネットワーク不安定）
- *予知保全*
- *ライン制御の高可用性*
- *デジタルツイン*

=== 主要構成

```
[工場の設備] → IoT Greengrass（エッジ）
            → IoT Core → Kinesis → S3
            → IoT SiteWise（産業データモデル）
            → IoT TwinMaker（デジタルツイン）

[クラウド分析]
            S3 → Glue → Athena / Redshift
            SageMaker（予知保全モデル）
            Lookout for Equipment / Lookout for Vision

[エッジ計算]
            Snowball Edge Compute Optimized
            Outposts（工場内）
```

=== 関連サービス

- *AWS for Industries*：自動車、エネルギー、公共
- *Lookout for Equipment*：機械学習による予知保全
- *Lookout for Vision*：画像での品質検査
- *Monitron*：振動・温度センサーの予知保全

== 公共・政府

=== 業界要件

- *データ主権*
- *厳格な認証・監査*
- *長期保管*
- *FedRAMP / IRAP 等の認定*
- *マルチアカウント管理*

=== AWS の対応

- *AWS GovCloud*（US-East / US-West）：米国政府専用リージョン
- *AWS Top Secret / Secret*：諜報・防衛向け
- *日本でのリージョン* + *Outposts* で国内データ主権
- *Control Tower / Organizations* で複数省庁・部局を一元管理
- *Audit Manager*：FedRAMP / NIST 800-53 / CJIS

== スタートアップ

=== 特徴

- *リソース最小化*
- *スピード重視*
- *Free Tier 活用*
- *サーバーレス志向*

=== 主要構成

```
[Web / API]   Amplify or Vercel + S3 + CloudFront
              API Gateway + Lambda
              DynamoDB（On-Demand）
              Cognito

[認証]        Cognito or Clerk / Auth0

[Generative AI] Bedrock + Knowledge Bases

[IaC]         CDK or SST or Serverless Framework
[CI/CD]       GitHub Actions + OIDC
[監視]        CloudWatch Free Tier + Sentry
[コスト]      Budgets で月 \$50 アラート
```

*AWS Activate*（最大 \$100K クレジット）の活用。

== SaaS（再掲、41章とリンク）

41章で詳述。Silo / Pool / Bridge モデル。

```
[Tenant] → CloudFront → ALB → ECS（Pool）
                          → Lambda（Tier 別 Reserved Concurrency）
                          → DynamoDB（PK プレフィクス分離）
[認証]   Cognito（Pre Token Generation で tenant_id）
[請求]   AWS Marketplace or Stripe
[観測]   テナント別 CloudWatch メトリクス
```

== モビリティ・自動運転

=== 業界要件

- *エッジ計算*（車両内）
- *5G 連携*
- *大量データ*（センサー、カメラ）
- *リアルタイム ML*

=== 主要構成

```
[車両] → Wavelength（5G キャリア網内）→ AWS
[クラウド] → IoT FleetWise（車両データ）
          → S3（ペタバイト級ログ）
          → SageMaker（ML 訓練）
          → Outposts（OTA 配信制御）
```

=== 関連

- *AWS IoT FleetWise*：車両データ管理
- *Wavelength* / *Snow Family*：低レイテンシ・現地計算
- *DeepRacer*：教育用自動運転 ML

== 共通の設計原則（業界横断）

1. *Well-Architected* の6本柱を業界要件にマッピング
2. *責任共有モデル* を明確化
3. *マルチアカウント* で環境・権限分離
4. *監査ログ* を WORM で長期保管
5. *暗号化* を保管時・転送時で徹底
6. *DR 戦略* を業務要件（RPO/RTO）から逆算
7. *コスト管理* を最初から
8. *インシデント対応* の Runbook 整備

== 参考リソース

- *AWS Architecture Center*：業界別リファレンス
- *AWS Solutions Library*：すぐ使える IaC テンプレート
- *AWS Quick Starts*：CloudFormation 即座デプロイ
- *AWS Industries*：業界別ポータル
- *AWS Partner Solutions*：認定パートナーの構成例
- *AWS re\:Invent セッション*：業界別セッション豊富
- *Whitepapers*：業界・分野別の詳細ガイド

業界特有の課題は AWS だけで解決できないことも多い。*業界専門家・コンサル・パートナー* との協業が鍵となる。
