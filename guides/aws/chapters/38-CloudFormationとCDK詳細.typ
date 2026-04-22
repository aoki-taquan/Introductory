= CloudFormation と CDK 詳細

11章で IaC ツールの俯瞰を扱った。本章では AWS 純正の CloudFormation と CDK を本格運用視点で深掘りする。スタック構造、Cross-stack 参照、Aspect、Custom Resource、StackSets、テスト、Drift 検出など。

== CloudFormation の基本構造

```yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: My stack
Transform: AWS::Serverless-2016-10-31    # SAM の場合のみ

Parameters:
  Env:
    Type: String
    AllowedValues: [dev, staging, prod]
    Default: dev

Mappings:
  RegionMap:
    ap-northeast-1: { AmazonLinux: ami-0abc... }
    us-east-1:      { AmazonLinux: ami-0def... }

Conditions:
  IsProd: !Equals [!Ref Env, prod]

Resources:
  MyBucket:
    Type: AWS::S3::Bucket
    Properties:
      BucketName: !Sub "my-bucket-${AWS::AccountId}-${Env}"

Outputs:
  BucketArn:
    Value: !GetAtt MyBucket.Arn
    Export: { Name: !Sub "${AWS::StackName}-BucketArn" }
```

=== セクションの役割

- *Parameters*：実行時に与える変数
- *Mappings*：環境別の固定値テーブル
- *Conditions*：リソース作成の条件
- *Resources*：作成するリソース（必須）
- *Outputs*：他スタックや CLI から参照する値

== Intrinsic Functions（組み込み関数）

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*関数*], [*用途*]),
  [`!Ref`], [パラメータ・リソースの主要属性参照],
  [`!GetAtt`], [リソースの個別属性取得],
  [`!Sub`], [文字列補間],
  [`!Join`], [文字列結合],
  [`!Split`], [文字列分割],
  [`!Select`], [リストから要素取得],
  [`!FindInMap`], [Mappings から取得],
  [`!If` / `!Equals` / `!And` / `!Or` / `!Not`], [Conditions ロジック],
  [`!ImportValue`], [他スタックの Output を参照],
  [`!Cidr`], [サブネット CIDR 計算],
  [`!Base64`], [Base64 エンコード（UserData 等）],
)

== スタック設計戦略

=== モノリスス vs ネスト vs Cross-stack

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*戦略*], [*特徴*]),
  [モノリス], [1スタックに全部。シンプルだが大きくなると重い・リソース上限],
  [ネストスタック], [親 → 子の階層。子は再利用可能なテンプレート],
  [Cross-stack], [`Export` / `ImportValue` で疎結合に],
  [Stack Set], [複数アカウント・複数リージョンへ展開],
)

=== レイヤ分割の典型

```
[1. Network スタック]    VPC、Subnet、TGW、Direct Connect
[2. Security スタック]   IAM、KMS、SecurityHub、GuardDuty
[3. Storage スタック]    S3、RDS、DynamoDB
[4. Compute スタック]    ECS、Lambda、EC2
[5. App スタック]        各アプリケーション固有リソース
```

下から上に依存。下層変更時の影響範囲を絞れる。

== Cross-stack 参照

```yaml
# Network stack の Output
Outputs:
  VpcId:
    Value: !Ref Vpc
    Export: { Name: !Sub "${AWS::StackName}-VpcId" }
```

```yaml
# Compute stack でインポート
SubnetIds: !Split
  - ","
  - !ImportValue NetworkStack-PrivateSubnetIds
```

ただし Cross-stack 参照は *硬い結合*。Export を消そうとすると Import 側スタックでエラー。

=== SSM Parameter Store 経由

より柔軟な代替手段：

```yaml
# Network stack で Parameter Store に書き出し
VpcIdParam:
  Type: AWS::SSM::Parameter
  Properties:
    Name: /network/vpc-id
    Type: String
    Value: !Ref Vpc

# 他スタックで動的参照
VpcId: '{{resolve:ssm:/network/vpc-id:1}}'
```

== Custom Resource

CloudFormation でサポートされていないリソースや、外部 API を呼ぶ必要があるときに *Lambda を呼んでカスタム処理* する仕組み。

```yaml
MyCustomResource:
  Type: Custom::MyLogic
  Properties:
    ServiceToken: !GetAtt MyCustomResourceFunction.Arn
    SomeParam: value
```

