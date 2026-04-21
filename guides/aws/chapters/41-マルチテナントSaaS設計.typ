= マルチテナント SaaS 設計

複数の顧客（テナント）に同じシステムを提供する SaaS の設計パターンを、AWS 上での実装と合わせて扱う。テナント分離戦略、課金、オンボーディング、運用、セキュリティを横断する。

== マルチテナンシーの3モデル

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*モデル*], [*概要*]),
  [Silo], [テナントごとに独立リソース（VPC・DB・アカウント単位）],
  [Pool], [全テナントで共通リソース、論理分離],
  [Bridge], [一部 Pool、一部 Silo（ハイブリッド）],
)

=== Silo モデル

```
Tenant A → 独立 AWS アカウント / VPC / DB
Tenant B → 独立 AWS アカウント / VPC / DB
```

メリット：

- 強い分離性、相互影響なし
- リソース上限・課金がテナント単位で明確
- 規制要件への対応が楽

デメリット：

- 運用コスト・人件費が高い
- ベースインフラが各テナントに発生
- アップデート展開に時間がかかる

主に *エンタープライズ顧客*、*高規制業界*（金融・医療）向け。

=== Pool モデル

```
1つの ECS / EKS / Lambda + 1 DynamoDB / Aurora
全テナントが同じインフラ上で動作
論理的にテナント ID で分離
```

メリット：

- 規模の経済で低コスト
- アップデート反映が早い
- リソース効率が良い

デメリット：

- *Noisy Neighbor*（特定テナントが大量消費すると他に影響）
- 分離強度が低い
- 「うちは何リソース使っている」が見えにくい

主に *中小企業向け SaaS*、*FreeTier がある B2C 向け*。

=== Bridge モデル

```
Compute は Pool（共通 ECS）
DB は Silo（テナントごとに別 RDS）
ストレージは Pool（共通 S3、プレフィクス分離）
```

実用上ほとんどの SaaS は Bridge。「分離強度が必要な層は Silo、効率重視は Pool」。

== AWS SaaS Builder Toolkit / SaaS Boost

AWS 公式の SaaS リファレンス。CDK ベースで Silo / Pool / Bridge 各モデルの構成例を提供。学習・PoC のスタート地点として有用。

== テナント識別と分離

=== テナント ID の埋め込み

JWT クレーム → 全リクエストに `tenant_id` を伝播。

```python
# Lambda での例
def handler(event, context):
    claims = event['requestContext']['authorizer']['jwt']['claims']
    tenant_id = claims['custom:tenant_id']
    # 以降、すべてのクエリに tenant_id を含める
    item = ddb.get_item(Key={'PK': f'TENANT#{tenant_id}#USER#{user_id}'})
```

=== ABAC でデータ分離

IAM の `Condition` で `aws:PrincipalTag/TenantId` を使い、テナントの DynamoDB 行・S3 プレフィクスへのアクセスを限定。

```json
{
  "Effect": "Allow",
  "Action": ["dynamodb:GetItem", "dynamodb:Query"],
  "Resource": "arn:aws:dynamodb:*:*:table/Tenants",
  "Condition": {
    "ForAllValues:StringEquals": {
      "dynamodb:LeadingKeys": ["${aws:PrincipalTag/TenantId}"]
    }
  }
}
```

```json
{
  "Effect": "Allow",
  "Action": "s3:GetObject",
  "Resource": "arn:aws:s3:::saas-data/*",
  "Condition": {
    "StringLike": {
      "s3:prefix": ["${aws:PrincipalTag/TenantId}/*"]
    }
  }
}
```

Cognito Pre Token Generation Lambda で `tenant_id` を *セッションタグ* に埋める。

=== Lambda での Assume Role-by-tenant

リクエストごとに *テナント専用の限定ロール* を Assume：

```python
sts = boto3.client('sts')
resp = sts.assume_role(
    RoleArn='arn:aws:iam::...:role/TenantBaseRole',
    RoleSessionName=f'tenant-{tenant_id}',
    Tags=[{'Key': 'TenantId', 'Value': tenant_id}],
    PolicyArns=[],
)
tenant_creds = resp['Credentials']
# 以降のリソース操作はこの一時認証で
```

これで *コードバグでもクロステナント漏洩を防止* できる。

== データストアの分離パターン

=== DynamoDB

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*パターン*], [*説明*]),
  [テナントごとに別テーブル], [Silo。テナント数大なら管理大変],
  [PK プレフィクスにテナント ID], [Pool。`TENANT#X#USER#Y`],
  [テーブル + GSI で混合], [Pool かつ多角的アクセスパターン],
)

Pool パターンが圧倒的に運用コスト低い。Single Table Design（31章）と相性◎。

