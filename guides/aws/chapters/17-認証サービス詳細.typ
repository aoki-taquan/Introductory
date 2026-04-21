= 認証サービスの詳細

3章では IAM そのものを扱った。本章は IAM を補完・拡張する周辺サービス、特に *Cognito*（自社アプリのエンドユーザー）、*IAM Identity Center 詳細*、*Directory Service*、*Verified Permissions*、*Resource Access Manager*、*IAM Roles Anywhere* を扱う。

== アイデンティティの種類と AWS の選択肢

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*アイデンティティ種別*], [*AWS の選択肢*]),
  [AWS リソースを操作する人間], [IAM Identity Center（推奨） or IAM ユーザー],
  [マシン・ワークロード], [IAM Role + 一時認証情報、IAM Roles Anywhere],
  [自社アプリのエンドユーザー], [Cognito User Pools],
  [自社アプリ → AWS リソース利用], [Cognito Identity Pools（フェデレーション）],
  [社員（社内 IdP）], [IAM Identity Center + 外部 IdP 連携],
  [オンプレ AD 統合], [Directory Service / AD Connector],
  [きめ細かなアプリ内認可], [Verified Permissions],
)

「人間は Identity Center、マシンは Role、エンドユーザーは Cognito」が現代の指針。

== IAM Identity Center 詳細

2章では概要を、本節は実運用の細部を扱う。

=== アイデンティティソース

3つの中から1つを選ぶ。

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*ソース*], [*用途*]),
  [Identity Center directory], [Identity Center 自前のディレクトリ。小〜中規模],
  [Active Directory], [既存 AD（オンプレ or AWS Managed AD）],
  [外部 IdP（SAML 2.0 / SCIM）], [Microsoft Entra ID、Okta、Google Workspace、OneLogin、JumpCloud 等],
)

外部 IdP 連携が現代企業の標準。SCIM プロビジョニングでユーザー・グループを自動同期し、SSO で SAML 認証する。

=== 許可セット（Permission Sets）

許可セットは「IAM ロール＋ポリシーの組み合わせを Identity Center 用にラップしたもの」と理解してよい。

- *AWS マネージドポリシーベース*：`AdministratorAccess`、`ReadOnlyAccess` を貼るだけ
- *カスタマー管理ポリシーベース*：自前ポリシー名を指定（各アカウント側にもポリシーが存在している前提）
- *カスタムインラインポリシー*：許可セット内に直書き
- *Permissions Boundary 付き*

許可セットを *AWS アカウント × ユーザー／グループ* に割り当てると、対象アカウントに自動的に `AWSReservedSSO_<許可セット名>_<ハッシュ>` というロールが作成される。

=== ABAC（Attribute-Based Access Control）

属性ベースアクセス制御。IdP 側のユーザー属性を *セッションタグ* として渡し、IAM ポリシーの `Condition` で評価する。

```json
{
  "Effect": "Allow",
  "Action": "s3:*",
  "Resource": "arn:aws:s3:::project-*/*",
  "Condition": {
    "StringEquals": {
      "aws:ResourceTag/Project": "${aws:PrincipalTag/Project}"
    }
  }
}
```

「ユーザーの `Project` 属性と同じ値のリソースタグなら許可」というポリシー。アカウント・ロールを増やさずに、属性追加だけで権限管理が回る。

=== セッション管理

- 許可セットごとにセッション期間（1〜12時間）
- 強制サインアウト、リフレッシュトークン
- CLI で `aws sso login` 後、`~/.aws/sso/cache/` に短期トークンが置かれる

=== 監査

Identity Center 側の操作は CloudTrail に `eventSource = sso.amazonaws.com` で記録される。許可セット変更、ユーザー作成、SSO ログインなどを監視。

=== 移行（IAM ユーザーから Identity Center へ）

+ Organizations を有効化（未なら）
+ Identity Center を有効化（リージョン1つを選定）
+ アイデンティティソースを決定（最初は Identity Center directory で開始可）
+ 許可セットを作成（最低 `AdministratorAccess` と `ReadOnlyAccess`）
+ ユーザー／グループに割り当て
+ 既存 IAM ユーザーから順次切替、切替完了後にアクセスキー失効

== Cognito

エンドユーザー向けのサインアップ・サインイン・認可基盤。User Pools と Identity Pools の2系統がある。

=== User Pools（ユーザーディレクトリ）

サインアップ・ログイン・MFA・パスワードポリシー・パスワードリセット・属性管理を一手に提供。