Lambda が Create / Update / Delete イベントを受け取り、CloudFormation に Success / Failed を返す。

CDK では `aws-cdk-lib/custom-resources` の `AwsCustomResource` で *AWS SDK 呼び出し* を直接書ける。

== Drift 検出

実リソースとテンプレートの差分を検出。コンソールから手動実行 or API。

```bash
aws cloudformation detect-stack-drift --stack-name my-stack
aws cloudformation describe-stack-resource-drifts --stack-name my-stack
```

手動変更（コンソール操作）を検出して IaC に戻す運用。

== StackSets

複数アカウント・複数リージョンに *1テンプレートを展開*。

=== 2つの権限モデル

- *Self-Managed*：管理者が IAM を各アカウントに準備
- *Service-Managed*：Organizations 連携で自動

```bash
aws cloudformation create-stack-set \
  --stack-set-name baseline \
  --template-body file://baseline.yaml \
  --permission-model SERVICE_MANAGED \
  --auto-deployment Enabled=true,RetainStacksOnAccountRemoval=false

aws cloudformation create-stack-instances \
  --stack-set-name baseline \
  --deployment-targets OrganizationalUnitIds=ou-abc-1234 \
  --regions ap-northeast-1 us-east-1
```

新規アカウント作成時に *自動デプロイ* される設定が便利。

== AWS CDK 詳細

CDK は CloudFormation のラッパーだが、*プログラミング言語* で書ける利点が大きい。

=== Construct の3層

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*層*], [*説明*]),
  [L1 (Cfn\*)], [CloudFormation 直マッピング (`CfnBucket`)],
  [L2], [パターン化された API (`Bucket`)],
  [L3 (Pattern)], [複数リソースを束ねた高水準 (`ApplicationLoadBalancedFargateService`)],
)

新規開発は L2 中心、新サービスや細かい設定は L1 で補う。

=== App / Stack / Construct の階層

```
App
└ Stack
   └ Construct
      └ Resource (L1)
```

`Stack` 単位で CloudFormation スタックが生成される。`App` 全体で `cdk synth` → `cdk deploy`。

=== Cross-stack 参照（CDK）

```typescript
// 同 App 内なら自動的に Export/ImportValue が生成される
const networkStack = new NetworkStack(app, 'Network');
const computeStack = new ComputeStack(app, 'Compute', { vpc: networkStack.vpc });
```

CDK 側で依存関係を解決し、CloudFormation 側で Export/ImportValue として書き出す。

=== Tag の一括付与

```typescript
import { Tags } from 'aws-cdk-lib';
Tags.of(app).add('Project', 'myapp');
Tags.of(app).add('Environment', env);
```

App ツリー全体に伝播。

=== Aspects

CDK ツリーを traverse して *横断的なルール* を適用する仕組み。

```typescript
import { IAspect, Aspects, IConstruct } from 'aws-cdk-lib';
import { CfnBucket } from 'aws-cdk-lib/aws-s3';

class EnforceEncryption implements IAspect {
  visit(node: IConstruct) {
    if (node instanceof CfnBucket) {
      node.bucketEncryption = {
        serverSideEncryptionConfiguration: [{
          serverSideEncryptionByDefault: { sseAlgorithm: 'AES256' },
        }],
      };
    }
  }
}

Aspects.of(app).add(new EnforceEncryption());
```

組織共通のセキュリティルール強制、タグ強制、リソース命名規則チェックなどに。

=== cdk-nag

CDK ベストプラクティスを *自動チェック*。AWS Solutions / NIST 800-53 / HIPAA / PCI DSS 等のルールセット。

```typescript
import { AwsSolutionsChecks } from 'cdk-nag';
Aspects.of(app).add(new AwsSolutionsChecks({ verbose: true }));
```

`cdk synth` 時に違反を出力。

=== CDK Pipelines

CDK 自身を *self-mutating な CI/CD パイプライン* で運用。

```typescript
import * as pipelines from 'aws-cdk-lib/pipelines';

const pipeline = new pipelines.CodePipeline(this, 'Pipeline', {
  synth: new pipelines.ShellStep('Synth', {
    input: pipelines.CodePipelineSource.gitHub('owner/repo', 'main'),
    commands: ['npm ci', 'npm run build', 'npx cdk synth'],
  }),
});

pipeline.addStage(new MyAppStage(this, 'Dev', { env: { account: '111', region: 'ap-northeast-1' }}));
pipeline.addStage(new MyAppStage(this, 'Prod', { env: { account: '222', region: 'ap-northeast-1' }}), {
  pre: [new pipelines.ManualApprovalStep('PromoteToProd')],
});
```

