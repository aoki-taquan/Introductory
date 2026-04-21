= セキュリティサービスの詳細

10章ではセキュリティの全体像を扱った。本章は各サービスを深く掘り下げ、運用視点での設計と検知パイプライン、KMS / Secrets Manager / ACM の詳細、IAM Access Analyzer の使いこなしまでを対象にする。

== 防御層別のサービスマップ

```
[アイデンティティ]    IAM / Identity Center / Access Analyzer / Verified Permissions
[ネットワーク]         SG / NACL / WAF / Shield / Network Firewall / DNS Firewall
[データ]               KMS / CloudHSM / Secrets Manager / Macie / S3 Block Public Access
[コンピュート]         Inspector / IMDSv2 / GuardDuty Runtime Monitoring
[監査・検知]           CloudTrail / Config / GuardDuty / Detective / Audit Manager
[統合・運用]           Security Hub / Firewall Manager / Incident Manager
[コンプライアンス]    Artifact / Audit Manager
```

== WAF（Web Application Firewall）

CloudFront、ALB、API Gateway、AppSync、App Runner、Cognito User Pool に関連付けられる L7 FW。

=== Web ACL の構成

- *ルール*：個別の検査ロジック
- *ルールグループ*：複数ルールの束
- *優先度*：上から評価、最初に Match した Action（Allow / Block / Count / Captcha / Challenge）が確定
- *デフォルトアクション*：どのルールにもマッチしない場合の挙動（Allow か Block）

=== ルールの種類

- *マネージドルールグループ*：AWS 公式（Core、Known Bad Inputs、Linux、PHP、SQL Injection、XSS、Bot Control など）と Marketplace（F5、Fortinet、Imperva 等）
- *カスタムルール*：IP set、文字列マッチ、正規表現、サイズ制約
- *レート制限ルール*：5分間に N リクエスト超で Block / Challenge

=== Bot Control / ATP / ACFP

- *Bot Control*：自動化されたボット検出（簡易・ターゲット）
- *Account Takeover Prevention（ATP）*：ログイン総当たり防御
- *Account Creation Fraud Prevention（ACFP）*：偽アカウント大量作成の防御

=== CAPTCHA / Challenge

- *CAPTCHA*：画像チャレンジ、有効期限長め
- *Challenge*：JavaScript 検証、ユーザー透明（自動）

=== Logging

Web ACL のログを *Kinesis Data Firehose* / S3 / CloudWatch Logs に送出。Athena でクエリして攻撃傾向を分析。

=== 料金感

- Web ACL：\$5.00/月
- ルール：\$1.00/月
- 100万リクエスト：\$0.60
- マネージドルールグループ：別料金（種類による）

== Shield

DDoS 対策。

=== Standard

- *無料・全 AWS ユーザー自動適用*
- L3/L4 の典型的な DDoS（SYN flood、UDP reflection 等）を吸収
- CloudFront / Route 53 / Global Accelerator で特に効果

=== Advanced

- 月額 \$3,000 / 1組織
- *L7 攻撃の高度検出*、*DRT（DDoS Response Team）*、*急増課金のクレジット保護*
- Health-based Detection（CloudWatch アラームと連動）
- Global threat dashboard
- *常時 Web 公開で攻撃リスク高い* 用途のみ採用検討

== Network Firewall

VPC 内のステートフル FW。Suricata 互換。

=== ルールタイプ

- *ステートレスルール*：パケット単位の許可・拒否、低レイテンシ
- *ステートフルルール*：5タプル + 接続状態、ドメインリスト、Suricata IPS シグネチャ

=== 配置

「中央 Inspection VPC」モデル（18章参照）が定石。Transit Gateway 経由で全 VPC のトラフィックを集約検査。

== Firewall Manager

組織横断のセキュリティポリシー管理。

- *WAF / Shield / Network Firewall / DNS Firewall / SG ベースライン* を組織レベルで配布
- 自動修復ポリシー（違反 SG を自動補正）
- 新規アカウント作成時に自動適用

== GuardDuty 深掘り

機械学習による継続的脅威検知。

=== データソース

- *CloudTrail Management Events*：API 操作の異常
- *VPC Flow Logs*：通信パターン
- *DNS Logs*：怪しいドメインへの問い合わせ
- *S3 Data Events*：S3 バケットへの異常アクセス
- *EKS Audit Logs*：K8s API への怪しい操作
- *Lambda Network Logs*：Lambda の通信
- *RDS Login Activity*：RDS への異常ログイン
- *Runtime Monitoring*：EC2 / ECS / EKS のホスト内挙動
- *Malware Protection*：EBS スナップショットの自動マルウェアスキャン

=== Findings の例

- `CryptoCurrency:EC2/BitcoinTool.B`：マイニング兆候
- `UnauthorizedAccess:IAMUser/ConsoleLoginSuccess.B`：海外からのコンソールログイン
- `Trojan:EC2/DropPoint`：マルウェアの中継
- `Recon:EC2/PortProbeUnprotectedPort`：未保護ポート探索