主な機能：

- サインアップ／サインイン（メール・電話番号・ユーザー名）
- メール／SMS の検証
- パスワードポリシー
- MFA（TOTP・SMS）、*passkey（WebAuthn）も対応*
- カスタム属性（`custom:tenant_id` など）
- *Lambda トリガー*：Pre Sign-up、Post Confirmation、Pre Token Generation、Custom Message など
- *Hosted UI*：AWS が提供するサインインページ（カスタマイズ可）
- ソーシャル連携：Google、Apple、Facebook、Amazon
- 企業 IdP 連携：SAML、OIDC
- *Advanced Security Features*：適応型認証、リスクスコア、漏洩 Cred 検知

=== Identity Pools（フェデレーション）

認証済みユーザー（Cognito UP・Google・Apple・Twitter・SAML / OIDC IdP）に *AWS リソースアクセス用の一時認証情報* を発行する。

ユースケース：モバイルアプリから *DynamoDB / S3 へ直接アクセス* したい場合に、ユーザーごとに細かく権限を切る。

=== User Pool と Identity Pool の関係

```
[Cognito User Pool] → JWT
                     ↓
       [Identity Pool] → AWS 一時認証情報 → S3 / DynamoDB
```

User Pool は「認証」、Identity Pool は「AWS リソースの認可」。両方使う構成も、User Pool だけ・Identity Pool だけの構成もありえる。

=== 典型構成：SPA + API Gateway + Lambda

```
[Browser] → Cognito Hosted UI → JWT
[Browser] → API Gateway（JWT Authorizer） → Lambda → DynamoDB
```

最も多用される。API Gateway HTTP API の JWT オーソライザーで `Bearer <id_token>` を検証する。

=== マルチテナンシー設計

- *物理分離*：テナント = Cognito User Pool。完全分離だが管理コスト高
- *論理分離*：1つの User Pool でカスタム属性 `tenant_id` を保持、Pre Token Generation Lambda で JWT に埋め、ABAC でリソース分離

=== Cognito の料金感

- *MAU 課金*（無料枠：50,000 MAU/月）
- *Advanced Security Features* は別料金（MAU 単価が上がる）
- M2M（マシン間）クライアントクレデンシャルフロー：APIコール課金

== Directory Service

Active Directory 連携の3形態。

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*種類*], [*用途*]),
  [AWS Managed Microsoft AD], [マネージド AD。本格的な Windows 統合],
  [AD Connector], [既存オンプレ AD への中継。AD のみ提供],
  [Simple AD], [Samba ベース。小規模・機能限定],
)

利用例：

- *FSx for Windows File Server*：AD ユーザー認証
- *Workspaces*（仮想デスクトップ）：AD でユーザー管理
- *RDS for SQL Server*：Windows 認証
- *EC2 ドメイン参加*：Windows / Linux

オンプレ AD があるなら *AD Connector* で AWS 側からも参照、新規なら *Managed Microsoft AD*。

== Verified Permissions

*Cedar 言語* によるきめ細かな認可サービス。アプリケーション内の「誰が／どのリソースに／何ができるか」を中央管理する。

```cedar
permit(
    principal in Group::"editors",
    action == Action::"updateDocument",
    resource
)
when {
    resource.owner == principal ||
    resource.collaborators.contains(principal)
};
```

- API Gateway の Lambda オーソライザーから呼び出し
- アプリ内のチェックポイントから SDK で呼び出し
- *Open Source* な Cedar をローカルでも使え、Verified Permissions はマネージドホスティング層

ABAC が IAM レベルなら、Verified Permissions はアプリレベル。複雑な業務認可ロジックを *コード分散させない* のが利点。

== Resource Access Manager（RAM）

アカウント間でリソースを共有する仕組み。

=== 共有可能な代表リソース

- *Subnet*（VPC 共有）
- *Transit Gateway*
- *License Manager License Configuration*
- *Resolver Rule*
- *Route 53 Profiles*
- *AWS Config Aggregator*
- *Aurora DB Cluster snapshot*
- *Glue Data Catalog database / table*

Organizations 配下のアカウントには *自動承認* で共有可能。明示的に外部アカウントにも共有できる。

=== マルチアカウント・ネットワークの実例

中央のネットワーク管理アカウントで Transit Gateway と Subnet を作成し、RAM で各ワークロードアカウントに共有 → 各アカウントは「自分の VPC」として Subnet を見る。ネットワーク変更を中央集約できる。

