= IAM（認証・認可）

*IAM（Identity and Access Management）* は、「誰が（認証）」「何を（認可）」できるかを管理する AWS のセキュリティ基盤である。どのサービスを使うにしても IAM が土台になるため、最初に理解しておきたい。

== IAMの主要コンポーネント

=== 4つの基本要素

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*要素*], [*説明*]),
  [ユーザー（User）], [個人や単一のアプリに紐づく長期的なアイデンティティ],
  [グループ（Group）], [複数ユーザーをまとめる単位。グループにポリシーをアタッチできる],
  [ロール（Role）], [一時的に引き受けるアイデンティティ。EC2 や Lambda、他アカウントに付与する],
  [ポリシー（Policy）], [JSON で書かれた許可／拒否のルール],
)

ポリシーを直接ユーザー／ロールにアタッチすることもできるし、グループ経由でアタッチすることもできる。

=== 認証と認可の流れ

+ *認証（AuthN）*：API コール時に、アクセスキー or 一時認証情報 or SSO によって「誰か」が特定される
+ *認可（AuthZ）*：そのプリンシパルに付与されたポリシーと、対象リソース側のポリシーを評価して許可／拒否が決まる
+ *明示的 Deny* はどのポリシーの Allow も上書きする

== IAMポリシーの構造

ポリシーは JSON で記述される。以下は S3 バケットへの読み取りを許可する最小例である。

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ReadMyBucket",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::my-bucket",
        "arn:aws:s3:::my-bucket/*"
      ]
    }
  ]
}
```

=== 主要フィールド

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*フィールド*], [*意味*]),
  [Version], [必ず `2012-10-17` と書く（現行仕様の識別子）],
  [Effect], [`Allow` または `Deny`],
  [Action], [許可／拒否する API アクション。`s3:*` のようにワイルドカードも可],
  [Resource], [対象リソースの ARN（Amazon Resource Name）],
  [Condition], [IP、MFA、時刻など追加条件を指定],
  [Principal], [リソースベースポリシー（後述）で対象プリンシパルを指定],
)

=== ARN（Amazon Resource Name）

AWS のあらゆるリソースは ARN と呼ばれる一意の識別子を持つ。

```
arn:aws:<service>:<region>:<account-id>:<resource>
```

例：
- `arn:aws:s3:::my-bucket`（S3 はリージョンとアカウント ID が空）
- `arn:aws:ec2:ap-northeast-1:123456789012:instance/i-0abcd1234efgh5678`
- `arn:aws:iam::123456789012:role/EC2-S3-ReadOnly`

ポリシーの `Resource` 指定では ARN を使う。

=== 条件（Condition）

アクセス元 IP、時刻、MFA の有無などで制御を追加できる。典型的なのは「*MFA なし、または 社外 IP のいずれか* に該当したら拒否する」ポリシー。

*注意*：1つの `Statement` 内に書いた複数の `Condition` 演算子は *AND 結合* される。したがって「MFA なし *または* 社外 IP を拒否」を表現するには、*Statement を2つに分ける* 必要がある。

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyWithoutMfa",
      "Effect": "Deny",
      "Action": "*",
      "Resource": "*",
      "Condition": {
        "BoolIfExists": { "aws:MultiFactorAuthPresent": "false" }
      }
    },
    {
      "Sid": "DenyOutsideCorpIp",
      "Effect": "Deny",
      "Action": "*",
      "Resource": "*",
      "Condition": {
        "NotIpAddress": { "aws:SourceIp": ["203.0.113.0/24"] }
      }
    }
  ]
}
```

*`Allow` 側の Condition ではなく `Deny` 側で書くのがセオリー* である。`Allow` + ワイルドカードリソース + Condition の組み合わせは、`Condition` が条件を満たすときに *過剰な権限を与えてしまう* 危険がある。アクセス制限は「してはいけないケースを Deny で塞ぐ」方向で設計する。*「AND で繋ぎたいのか OR で繋ぎたいのか」を Statement の分け方で明示* する習慣を付ける。

=== 必要な IAM アクションの調べ方

実運用では「権限不足エラーが出た → 何を足せばよいか」を特定する場面が多い。次の経路で調べられる。

- *エラーメッセージ*：`not authorized to perform: ec2:TerminateInstances` のように必要アクション名がそのまま書かれる
- *CloudTrail*：実行したい操作をまず権限ありで実行し、ログから `eventName` と `eventSource` を抜く
- *IAM Access Analyzer Policy Generation*：実際の使用ログから必要最小のポリシーを自動生成
- *IAM Policy Simulator*：ポリシー適用前に特定アクションが通るか試せる
- *サービスの公式ドキュメント*：各サービスの "Actions, resources, and condition keys" ページに列挙されている

== ポリシーの種類

=== 管理ポリシーとインラインポリシー

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*種類*], [*説明*]),
  [AWS 管理ポリシー], [AWSが提供する既製ポリシー。`AdministratorAccess`、`ReadOnlyAccess` など],
  [カスタマー管理ポリシー], [利用者が作成する独立したポリシー。複数のユーザー／ロールにアタッチできる],
  [インラインポリシー], [ユーザー／ロールに直接埋め込む。1対1で紐づくため他にアタッチできない],
)

運用上は *カスタマー管理ポリシー* を作って再利用するのが望ましい。

=== アイデンティティベースとリソースベース

- *アイデンティティベースポリシー*：IAM ユーザー／グループ／ロールにアタッチする
- *リソースベースポリシー*：S3 バケット、SQS キュー、Lambda 関数などリソース側に定義する

