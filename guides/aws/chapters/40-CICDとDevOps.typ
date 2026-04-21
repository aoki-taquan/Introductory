= CI/CD と DevOps

11章で IaC、38〜39章で CloudFormation/CDK/Terraform を扱った。本章では *継続的インテグレーション・継続的デリバリ* の AWS 上での実装を、純正 Code シリーズと GitHub Actions の比較を含めて深掘りする。

== CI/CD の全体像

```
[Git push] → CI（ビルド・テスト・スキャン）→ Artifact
              ↓
            CD（dev → staging → prod デプロイ）
              ↓
          Observability（メトリクス・トレース）
              ↓
          Feedback Loop（issue / metric / SLO）
```

== AWS の CI/CD サービス群

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*サービス*], [*用途*]),
  [CodeCommit], [Git ホスティング（新規受付終了の方向）],
  [CodeBuild], [マネージドビルド],
  [CodeDeploy], [EC2 / Lambda / ECS のデプロイメント],
  [CodePipeline], [パイプラインオーケストレーション],
  [CodeArtifact], [npm / pip / maven などのアーティファクトリ],
  [CodeGuru], [コードレビュー・プロファイラ（Q Developer に統合進行）],
  [CodeCatalyst], [⚠️ 2025/10 廃止発表。2025/11 新規スペース不可、2025/12 保守終了。新規採用は避ける],
  [Amazon Q Developer], [生成 AI コーディング支援],
)

実務では *GitHub + GitHub Actions* が圧倒的シェア。AWS 純正は *Code* シリーズが中心（CodeCatalyst は 2025 年末に廃止）。

== GitHub Actions ＋ AWS（推奨）

=== OIDC でアクセスキー不要

3章で触れた通り、長期キーを置かずに *Assume Role* で AWS 操作。

```yaml
permissions:
  id-token: write
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789012:role/gha-deploy
          aws-region: ap-northeast-1
      - run: aws sts get-caller-identity
```

IAM ロールの信頼ポリシー：

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
        "token.actions.githubusercontent.com:sub": "repo:owner/repo:ref:refs/heads/main"
      }
    }
  }]
}
```

`sub` は *StringEquals + フルパス指定* が安全。ワイルドカードは fork PR で乗っ取りリスク。

=== 典型的な CI Workflow

```yaml
name: ci
on:
  pull_request:
  push:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '20' }
      - run: npm ci
      - run: npm run lint
      - run: npm test -- --coverage
      - uses: codecov/codecov-action@v4

  build:
    needs: test
    runs-on: ubuntu-latest
    permissions: { id-token: write, contents: read }
    steps:
      - uses: actions/checkout@v4
      - uses: aws-actions/configure-aws-credentials@v4
        with: { role-to-assume: arn:aws:iam::...:role/gha-ci, aws-region: ap-northeast-1 }
      - uses: aws-actions/amazon-ecr-login@v2
      - run: |
          docker build -t myapp:${{ github.sha }} .
          docker tag myapp:${{ github.sha }} 123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/myapp:${{ github.sha }}
          docker push 123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/myapp:${{ github.sha }}
```

=== 段階的 CD（Environment 機能）

```yaml
deploy-staging:
  needs: build
  environment: staging        # GitHub Environment
  runs-on: ubuntu-latest
  steps:
    - run: aws ecs update-service --cluster c --service s --force-new-deployment

deploy-prod:
  needs: deploy-staging
  environment: prod           # 承認待ち（Environment Protection Rules）
  runs-on: ubuntu-latest
  steps:
    - run: aws ecs update-service --cluster c --service s --force-new-deployment
```

`environment: prod` で *承認者リスト* を設定すれば、手動承認後にだけ実行される。

== AWS CodePipeline

純正のパイプラインオーケストレーション。Source → Build → Deploy のステージ構成。

```yaml
# CDK での定義例
import * as codepipeline from 'aws-cdk-lib/aws-codepipeline';
import * as actions from 'aws-cdk-lib/aws-codepipeline-actions';
import * as codebuild from 'aws-cdk-lib/aws-codebuild';

const pipeline = new codepipeline.Pipeline(this, 'Pipeline', {
  pipelineName: 'myapp',
  pipelineType: codepipeline.PipelineType.V2,    // V2 推奨
});

pipeline.addStage({
  stageName: 'Source',
  actions: [new actions.GitHubSourceAction({
    actionName: 'GitHub',
    owner: 'owner', repo: 'repo', branch: 'main',
    oauthToken: SecretValue.secretsManager('github-token'),
    output: new codepipeline.Artifact('SrcArtifact'),
  })],
});