=== 抑制ルール

「特定の検証用 EC2 からの脅威 IP リストヒットは無視」のような抑制ルールを書く。

=== マルチアカウント運用

委任管理者アカウント（通常はセキュリティ専用アカウント）に集約し、組織全体の Findings を一元監視。

=== 連携

EventBridge → SNS → Slack / PagerDuty、Security Hub への自動集約、Lambda での自動隔離（SG 切替・スナップショット取得・インスタンス停止）など。

== Inspector

継続的脆弱性スキャン。

=== 対象

- *EC2*：SSM エージェント経由でパッケージ脆弱性
- *ECR*：イメージ push 時 + 定期再評価
- *Lambda*：関数コード + レイヤの脆弱性

=== 修復推奨

CVE ごとに修正バージョンが提示される。重大な脆弱性は EventBridge で通知。

== Macie

S3 上の機密データ発見・分類。

- *マネージド識別子*：PII（メール、電話、個人 ID）、認証情報、PHI、PCI など多数
- *カスタム識別子*：正規表現で社内固有の機密
- *許可リスト*：誤検知を抑制
- *Automated Sensitive Data Discovery*：継続的に小サンプルをスキャンして感度スコアを更新
- 結果は CloudWatch Events / Security Hub に流せる

== Detective

セキュリティ調査支援。

- VPC Flow Logs / CloudTrail / EKS Audit / GuardDuty Findings をグラフ統合
- *Behavior Graph*：エンティティ間の関係を時系列で可視化
- *Entity Profile*：IAM ユーザー、ロール、IP、Finding ごとに掘り下げる UI

GuardDuty で Finding を検知 → Detective でコンテキスト調査 → 修復、というフロー。

== Security Hub

セキュリティ検出の集約 + CSPM（Cloud Security Posture Management）。

=== セキュリティ標準

- *AWS Foundational Security Best Practices*
- *CIS AWS Foundations Benchmark v1.4 / v3.0*
- *PCI DSS*
- *NIST 800-53 Rev. 5*
- *NIST CSF*

各標準に対するスコアと違反コントロールを表示。

=== 統合先

GuardDuty、Inspector、Macie、Config、Firewall Manager、IAM Access Analyzer、Health などからの Findings を *統一スキーマ ASFF* で集約。サードパーティツール（Splunk、Sumo Logic、Tenable 等）も多数対応。

=== 自動修復

EventBridge で Finding を検知 → Lambda / Systems Manager Automation で修復。

== Audit Manager

統制マッピングの自動化。

- 定義済みフレームワーク：PCI DSS、HIPAA、ISO 27001、SOC 2、GDPR、AWS Operational Best Practices
- 統制ごとに *証跡を自動収集*（CloudTrail、Config、Security Hub のデータから）
- レポート生成
- カスタムフレームワーク作成も可

監査対応の手作業を大きく削減できる。

== Artifact

AWS 自体のコンプライアンスレポート（SOC 1/2/3、PCI DSS、ISO 27001/27017/27018、HIPAA、FedRAMP、IRAP 等）を取得・閲覧。NDA 付き。

== KMS 深掘り

10章では概要を、ここでは設計・運用面を扱う。

=== キーポリシーと IAM

KMS の鍵は *キーポリシー*（リソースベース）と *IAM ポリシー*（プリンシパルベース）の両方で評価される。両者の関係：

- *キーポリシーで IAM 委任を許可していなければ*、IAM ポリシーは効かない
- 作成直後は「ルートユーザーが全権限」のキーポリシーが入っており、ここから絞っていく

=== 自動ローテーション

CMK は *年次自動ローテーション* を有効化できる（2022年以降カスタマー管理キーで対応）。新しいバッキングキーが作られ、復号は古い・新しい両方で可能。

=== Multi-Region Keys

複数リージョンで *同じキー ID* を持つ鍵セット。レプリケーション時に各リージョン独立に管理されるが、暗号文を相互に復号できる。マルチリージョン構成で必須。

=== エンベロープ暗号化

KMS は *データキー（DEK）* を発行し、それで実データを暗号化する方式を推奨する。

```
KMS マスターキー
    ↓ GenerateDataKey
Plaintext DEK + Encrypted DEK
    ↓ DEK でアプリが暗号化
Ciphertext + Encrypted DEK（一緒に保存）
復号時：Encrypted DEK を KMS Decrypt → Plaintext DEK → 復号
```

KMS 自体は小さなデータしか扱わない。実データの暗号化はクライアント側で。

=== Grants

一時的な権限委譲。Lambda が一時的に KMS 鍵を使う必要があるが IAM ポリシーで広く付与したくない、といった場合に。

== CloudHSM

FIPS 140-3 Level 3 のシングルテナント HSM。KMS では満たせない厳格な規制要件向け。クラスタ管理、PKCS#11 / JCE / KSP / CNG 経由で利用。

=== 用途

- 認証局（CA）の秘密鍵保管
- BYOK（KMS の Import Key Material）の元鍵
- 規制要件で「自社が物理鍵を所有」と求められる場合