== IAM Roles Anywhere

オンプレ・他クラウドのワークロードに *X.509 証明書ベース* で AWS 一時認証情報を払い出す。

=== 構成要素

- *Trust Anchor*：信頼する CA（プライベート CA か Customer CA）
- *Profile*：付与する IAM ロールと制約
- *credential-helper*：オンプレ側で証明書を提示し一時認証を取得するクライアント

```bash
# AWS CLI に credential_process として組み込む
[profile onprem-app]
credential_process = /opt/aws_signing_helper credential-process \
  --certificate /etc/pki/cert.pem \
  --private-key /etc/pki/key.pem \
  --trust-anchor-arn arn:aws:rolesanywhere:ap-northeast-1:123456789012:trust-anchor/xxxx \
  --profile-arn arn:aws:rolesanywhere:ap-northeast-1:123456789012:profile/yyyy \
  --role-arn arn:aws:iam::123456789012:role/onprem-role
```

オンプレで *長期アクセスキーを持たずに* AWS リソースを使えるのが最大の利点。

== STS と一時認証情報

AWS Security Token Service（STS）が一時認証情報の発行を司る。

=== 主要 API

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*API*], [*用途*]),
  [AssumeRole], [別ロールに切り替え（自分 → 別アカウントロール、開発 → 本番ロール）],
  [AssumeRoleWithWebIdentity], [OIDC IdP（GitHub Actions、Cognito、Google）からロール引き受け],
  [AssumeRoleWithSAML], [SAML IdP からロール引き受け],
  [GetSessionToken], [MFA 強制つき同一プリンシパルの一時認証],
  [GetFederationToken], [既存 IAM ユーザーからフェデレーテッドユーザー作成],
)

=== 一時認証情報の有効期限

- 標準：15分〜12時間（ロール側の MaxSessionDuration で制御）
- ロール連鎖（Role Chaining）：最大1時間
- IAM Identity Center 経由：許可セットで設定

=== Source Identity の伝播

`AssumeRole` 時に `SourceIdentity` を渡すと、後続のすべての API 呼び出しに引き継がれ、CloudTrail に記録される。「フェデレーション元の人間」をログから特定できる。

=== ロール連鎖の制約

A ロールから B ロールを Assume すると、B から C を Assume するときの最大期間が *1時間に制限* される。長時間処理ではロール構造を見直す。

== 認証関連のベストプラクティス

- *人間は Identity Center、マシンは IAM Roles + STS、エンドユーザーは Cognito*
- ルートユーザーには passkey/FIDO2、アクセスキーなし
- 外部 IdP（Entra/Okta/Google Workspace）と SCIM で自動同期
- *ABAC* で権限管理を属性ベースに（タグ／属性が増えても権限が爆発しない）
- フェデレーション（SAML / OIDC）を優先、長期キーは避ける
- *MFA / passkey をすべてのプリンシパルに*
- Cognito の Pre Token Generation Lambda は短く保つ（コールドスタートが UX を壊す）
- Verified Permissions でアプリ内認可ロジックを中央化

== マルチアカウント運用とのつながり

Identity Center は Organizations と切っても切れない関係にある。マルチアカウント運用は20章で扱うが、認証の観点では「*Identity Center を中央アカウントで有効化し、Organizations 配下の全アカウントへ許可セットを割り当てる*」のが基本形。

== よくあるトラブル

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*症状*], [*対処*]),
  [Cognito Hosted UI のドメイン取れない], [グローバル一意性、AWS 既存ドメインとの衝突回避],
  [SAML 連携でロール候補が出ない], [Role Mapping の SAML attribute、`https://aws.amazon.com/SAML/Attributes/Role`],
  [SCIM プロビジョニングが進まない], [属性マッピング、グループ階層、API トークン期限],
  [Identity Center CLI が AccessDenied], [`aws sso login` 再実行、許可セット再割り当て後はログイン更新必須],
  [AssumeRole 失敗], [信頼ポリシーの Principal、ExternalId、SourceIdentity 整合],
  [Pre Token Generation で JWT 壊れる], [Lambda の戻り値が claims を上書きしている、ペイロード超過],
  [Cognito の \`User does not exist\`], [サインインフロー（USER\_PASSWORD\_AUTH 等）の有効化、ユーザー存在検出設定],
  [IAM Roles Anywhere 401], [Trust Anchor の証明書チェーン、CRL、時刻ずれ],
)