pipeline.addStage({
  stageName: 'Build',
  actions: [new actions.CodeBuildAction({
    actionName: 'Build',
    project: new codebuild.PipelineProject(this, 'Build', {
      buildSpec: codebuild.BuildSpec.fromSourceFilename('buildspec.yml'),
    }),
    input: srcArtifact,
    outputs: [buildArtifact],
  })],
});

pipeline.addStage({
  stageName: 'DeployProd',
  actions: [new actions.ManualApprovalAction({ actionName: 'Approve' })],
});
```

=== CodePipeline V2 の利点

- *Trigger Filter*：PR イベント、ファイルパスフィルタ
- *Variables*：パイプライン全体で変数共有
- *Stage Conditions*：失敗・成功時の条件アクション

== AWS CodeBuild

マネージドビルド環境。`buildspec.yml` で定義。

```yaml
version: 0.2
phases:
  install:
    runtime-versions:
      nodejs: 20
  pre_build:
    commands:
      - npm ci
  build:
    commands:
      - npm test
      - npm run build
artifacts:
  files: ['dist/**/*', 'package.json']
cache:
  paths: ['node_modules/**/*']
```

=== ビルド環境

- AWS マネージドイメージ（Amazon Linux、Ubuntu、Windows）
- カスタムイメージ（ECR）
- Compute タイプ：BUILD\_GENERAL1\_SMALL〜LARGE、ARM、GPU、Lambda
- VPC 内ビルド（プライベートリソースアクセス）

=== バッチビルド

- *Build matrix*：複数バージョン並列
- *Build graph*：依存関係付き並列

== AWS CodeDeploy

EC2 / Lambda / ECS のデプロイメント。

=== EC2 デプロイ

- *In-place*：既存インスタンスを順次更新
- *Blue/Green*：新環境を作って切替（ELB 連携）

`appspec.yml`：

```yaml
version: 0.0
os: linux
files:
  - source: /
    destination: /opt/myapp
hooks:
  BeforeInstall:
    - location: scripts/before_install.sh
      timeout: 300
  AfterInstall:
    - location: scripts/after_install.sh
  ApplicationStart:
    - location: scripts/start.sh
  ValidateService:
    - location: scripts/health_check.sh
      timeout: 60
```

=== ECS デプロイ

- *Rolling*（標準）
- *Blue/Green*（CodeDeploy 連携）：Listener 切替で即時切替、ロールバック容易

```yaml
# appspec.yaml (ECS Blue/Green)
version: 0.0
Resources:
  - TargetService:
      Type: AWS::ECS::Service
      Properties:
        TaskDefinition: <TASK_DEFINITION>
        LoadBalancerInfo:
          ContainerName: app
          ContainerPort: 8080
```

=== Lambda デプロイ

- *Canary*：10% を5分、その後100%
- *Linear*：10%ずつ10分で
- *AllAtOnce*：即時

CloudWatch アラームと連動して、エラー率が高ければ自動ロールバック。

== Amazon CodeCatalyst（⚠️ 廃止）

統合 DevOps プラットフォームとして提供されていたが、*2025年10月に AWS は廃止を発表*。2025年11月以降新規スペース作成不可、2025年12月で保守終了予定。

既存利用者は *GitHub や GitLab など外部 Git ホスティング* + *CodePipeline / CodeBuild / CodeDeploy* への移行が推奨されている。新規プロジェクトは採用を避けること。

=== 歴史的参考（すでに非推奨）

- Project・Workflows・Dev Environment・Blueprint などの概念
- AWS Builder ID による個人アカウント
- CodeCommit の新規受付停止と合わせて AWS の純正 DevOps 統合戦略の再編が進行中

=== 代替の選択肢

- *GitHub + GitHub Actions + CodePipeline*：現状の王道
- *GitLab（セルフホスト or SaaS）+ CodePipeline*
- *HCP Terraform + GitHub*：IaC 重視

== Amazon Q Developer

生成 AI 開発支援。

- *IDE プラグイン*（VSCode、JetBrains、Visual Studio）
- *コード生成・補完*：自然言語コメントからコード提案
- *コード説明・リファクタリング*
- *単体テスト生成*
- *セキュリティスキャン*
- *Q Code Transformation*：Java バージョンアップ、.NET 移行などの自動コード変換
- *AWS CLI / Console での Q Chat*：「これはなぜ動かない？」を AWS リソース文脈で回答

GitHub Copilot 競合。AWS 統合が強み。

== セキュリティスキャン

CI/CD パイプラインに組み込む静的・動的スキャン。

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*ツール*], [*対象*]),
  [Amazon Inspector], [ECR / Lambda / EC2 の脆弱性スキャン],
  [Snyk / Dependabot / Renovate], [依存パッケージの脆弱性],
  [Trivy / Grype], [コンテナイメージスキャン（GHA で）],
  [tfsec / checkov / Trivy IaC], [IaC の設定ミス検知],
  [Semgrep / Bandit / ESLint security rules], [SAST],
  [GitHub Advanced Security], [シークレットスキャン、CodeQL],
  [AWS Secrets Manager + git-secrets], [シークレット流出防止],
  [cdk-nag], [CDK ベストプラクティス],
)

PR ブロッキングと「警告のみ」を切り分けて運用。

== Artifact 管理

=== ECR

コンテナイメージ。組織内共有、レプリケーション、脆弱性スキャン統合。

=== CodeArtifact

npm / pip / maven / NuGet / Cargo パッケージのプライベートリポジトリ。ECR の言語パッケージ版。

=== S3

汎用アーティファクト（zip、tar、ML モデル、データセット）。バージョニング前提。

== デプロイ戦略

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*戦略*], [*動作*]),
  [Rolling], [古い→新しいを段階入れ替え],
  [Blue/Green], [新環境を立てて切替、即ロールバック可],
  [Canary], [一部ユーザーに新版、徐々に拡大],
  [Feature Flag], [コードはデプロイ済み、フラグで有効化],
  [A/B Testing], [ユーザーセグメントで使い分け、計測],
  [Shadow], [本番トラフィックを *コピー* して新版で実行（破壊しない）],
)

=== AppConfig（Feature Flag）

AWS のフィーチャーフラグサービス。

```python
import boto3
ac = boto3.client('appconfigdata')
session = ac.start_configuration_session(
    ApplicationIdentifier='myapp',
    EnvironmentIdentifier='prod',
    ConfigurationProfileIdentifier='features'
)
config = ac.get_latest_configuration(ConfigurationToken=session['InitialConfigurationToken'])
features = json.loads(config['Configuration'].read())
if features.get('new_checkout'):
    return new_checkout()
