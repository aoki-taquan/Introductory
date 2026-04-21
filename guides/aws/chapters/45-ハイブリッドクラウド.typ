= ハイブリッドクラウドとオンプレ統合

クラウド一本化が理想論で、現実には *オンプレ・他クラウドとの共存* が続く。本章ではハイブリッド設計、AWS の延長サービス、ネットワーク統合、データ同期、運用の一元化を扱う。

== ハイブリッドクラウドのパターン

=== なぜハイブリッドか

- *段階的移行*：一気に全部クラウドは現実的でない
- *規制・データ主権*：一部データをオンプレに
- *レガシー依存*：商用ソフト・ライセンス・ハードウェア
- *コスト*：既存投資の償却、長期運用
- *低レイテンシ要件*：工場・店舗の現地処理
- *ネットワーク要件*：専用線、閉域
- *災害対策*：逆向きの DR（クラウドからオンプレ）

=== 主要パターン

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*パターン*], [*特徴*]),
  [Cloud Burst], [普段オンプレ、スパイクをクラウドへ],
  [Dev in Cloud, Prod on-prem], [新規開発をクラウド、本番はオンプレ],
  [Data Gravity], [データ大量のオンプレ、処理はクラウド],
  [Edge + Cloud], [エッジで収集、クラウドで分析],
  [Multi-Cloud], [複数パブリッククラウドを用途別に],
)

== AWS の延長サービス

AWS をオンプレやエッジに *持ち込む* サービス群。

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*サービス*], [*用途*]),
  [Outposts（ラック / サーバ）], [自社データセンターに AWS インフラを置く],
  [Local Zones], [主要都市のメトロに AWS のミニリージョン],
  [Wavelength], [5G キャリア網内に AWS インフラ],
  [ECS / EKS Anywhere], [マネージドコントロールプレーンをオンプレで],
  [IoT Greengrass], [エッジデバイスで Lambda / ML 実行],
  [Storage Gateway], [オンプレに NFS/SMB/iSCSI、裏は S3],
  [Snow Family], [オフラインデータ移送・エッジ計算],
  [Direct Connect], [専用線で AWS に接続],
  [VPN], [IPsec でオンプレ ↔ AWS],
  [CloudEndure（MGN に統合）], [サーバレプリケーション移行],
)

== AWS Outposts

AWS のラックそのものを自社 DC に置く。EC2、EBS、S3 on Outposts、RDS、EKS、ECS が *オンプレで動作*。

=== 2種類

- *Outposts ラック*：標準サーバラック（42U）。大規模向け
- *Outposts サーバ*：1U / 2U。支店・小規模向け

=== 主な利用シナリオ

- 低レイテンシ要件（現地で数ms）
- データ主権要件（クラウドに出せないデータ）
- ネットワーク制約（オンプレから切り離せない既存システム）
- 規制（金融・公共系）

=== 運用

- *コントロールプレーンはリージョン*（バージニア、東京など）
- *データプレーンは Outposts*（物理的に自社）
- AWS 従業員が *物理メンテナンス* に立ち会う
- インターネット / 専用線で AWS と常時接続

== Local Zones

主要都市のメトロにある AWS のミニリージョン。

- 低レイテンシ（数 ms）の AWS サービス（EC2、EBS、FSx 等）
- 親リージョンと Internal 接続
- 日本では *現時点で Local Zones なし*
- 米国・欧州・アジア主要都市に展開中

メディア制作、ゲーミング、ライブ配信、リアルタイム ML 推論向け。

== Wavelength

5G モバイルキャリアのネットワーク *内部* に AWS インフラを置く。

- モバイル端末から *キャリア網内で完結* → 超低レイテンシ
- AR/VR、自動運転、工場の協調制御
- キャリア（米国：Verizon、日本：KDDI 等）のパートナーシップ

== ECS / EKS Anywhere

Kubernetes / ECS のコントロールプレーンだけ AWS、ワーカーノードはオンプレ。既存オンプレ Kubernetes を AWS 流の運用で統合できる。

*EKS Anywhere* は完全に別物：オンプレで独立 K8s クラスタを構築・運用（AWS との接続は任意）。

== Storage Gateway 再掲

13章で扱ったハイブリッドストレージ。

- *File Gateway*：NFS/SMB → S3
- *Volume Gateway*：iSCSI、キャッシュ型 / 保管型
- *Tape Gateway*：仮想テープ → S3/Glacier

段階的移行 / バックアップ / ハイブリッドアクセスで活躍。

== ネットワーク統合

=== 接続方式の選択