=== Aurora / RDS

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*パターン*], [*説明*]),
  [Cluster ごと別], [完全分離。料金高],
  [Database ごと別（同一 Cluster）], [中庸。`CREATE DATABASE` で論理分離],
  [Schema ごと別], [PostgreSQL の `SET search_path`],
  [Row Level Security], [すべて1テーブルに、`tenant_id` 列で分離],
)

PostgreSQL の *Row Level Security（RLS）* が最も柔軟：

```sql
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON orders
  USING (tenant_id = current_setting('app.current_tenant')::uuid);

-- アプリ接続時
SET app.current_tenant = 'tenant-uuid';
```

=== S3

```
s3://my-saas-data/
  tenants/
    tenant-A/
      orders/
      uploads/
    tenant-B/
      orders/
      uploads/
```

プレフィクスでの分離 + IAM Condition。バケットポリシーは1つで済む。

== 認証・ID 管理

=== Cognito User Pool 戦略

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*パターン*], [*説明*]),
  [テナントごと別 User Pool], [完全分離。テナント追加でプール作成オーバーヘッド],
  [1つの User Pool でカスタム属性], [`custom:tenant_id` でラベル付け、Pre Token で JWT に],
  [Identity Federation], [テナントの IdP（SAML/OIDC）連携、企業向け],
)

Cognito User Pool は *1リージョンで最大1000プール* なので Silo はテナント数次第で破綻。

=== マルチテナント JWT

```json
{
  "sub": "user-uuid",
  "email": "user@example.com",
  "custom:tenant_id": "tenant-uuid",
  "custom:roles": ["admin"],
  "iss": "https://cognito-idp...",
  "aud": "client-id"
}
```

API Gateway JWT Authorizer で検証 → Lambda で `tenant_id` を取り出し、すべての処理に伝播。

== オンボーディング

新規テナント登録時の自動化フロー：

```
[新規申し込み]
  → Lambda（onboarding）
     ├ Cognito にテナント管理者ユーザー作成
     ├ DynamoDB に Tenant メタデータ
     ├ S3 プレフィクス作成
     ├ Silo の場合：CloudFormation StackSet で専用リソース作成
     ├ サブドメイン割当（Route 53）
     └ ウェルカムメール送信
```

Step Functions で長時間ワークフローとして組むのが定石。

=== Tier 別オンボーディング

- *Free / Starter*：Pool に追加するだけ（数秒）
- *Standard*：Pool + 専用 DB schema
- *Enterprise / Premium*：Silo（専用 VPC / DB / 場合によってアカウント）

== 課金とメータリング

=== 利用量計測

各テナントの使用量を継続収集：

```python
# CloudWatch EMF メトリクスでテナント別の使用量を出力
metrics.add_dimension(name='TenantId', value=tenant_id)
metrics.add_metric(name='APICall', unit='Count', value=1)
metrics.add_metric(name='StorageBytes', unit='Bytes', value=size)
```

CloudWatch → Athena / QuickSight で月次集計。

=== AWS Marketplace 統合

SaaS を AWS Marketplace で販売する場合：

- *Subscription*：固定月額
- *Contract Pricing*：1〜3年契約
- *Pay-as-you-go（Metered）*：使用量に応じて
- *Free Trial*

利用量は AWS Marketplace Metering Service API で送信。請求は AWS が代行。

=== Stripe / Recurly 等の外部請求基盤

AWS Marketplace 以外の場合、Stripe / Recurly / Chargebee と連携。

== Tier 別リソース割当

```
Free Tier:    Pool, レート 100 req/min, ストレージ 1 GB
Standard:     Pool, レート 1,000 req/min, ストレージ 100 GB
Enterprise:   Bridge / Silo, 専用 DB, SLA 99.95%
```

=== レート制限

API Gateway *Usage Plan* + API Key（テナントごと）。または ALB / WAF レート制限。Lambda 同時実行数 *Reserved Concurrency* で Tier 分離。

=== 物理分離（Tier 別）

- Free / Standard：共通 Lambda + DynamoDB（On-Demand）
- Enterprise：専用 Lambda（Provisioned Concurrency）+ 専用 Aurora

== Noisy Neighbor 対策

Pool モデルの最大の課題。

- *レート制限*：API Gateway / WAF / Lambda Reserved Concurrency
- *DynamoDB 書き込みシャーディング*：高負荷テナントのキー分散
- *Cell-based Architecture*：複数の小規模 Pool に分け、テナントを Cell に割当（特定 Cell 障害が他 Cell に波及しない）
- *モニタリング*：テナント別の SLA 違反検知 → 別 Cell / Tier 移動

=== Cell-based Architecture

```
Region: ap-northeast-1
├ Cell-1 (Pool: 1,000 テナント収容)
│  ├ ECS, DynamoDB, ElastiCache
│  └ Tenants: A, B, C, ...
├ Cell-2
│  └ Tenants: D, E, F, ...
└ Cell-N
   └ Tenants: ...

ルーティング層（CloudFront → Lambda\@Edge）でテナント → Cell マッピング
```