== Secrets Manager 深掘り

=== 自動ローテーション

Lambda を使って RDS / Aurora / Redshift / DocumentDB のパスワードを自動ローテーション。AWS 提供のローテーションテンプレートを利用するのが楽。カスタムリソースでも書ける。

=== Cross-Region Replication

マルチリージョン DR で必須。プライマリ Secret の更新が自動でセカンダリへ伝播。

=== リソースベースポリシー

別アカウントからのアクセスを許可。

=== VPC エンドポイント

`com.amazonaws.<region>.secretsmanager` のインタフェースエンドポイントで、プライベートサブネットからインターネット経由なしで取得。

=== Parameter Store との使い分け（再掲）

- *Parameter Store*：設定値・軽い秘密。基本無料
- *Secrets Manager*：自動ローテーション・本格的な秘密。1秘密 \$0.40/月

=== コードサンプル

```python
import boto3, json
sm = boto3.client('secretsmanager')
resp = sm.get_secret_value(SecretId='prod/db/master')
creds = json.loads(resp['SecretString'])
db_password = creds['password']
```

== Certificate Manager（ACM）

=== パブリック証明書

DNS 検証 / メール検証で発行。自動更新（残り60日でドメイン検証チェック → 30日で更新）。

- *ALB / NLB / API Gateway / App Runner*：同一リージョンで取得
- *CloudFront*：us-east-1 で取得（必須）

=== Private CA（ACM PCA）

社内 PKI のマネージド CA。エンドエンティティ証明書、サブ CA、CRL、OCSP を全部管理。料金は CA \$400/月 + 証明書発行ごと。

=== ACM の制限

- 自動更新のためには *ALB / CloudFront 等の ACM 統合サービスで使用中* である必要
- 単独で証明書だけダウンロードしてサーバに置く、はパブリック証明書では不可（PCA なら可）

== CloudTrail Lake

CloudTrail の SQL ベース分析サービス。

- *イベントデータストア*：保管期間最長10年
- SQL でクエリ（Athena 不要）
- *フェデレーテッドクエリ*：CloudTrail Lake から Glue Data Catalog 経由で他データソースに JOIN

監査調査での「あの API を誰がいつ呼んだ」を高速に。

== IAM Access Analyzer 深掘り

=== 外部アクセス分析

S3、IAM、KMS、Lambda、SQS、Secrets Manager、SNS、ECR、EFS リソースが *外部（別アカウント・別組織・パブリック）* からアクセス可能になっていないかを継続検出。

=== 未使用アクセス分析

IAM ロール・ユーザーの権限のうち、*過去 X 日間使われていないアクション・サービス* を検出。最小権限への絞り込みに活用。

=== Policy Generation

CloudTrail ログから *実際に使われたアクション* を抽出して必要最小ポリシーを生成。

=== カスタムポリシーチェック

CI/CD 統合用 API。「このポリシー変更が *新たな外部アクセスを許可していないか*」を Pull Request で自動チェック。

=== Reachability

VPC リソース（EC2 等）にどの経路で到達可能かを可視化。

== セキュリティ運用ベストプラクティス

- *監査専用アカウント* に GuardDuty / Security Hub / CloudTrail / Config を集約
- 検知 → トリアージ → 修復のループを *EventBridge + Lambda* で自動化
- *IaC でガードレール*：SCP・Config Rules・Permission Boundary・ABAC
- 「想定外の操作を起こさせない」設計（事後対応より事前防止）
- インシデント対応 *Runbook を Systems Manager Automation* に登録
- 定期的な *ペンテスト・カオス演習*
- *人間のアクセス記録* を Source Identity で追跡可能に

== インシデント対応の典型フロー

```
1. 検知    GuardDuty Finding → EventBridge
2. 通知    SNS → Slack / PagerDuty
3. 隔離    Lambda：SG を quarantine SG に切替、IAM 権限剥奪
4. 調査    Detective でグラフ調査、CloudTrail Lake で操作履歴
5. 修復    SSM Automation でパッチ・キーローテーション
6. 復旧    バックアップから復元、Auto Scaling で再構築
7. 振り返り 報告書作成、Runbook / SCP / Rule 改善
```

== よくあるトラブル

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*症状*], [*対処*]),
  [WAF が誤検知で正常を Block], [Logs を見て対象ルールを Count に切替、例外 IP / URI 追加],
  [GuardDuty 通知が止まらない], [抑制ルール、検証用環境のタグ・IP 除外],
  [Inspector で誤検知], [Suppression Rule、CVE スコアでフィルタ],
  [Macie がスキャンしない], [対象バケットのジョブ作成、IAM 権限],
  [KMS で AccessDenied], [キーポリシー優先、IAM 委任、CloudTrail で `kms:*` イベント確認],
  [ACM 自動更新が走らない], [統合サービスで使用中か、DNS 検証レコードが残っているか],
  [CloudTrail Lake が遅い], [パーティション設計、データストアの段階的圧縮],
)