S3 バケットポリシー、Lambda のリソースベースポリシー、KMS キーポリシーなどは後者の代表例である。

=== SCP（サービスコントロールポリシー）

AWS Organizations 配下で、アカウントそのものに対して使える機能を制限する。親アカウントから子アカウントへのガードレールとして機能する。例：「東京・大阪以外のリージョンでの API 実行を全面禁止」。

== ロールと一時認証情報

=== なぜロールが必要か

EC2 で動くアプリが S3 にアクセスする場合、従来はアクセスキーをサーバに置いていた。これは漏洩リスクが高く、管理もしづらい。*IAM ロール* を使えば、インスタンスに一時認証情報が自動配布され、定期的にローテーションされる。

=== ロールの使われ方

- *EC2 インスタンスプロファイル*：EC2 に付与する。インスタンス内からメタデータ経由で取得
- *Lambda 実行ロール*：Lambda 関数が AWS API を呼ぶときの権限
- *クロスアカウントロール*：別アカウントから `sts:AssumeRole` で引き受ける
- *OIDC / SAML 連携ロール*：IdP（GitHub Actions など）からフェデレーションで引き受ける
- *サービスリンクロール*：AWS 側が管理する特別なロール（ELB、ECS などが自動作成）

=== 信頼ポリシーとアクセスポリシー

ロールには2種類のポリシーが紐づく。

- *信頼ポリシー（Trust Policy）*：「誰がこのロールを引き受けられるか」
- *アクセスポリシー（Permissions Policy）*：「このロールが何をできるか」

EC2 がこのロールを引き受けられるようにする信頼ポリシーの例：

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "Service": "ec2.amazonaws.com" },
    "Action": "sts:AssumeRole"
  }]
}
```

=== GitHub Actions から OIDC で引き受ける例

アクセスキーを発行せず、GitHub Actions から AWS を操作するためのモダンな構成。

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "Federated": "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
    },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": {
        "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
        "token.actions.githubusercontent.com:sub": "repo:octo/app:ref:refs/heads/main"
      }
    }
  }]
}
```

`sub` の条件に *`StringLike` でワイルドカード（例：`repo:octo/app:*`）を使うのは危険* である。フォーク PR やタグ push など、想定外のワークフローからもロールを引き受けられてしまう。*`StringEquals` で特定ブランチ・環境・タグを明示する* のが安全である。複数条件を許したい場合は配列で列挙する。

```json
"token.actions.githubusercontent.com:sub": [
  "repo:octo/app:ref:refs/heads/main",
  "repo:octo/app:environment:prod"
]
```

== ベストプラクティス

=== 最小権限の原則

必要最小限の権限だけを付与する。運用で権限不足が発生したら、CloudTrail のログや IAM Access Analyzer で実際に使われた API を確認し、必要なものだけを追加していく。

=== 権限境界（Permissions Boundary）

開発者が自分で IAM ロールを作れるが、特定の権限を超えないようにしたい場合に使う。IAM ロール／ユーザーの「権限の上限」を定義する。

=== 実装上の推奨

- *ルートユーザーは使わない、MFA を必ず設定する*
- *長期アクセスキーを避ける*、代わりにロール／Identity Center の一時認証情報を使う
- *グループ経由で権限付与*、ユーザーに直接アタッチしない
- *カスタマー管理ポリシー* を作り、複数ユーザーで共有する
- *アクセスキーを定期的にローテーション*、未使用のキーは削除
- *IAM Access Analyzer* で外部公開されたリソースを検出
- *CloudTrail* で監査ログを取り続ける

=== アクセスキーを CI に置かない

GitHub Actions や GitLab CI などで AWS を操作する場合は、長期アクセスキーをシークレットに保存するのではなく *OIDC フェデレーション* でロールを引き受ける。漏洩リスクがゼロに近づく。

== 実習：権限不足を体験する

IAM の感覚をつかむには、*実際に権限を絞ってエラーを出す* のが早い。

+ 管理者ユーザーとは別に、`ReadOnlyAccess` のみを付けた IAM ユーザー `demo-readonly` を作成
+ そのユーザーで AWS CLI の別プロファイルを設定
+ `aws ec2 describe-instances --profile demo-readonly` は成功する
+ `aws ec2 terminate-instances ... --profile demo-readonly` は `UnauthorizedOperation` で失敗する
+ エラー文言には必要なアクション名（例：`ec2:TerminateInstances`）が含まれる

このフィードバックループを通じて、「エラー → 必要アクション特定 → ポリシー更新」の手順が身につく。

== よく使う AWS 管理ポリシー

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*ポリシー名*], [*用途*]),
  [AdministratorAccess], [全権限。検証・管理者用（本番で一般ユーザーに付けない）],
  [ReadOnlyAccess], [全サービスの読み取りのみ。監査・調査用],
  [PowerUserAccess], [IAM 以外ほぼ全権限。開発者用],
  [AmazonS3FullAccess], [S3 の全操作],
  [AmazonEC2FullAccess], [EC2 の全操作],
  [IAMUserChangePassword], [自分のパスワード変更を許可。全ユーザーに付けるとよい],
  [AWSSupportAccess], [サポートケースの作成・閲覧],
  [Billing], [請求情報の閲覧・管理],
)

最初はこれらを組み合わせて始め、慣れてきたらカスタマー管理ポリシーで絞り込む。