Cell 単位で *分離・スケール・障害爆発半径制限*。

== 観測性

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*指標*], [*収集方法*]),
  [テナント別 API リクエスト], [EMF メトリクス（TenantId Dimension）],
  [テナント別エラー率], [CloudWatch Logs Insights で集計],
  [テナント別レスポンス時間], [X-Ray + Application Signals],
  [テナント別ストレージ使用量], [S3 Storage Lens、DynamoDB Metrics],
  [テナント別コスト], [Cost Allocation Tags + Cost Categories],
  [SLA 違反検知], [テナント別 Composite Alarm],
)

=== カーディナリティに注意

CloudWatch Metrics の *Dimension* にテナント ID を入れると、テナント数 × メトリクス数 の組み合わせ爆発で *コスト高騰*。

対策：

- 上位 N テナント（高トラフィック）だけ Dimension に
- Logs Insights / Athena 経由で集計
- *Datadog 等の高カーディナリティ対応 SaaS* を検討

== セキュリティ

=== Tenant Isolation のテスト

以下を *自動テスト* に組み込む：

- Tenant A の認証で Tenant B のリソースにアクセス → 失敗を確認
- IAM Policy Simulator で疑似シナリオ
- *Continuous Penetration Testing*

=== 暗号化

- *KMS Multi-tenant key* vs *Tenant-specific key*
- Tenant 別 key（CMK）：強い分離、コスト・運用増
- 共通 key + Encryption Context にテナント ID：実質テナント分離、運用低

```python
kms.encrypt(
    KeyId='alias/saas',
    Plaintext=data,
    EncryptionContext={'TenantId': tenant_id}
)
```

復号時に Encryption Context が一致しないと失敗 → クロステナント漏洩防止。

=== コンプライアンス

- *データ residency*：テナントのリージョン要件（GDPR、APPI、HIPAA）
- *監査*：CloudTrail にテナント操作を記録、Audit Manager で証跡化
- *PII / PCI*：Macie で機密データ検出

=== Per-Tenant の権限境界

各テナントの管理者ロールに *Permissions Boundary* を設定し、テナント外への権限拡張を物理的に防止。

== 運用

=== マイグレーション戦略

- *Dual Write*：旧スキーマと新スキーマの両方に書き、徐々に切替
- *Feature Flag* でテナント単位ロールアウト
- *Canary Tenant*：少数の信頼できるテナントで先行検証

=== バックアップとリストア

Pool モデルでは「特定テナントだけリストア」が難しい。対策：

- DynamoDB：テナント別 PITR + ETL で別テーブル復元
- Aurora：論理バックアップ（`pg_dump` の WHERE 句）
- *イベントソーシング*：イベントログから再構築

=== テナント解約・退会

- データを *エクスポート* して提供（GDPR の *Right to Data Portability*）
- 一定期間後に削除（*Right to be Forgotten*）
- 削除実行を CloudTrail / Logs に記録

== 参考実装

AWS SaaS Factory Reference Architecture：CDK ベースで Pool / Silo / Bridge の各モデル実装が公開。

ECS Pool モデル / EKS マルチテナント / DynamoDB Single Table の SaaS 例が GitHub で参照可能。

== 設計判断のチェックリスト

- [ ] テナント分離レベル（Silo / Pool / Bridge）を文書化
- [ ] テナント ID の伝播経路（JWT → アプリ → DB → ログ）を設計
- [ ] ABAC / Permissions Boundary でクロステナント防止
- [ ] Tier 別の SLA / リソース割当・課金モデル
- [ ] Noisy Neighbor 対策（レート制限、Cell）
- [ ] テナント別観測性（カーディナリティ管理）
- [ ] オンボーディング・解約の自動化
- [ ] バックアップ・リストアのテナント単位対応
- [ ] コンプライアンス（リージョン、データ residency）
- [ ] テナント分離の自動テスト

== よくある罠

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*罠*], [*対策*]),
  [初期から Silo で破綻], [Pool 始まり、必要時に Tier 別に Silo に],
  [テナント ID 伝播の漏れ], [型レベルで強制（TypeScript の Branded Type 等）],
  [Noisy Neighbor で SLA 違反], [Cell、レート制限、Tier 移動],
  [Cognito Pool 上限], [カスタム属性で Pool 共用],
  [メトリクスのカーディナリティ爆発], [Top-N、Logs Insights、Datadog],
  [テナントデータの誤露出], [自動分離テスト、ABAC],
  [リストアが個別不可], [イベントソーシング、PITR + ETL],
  [課金モデルの後付け変更], [最初から Cost Allocation Tags、メータリング],
)