else:
    return old_checkout()
```

デプロイ戦略：Linear / Canary / All at once。CloudWatch アラーム連動で *自動ロールバック*。

== マルチアカウントデプロイ

```
[CI Account] → CodePipeline / GHA
       ↓ Assume Role
[Dev Account]    → デプロイ
       ↓
[Staging Account] → デプロイ
       ↓ 承認
[Prod Account]   → デプロイ
```

各アカウントに *デプロイ用 IAM ロール*（Permissions Boundary 付き）を用意し、CI から Assume。CDK Pipelines はこの構造をネイティブサポート。

== モニタリング・通知

- CloudWatch Logs / Metrics でビルド・デプロイ履歴
- SNS → Chatbot で Slack / Teams 通知
- *デプロイ失敗時の自動ロールバック*（CodeDeploy のアラーム連動）
- *DORA Metrics*：Deployment Frequency / Lead Time / MTTR / Change Failure Rate を計測

== ベストプラクティス

- *PR ごとに CI 必須*、main 直 push 禁止
- *自動テスト・静的解析・セキュリティスキャン* を CI で
- *本番デプロイは承認 + Canary*
- *CloudWatch アラームと連動した自動ロールバック*
- *シークレットは Secrets Manager / Parameter Store*、リポジトリに置かない
- *OIDC でキーレス*
- *マルチアカウント分離*（Dev / Staging / Prod）
- *Feature Flag* で *デプロイとリリースを分離*
- *DORA Metrics* で改善サイクルを回す

== よくある罠

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*罠*], [*対処*]),
  [長期 IAM キーを GHA に置く], [OIDC で AssumeRole に切替],
  [GHA の sub にワイルドカード], [`StringEquals` でフルパス固定],
  [Production を main 直 push], [Environment Protection Rules + 承認者],
  [テストなしのデプロイ], [ユニット + 統合 + smoke を最低限],
  [Feature Flag のフラグ放置], [定期棚卸し、TTL 付き],
  [モノリスの Big Bang デプロイ], [Canary、Blue/Green、Feature Flag 分割],
  [Rollback できない DB マイグレ], [Backward-compatible スキーマ変更を徹底],
  [Pipeline の手動承認だけ], [自動 Smoke テスト + アラーム自動ロールバック],
)

== DevOps 文化

CI/CD ツールは *目的ではなく手段*。文化面では：

- *小さく頻繁にリリース*：1日複数回デプロイ
- *Trunk-based Development*：長期分岐を避ける
- *Feature Flag で master を常にリリース可能に*
- *Postmortem 文化*：Blameless、共有
- *SRE / DevOps エンジニアと開発者の協業*
- *自動化を後回しにしない*（手作業はバグの温床）

技術導入だけでなく、*組織の意思決定スピード* も同時に変わる必要がある。