複数アカウント・複数リージョン・段階デプロイを宣言的に。

== テスト

=== 1. snapshot テスト

```typescript
import { Template } from 'aws-cdk-lib/assertions';

test('matches snapshot', () => {
  const stack = new MyStack(new App(), 'Test');
  const template = Template.fromStack(stack);
  expect(template.toJSON()).toMatchSnapshot();
});
```

予期せぬ差分を検知。

=== 2. ファインマッチング

```typescript
import { Match } from 'aws-cdk-lib/assertions';

test('S3 bucket has versioning', () => {
  const stack = new MyStack(new App(), 'Test');
  const template = Template.fromStack(stack);
  template.hasResourceProperties('AWS::S3::Bucket', {
    VersioningConfiguration: Match.objectLike({ Status: 'Enabled' }),
  });
});
```

=== 3. 統合テスト

`@aws-cdk/integ-tests-alpha` で *実 AWS にデプロイしてアサート*。`integ-runner` で実行。

== デプロイ戦略

=== Hotswap

```bash
cdk deploy --hotswap
```

CloudFormation を経由せずに *Lambda コード・Step Functions 定義などを直接更新*。開発ループを高速化（本番では使わない）。

=== Watch

```bash
cdk watch
```

ファイル変更を検知して自動 deploy（Hotswap 込み）。

=== Bootstrap モダン化

```bash
cdk bootstrap aws://<account>/<region>
```

CDK 用の S3 / IAM Role / KMS Key が作られる。組織レベルでカスタマイズ（CdkBootstrap-Modern）。

== CDK と Terraform の選び方

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*要件*], [*推奨*]),
  [AWS だけ・型安全・プログラミング], [CDK],
  [マルチクラウド・既存 Terraform 資産], [Terraform],
  [サーバーレス特化], [SAM or CDK],
  [チームが Java/.NET/Python に習熟], [CDK],
  [HashiCorp エコシステム（Vault、Vagrant 等）], [Terraform],
  [大量の同様リソース展開], [CDK の loop / Terraform の count 両方可],
  [GitOps、宣言重視], [Terraform / OpenTofu],
)

両方を併用する組織も多い：CDK で AWS 基盤、Terraform で SaaS / マルチクラウド連携。

== ベストプラクティス

- *Stack を環境変数で分離*：dev/staging/prod を別 Stack
- *Construct を再利用ライブラリ化*：社内共通 Construct を npm package で配布
- *cdk-nag* / *cfn-guard* / *Checkov* で静的検査
- *PR ごとに `cdk diff`* を CI で表示してレビュー
- *デプロイは CI/CD 経由*、ローカルからの直接 deploy を本番禁止
- *タグを App 単位で必ず付与*
- *Outputs は最小限*、SSM Parameter Store の方が柔軟
- *Stack Set* / *CDK Pipelines* でマルチアカウント
- *State / Drift の定期チェック*

== 制限値の頭出し

#table(
  columns: (1fr, 1fr),
  align: left,
  table.header([*項目*], [*上限*]),
  [スタックあたりリソース数], [500（緩和申請可）],
  [スタックあたり Outputs], [200],
  [スタックあたり Parameters], [200],
  [スタックあたり Mappings], [200],
  [テンプレートサイズ（直接アップロード）], [51,200 バイト],
  [テンプレートサイズ（S3 経由）], [1MB],
)

== よくある罠

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*罠*], [*対処*]),
  [Cross-stack Export を消せない], [Import 側を先に変更してから Export 削除],
  [スタック削除で IAM Role 消えない], [`AssumeRolePolicy` 競合、依存リソース残存],
  [Drift が大量], [手動変更を IaC に取り込み、SCP で手動禁止],
  [`cdk destroy` で残るリソース], [`removalPolicy: DESTROY`、`autoDeleteObjects`],
  [ROLLBACK\_FAILED ステート], [CloudFormation ヘルプ参照、必要なら手動削除],
  [カスタムリソースの Stuck], [Lambda timeout、SUCCESS / FAILED 必ず返す],
  [Replacement で本番停止], [`UpdateReplacePolicy: Retain`、Replacement プロパティ把握],
  [Stack Set デプロイ失敗], [対象アカウントの IAM Role、リージョンの opt-in],
)