#table(
  columns: (1fr, 1fr, 1fr),
  align: left,
  table.header([*接続*], [*帯域*], [*用途*]),
  [VPN Site-to-Site], [〜 1.25 Gbps/tunnel], [小規模、検証、バックアップ接続],
  [VPN Accelerated], [〜 10 Gbps], [Global Accelerator 経由、低レイテンシ],
  [Direct Connect (Hosted)], [50 Mbps〜10 Gbps], [中規模、共有線],
  [Direct Connect (Dedicated)], [1〜400 Gbps], [大規模、専有線],
  [Transit Gateway Connect], [高速], [SD-WAN / BGP 統合],
)

=== オンプレ側機器

Cisco、Juniper、Palo Alto、Fortinet 等のメーカーが AWS 認定設定テンプレートを提供。

=== Direct Connect 設計

- *冗長化*：2 Location、2 Connection で SLA 99.99%
- *BGP で経路制御*：Private VIF / Transit VIF
- *MACsec*（L2 暗号化）：規制対応
- *バックアップ VPN*：Direct Connect 障害時

=== Cloud WAN / SD-WAN

- *AWS Cloud WAN*：グローバル WAN の宣言的管理
- *Cisco Meraki SD-WAN*、*Cisco Viptela*、*VMware SD-WAN* 等の連携
- Transit Gateway Connect で GRE トンネル統合

== DNS 統合

=== Route 53 Resolver

- *インバウンドエンドポイント*：オンプレから VPC 内 DNS を解決
- *アウトバウンドエンドポイント*：VPC 内からオンプレ DNS を解決
- *Resolver Rules*：ドメイン単位のルーティング

```
VPC → 社内ドメイン (*.corp.example.com) → オンプレ DNS
     → その他 → Route 53 / VPC 内
```

=== ハイブリッド DNS 設計

```
[オンプレ DNS (AD)]  ←→ Resolver Inbound Endpoint
                      ←→ Resolver Outbound Endpoint
                      ←→ VPC Private Hosted Zone
                      ←→ Route 53 Public Hosted Zone
```

== Active Directory 統合

=== AWS Managed Microsoft AD

フルマネージド AD。EC2 Windows ドメイン参加、FSx for Windows、Workspaces で使う。

=== AD Connector

既存オンプレ AD への中継。AD は *オンプレにあるまま*、AWS サービスから参照。

=== AD Trust

オンプレ AD と AWS Managed AD を *信頼関係* で統合。どちらのユーザーもシームレスにアクセス。

== データ同期・統合

=== DataSync

オンライン回線でのファイル・オブジェクト同期（21章参照）。

- NFS / SMB / HDFS / S3 / EFS / FSx
- 継続的同期、スケジュール、検証
- 帯域制御

=== DMS（Database Migration Service）

DB 移行・継続レプリケーション。

- *Full Load + CDC*：初期コピー + 変更差分
- オンプレ Oracle → AWS Aurora など
- *DMS Fleet Advisor*：移行候補の可視化

=== Storage Gateway

NFS/SMB アクセスを S3 に変換。段階的移行でアプリ無改造。

=== Kinesis / EventBridge Pipes

イベント・ストリームのハイブリッド化。オンプレから SDK 経由で送信、クラウド側で処理。

=== CloudEndure / MGN

サーバ全体のブロックレベルレプリケーション。移行・DR。

== CI/CD のハイブリッド化

```
[Git (オンプレ GitLab / クラウド GitHub)]
   ↓
[CI（クラウド）]     ビルド・テスト
   ↓
[Artifact（S3/ECR）]
   ↓
[CD] → Outposts / ECS Anywhere / オンプレ（SSM で Push）
     → AWS 本体（CodeDeploy）
```

Systems Manager Automation / Run Command でオンプレサーバにも統一手順を流せる（SSM Agent オンプレインストール）。

== 運用・監視の一元化

=== Systems Manager Hybrid Activations

オンプレサーバを *Managed Instance* として登録し、AWS 側から管理。

- インベントリ収集
- Patch Manager でパッチ適用
- Run Command で一斉コマンド
- Session Manager でブラウザ経由接続
- Compliance レポート

```bash
# オンプレサーバで Activation Code を使って有効化
curl https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm -o /tmp/amazon-ssm-agent.rpm
sudo yum install -y /tmp/amazon-ssm-agent.rpm
sudo amazon-ssm-agent -register -code "CODE" -id "ID" -region "ap-northeast-1"
```

=== CloudWatch Agent on-prem

オンプレサーバのメトリクス・ログを CloudWatch に送信。AWS リソースと同じダッシュボードで可視化。

=== AWS Config for Hybrid

オンプレリソース（VMware 等）を Config で設定管理。

=== Managed Grafana / Prometheus

OSS メトリクスをマネージドで。オンプレと AWS の両方のメトリクスを統合ダッシュボード。

== Identity 統合

=== IAM Identity Center + 外部 IdP

オンプレ AD / Entra ID / Okta と SAML / SCIM 統合。ユーザーは1つの ID で AWS 複数アカウントにアクセス。

=== SAML / OIDC フェデレーション

長期 IAM ユーザーを使わず、IdP 発行の短期トークンで AWS リソース利用。

=== IAM Roles Anywhere

オンプレワークロードに X.509 証明書ベースで AWS 一時認証情報を払い出す。オンプレから AWS API を呼ぶ典型。

== セキュリティ

=== 共通の監査基盤

- CloudTrail（AWS 側）
- Config（AWS リソース）
- Inspector（EC2 + オンプレ SSM Managed Instance）
- Audit Manager（統合フレームワーク）

=== ネットワークセキュリティ

- Direct Connect は暗号化されない → MACsec または上位 VPN
- PrivateLink で AWS マネージドサービスをプライベート経由
- Network Firewall / AWS WAF で境界防御

=== データ主権

- *どのリージョンに保管するか*
- *暗号化キー（KMS）の所在*
- *誰がアクセスできるか*
- GDPR / CCPA / 日本の個人情報保護法などの規制対応

== ハイブリッドアーキテクチャ例

=== 段階的クラウド移行

```
Phase 1: オンプレ主軸、AWS でバックアップ（Storage Gateway）
Phase 2: 非本番環境を AWS に（Dev/Staging/DR）
Phase 3: 新規ワークロードは AWS（Cloud-Native で実装）
Phase 4: 本番レガシーを段階移行（MGN + DMS）
Phase 5: オンプレは戦略的なものだけ残す（Outposts 等）
```

=== 工場・店舗のエッジ

```
[店舗]                      [リージョン (東京)]
  └ IoT デバイス → IoT Core → Firehose → S3 → Athena
  └ エッジ Pi → Greengrass    → DynamoDB
  └ POS → (SD-WAN) → VPC → ECS
```

=== 金融・医療の規制対応

```
[オンプレ DC]               [Outposts (自社 DC 内)]  [リージョン]
  └ 患者 DB（オンプレ）      └ 秘匿計算（Outposts）    └ 分析・バックアップ
  └ 院内システム                                        └ ML / 匿名化後データ
         ↑↓ Direct Connect（MACsec）
```

== マルチクラウドとの違い

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*モデル*], [*説明*]),
  [Single Cloud], [AWS 単一。シンプル、統合深],
  [Hybrid], [AWS + オンプレ。現実的、移行過渡期],
  [Multi-Cloud], [AWS + GCP/Azure など。特定機能の best-of-breed],
)

マルチクラウドは IaC（Terraform）、認証連携、データ転送料金、運用人員 などコスト増要因が多い。*明確な理由（独禁・規制・機能）* がない限り避ける方が現実的。

== 注意点

- *レイテンシ*：オンプレ ⇔ AWS は数十 ms 以上。アプリ設計が重要
- *データ転送料金*：大量通信は料金影響大。圧縮・バッチ化
- *障害時の切り分け*：AWS・ネットワーク・オンプレのどこか特定できる体制
- *運用人員*：両方の知識が必要、チーム編成
- *バージョン差*：オンプレは古い、クラウドは新しい。互換性管理

== よくある落とし穴

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*罠*], [*対策*]),
  [Direct Connect 単一で落ちる], [2拠点・2接続で冗長化、VPN バックアップ],
  [オンプレ変更でクラウドが動かない], [統合テスト、Staging 環境],
  [DNS 切替が反映遅い], [TTL 短縮、Route 53 ARC],
  [認証情報が2系統で錯綜], [Identity Center 一元化、SSO],
  [Outposts の孤立], [リージョン接続監視、オフライン時の設計],
  [データ転送料で月末ビックリ], [VPC エンドポイント、圧縮、分析はクラウド側],
  [ネットワーク制約で Lambda / Fargate 使えない], [Outposts / ECS Anywhere の計算サービス],
  [ハイブリッド運用が属人化], [Runbook、自動化、人材育成],
)

== 将来像

AWS はハイブリッドを重要戦略と位置づけ、Outposts / ECS Anywhere / EKS Anywhere / Local Zones を拡大している。一方、多くの組織は *長期的にクラウドファースト* へ移行中。

ハイブリッドは *目的ではなく過渡期*。最終状態（ターゲットアーキテクチャ）を定め、そこに向かう道筋として設計する。
