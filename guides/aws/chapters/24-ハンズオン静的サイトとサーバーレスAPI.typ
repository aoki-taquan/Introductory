= ハンズオン1：静的サイトとサーバーレス API

ここから3つのハンズオン章では、実際に手を動かして AWS を使う流れを示す。本章は最小コストで完結する *静的サイト + サーバーレス API* の構成。Free Tier 内に収まることを目指す。

== ゴール

- *静的フロントエンド*（HTML/CSS/JS の SPA）を S3 + CloudFront で HTTPS 配信
- *バックエンド API* を API Gateway + Lambda + DynamoDB で構築
- *カスタムドメイン* を Route 53 + ACM で適用
- 全体を *AWS CDK*（TypeScript）で IaC 化
- 終了時に *cdk destroy* で完全削除

== 前提

- AWS アカウント開設済（2章）、Identity Center または管理者 IAM ユーザーあり
- AWS CLI v2 インストール、`aws sts get-caller-identity` で確認できる状態
- Node.js 20 以上、npm
- 自前のドメイン（Route 53 でも他社レジストラでも可）。なければ DNS 部分はスキップしてもよい
- 想定所要時間：2〜3時間

== 構成図

```
[Browser]
   ↓ HTTPS
[Route 53] → [CloudFront] → [S3 (private, OAC)]    ← 静的フロント
                          → /api/* → [API Gateway HTTP API]
                                       → [Lambda]
                                          → [DynamoDB]
```

== ステップ1：プロジェクト初期化

```bash
mkdir -p ~/aws-handson/serverless-app && cd $_
npm init -y
npm install -D typescript ts-node @types/node aws-cdk-lib constructs
npx cdk init app --language typescript
```

CDK の `bin/` と `lib/` ができる。`lib/serverless-app-stack.ts` に構築を書いていく。

=== Bootstrap（初回のみ）

CDK はリージョンごとに *Bootstrap*（CDK 用の S3 バケットや IAM ロール）が必要。

```bash
npx cdk bootstrap aws://<アカウントID>/ap-northeast-1
```

== ステップ2：Lambda 関数を書く

`lambda/api/index.ts` を作成。

```bash
mkdir -p lambda/api
npm install --prefix lambda/api @aws-sdk/client-dynamodb @aws-sdk/lib-dynamodb
```

```typescript
// lambda/api/index.ts
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, PutCommand, GetCommand, ScanCommand } from '@aws-sdk/lib-dynamodb';
import { randomUUID } from 'crypto';

const ddb = DynamoDBDocumentClient.from(new DynamoDBClient({}));
const TABLE = process.env.TABLE_NAME!;

export const handler = async (event: any) => {
  const method = event.requestContext?.http?.method;
  const path = event.requestContext?.http?.path;

  try {
    if (method === 'GET' && path === '/api/notes') {
      const r = await ddb.send(new ScanCommand({ TableName: TABLE }));
      return ok(r.Items ?? []);
    }
    if (method === 'POST' && path === '/api/notes') {
      const body = JSON.parse(event.body ?? '{}');
      const item = { id: randomUUID(), text: String(body.text ?? ''), createdAt: Date.now() };
      await ddb.send(new PutCommand({ TableName: TABLE, Item: item }));
      return ok(item);
    }
    if (method === 'GET' && path?.startsWith('/api/notes/')) {
      const id = path.split('/').pop();
      const r = await ddb.send(new GetCommand({ TableName: TABLE, Key: { id } }));
      return r.Item ? ok(r.Item) : { statusCode: 404, body: 'not found' };
    }
    return { statusCode: 404, body: 'not found' };
  } catch (e: any) {
    return { statusCode: 500, body: JSON.stringify({ error: e.message }) };
  }
};

const ok = (body: unknown) => ({
  statusCode: 200,
  headers: { 'content-type': 'application/json' },
  body: JSON.stringify(body),
});
```

== ステップ3：CDK スタック

```typescript
// lib/serverless-app-stack.ts
import { Stack, StackProps, RemovalPolicy, Duration, CfnOutput } from 'aws-cdk-lib';
import { Construct } from 'constructs';
import * as s3 from 'aws-cdk-lib/aws-s3';
import * as cf from 'aws-cdk-lib/aws-cloudfront';
import * as origins from 'aws-cdk-lib/aws-cloudfront-origins';
import * as ddb from 'aws-cdk-lib/aws-dynamodb';
import * as lambdaNode from 'aws-cdk-lib/aws-lambda-nodejs';
import * as lambda from 'aws-cdk-lib/aws-lambda';
import * as apigw from 'aws-cdk-lib/aws-apigatewayv2';
import * as apigwInteg from 'aws-cdk-lib/aws-apigatewayv2-integrations';
import * as s3deploy from 'aws-cdk-lib/aws-s3-deployment';
import * as path from 'path';

export class ServerlessAppStack extends Stack {
  constructor(scope: Construct, id: string, props?: StackProps) {
    super(scope, id, props);

    // 1. DynamoDB
    const table = new ddb.Table(this, 'NotesTable', {
      partitionKey: { name: 'id', type: ddb.AttributeType.STRING },
      billingMode: ddb.BillingMode.PAY_PER_REQUEST,
      removalPolicy: RemovalPolicy.DESTROY,
      pointInTimeRecoverySpecification: {
        pointInTimeRecoveryEnabled: true,
      },
    });

    // 2. Lambda
    const fn = new lambdaNode.NodejsFunction(this, 'ApiFn', {
      entry: path.join(__dirname, '..', 'lambda', 'api', 'index.ts'),
      runtime: lambda.Runtime.NODEJS_20_X,
      memorySize: 256,
      timeout: Duration.seconds(10),
      environment: { TABLE_NAME: table.tableName },
    });
    table.grantReadWriteData(fn);

    // 3. API Gateway HTTP API
    const httpApi = new apigw.HttpApi(this, 'HttpApi', {
      corsPreflight: {
        allowOrigins: ['*'],
        allowMethods: [apigw.CorsHttpMethod.ANY],
        allowHeaders: ['content-type'],
      },
    });
    httpApi.addRoutes({
      path: '/api/{proxy+}',
      methods: [apigw.HttpMethod.ANY],
      integration: new apigwInteg.HttpLambdaIntegration('ApiInt', fn),
    });

    // 4. S3（静的サイト用、非公開）
    const siteBucket = new s3.Bucket(this, 'SiteBucket', {
      blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
      removalPolicy: RemovalPolicy.DESTROY,
      autoDeleteObjects: true,
      enforceSSL: true,
    });

    // 5. CloudFront + OAC
    const dist = new cf.Distribution(this, 'Dist', {
      defaultBehavior: {
        origin: origins.S3BucketOrigin.withOriginAccessControl(siteBucket),
        viewerProtocolPolicy: cf.ViewerProtocolPolicy.REDIRECT_TO_HTTPS,
        cachePolicy: cf.CachePolicy.CACHING_OPTIMIZED,
      },
      additionalBehaviors: {
        '/api/*': {
          origin: new origins.HttpOrigin(`${httpApi.apiId}.execute-api.${this.region}.amazonaws.com`),
          viewerProtocolPolicy: cf.ViewerProtocolPolicy.REDIRECT_TO_HTTPS,
          allowedMethods: cf.AllowedMethods.ALLOW_ALL,
          cachePolicy: cf.CachePolicy.CACHING_DISABLED,
          originRequestPolicy: cf.OriginRequestPolicy.ALL_VIEWER_EXCEPT_HOST_HEADER,
        },
      },
      defaultRootObject: 'index.html',
      errorResponses: [
        { httpStatus: 403, responseHttpStatus: 200, responsePagePath: '/index.html' },
        { httpStatus: 404, responseHttpStatus: 200, responsePagePath: '/index.html' },
      ],
    });

    // 6. 静的サイトのデプロイ
    new s3deploy.BucketDeployment(this, 'DeploySite', {
      sources: [s3deploy.Source.asset(path.join(__dirname, '..', 'site'))],
      destinationBucket: siteBucket,
      distribution: dist,
      distributionPaths: ['/*'],
    });

    new CfnOutput(this, 'CloudFrontUrl', { value: `https://${dist.distributionDomainName}` });
  }
}
```

== ステップ4：静的フロントエンド

最小限の SPA を `site/index.html` として作る。

```bash
mkdir -p site
```

```html
<!-- site/index.html -->
<!doctype html>
<html lang="ja">
<head>
<meta charset="utf-8">
<title>Notes</title>
<style>
  body { font-family: sans-serif; max-width: 600px; margin: 2em auto; }
  input, button { font-size: 1em; padding: 0.4em; }
  ul { padding: 0; }
  li { list-style: none; padding: 0.5em; border-bottom: 1px solid #ddd; }
</style>
</head>
<body>
<h1>メモ</h1>
<input id="text" placeholder="新しいメモ">
<button id="add">追加</button>
<ul id="list"></ul>
<script>
async function load() {
  const r = await fetch('/api/notes');
  const items = await r.json();
  document.getElementById('list').innerHTML = items
    .map(i => `<li>${i.text}<br><small>${new Date(i.createdAt).toLocaleString()}</small></li>`)
    .join('');
}
document.getElementById('add').onclick = async () => {
  const text = document.getElementById('text').value;
  if (!text) return;
  await fetch('/api/notes', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ text }),
  });
  document.getElementById('text').value = '';
  load();
};
load();
</script>
</body>
</html>
```

== ステップ5：デプロイ

```bash
npx cdk deploy
```

`CloudFrontUrl` の出力 URL（`https://dXXXXXXXX.cloudfront.net`）にブラウザでアクセス。「メモを追加」して保存・再読込で残ることを確認。

== ステップ6：カスタムドメイン

Route 53 でホストゾーンが既にある前提（`example.com`）。

=== ACM 証明書（us-east-1）

```bash
aws acm request-certificate \
  --domain-name 'notes.example.com' \
  --validation-method DNS \
  --region us-east-1
```

検証 CNAME を Route 53 に追加（コンソールで「Create records in Route 53」を1クリック）。

=== CDK スタックに追加

```typescript
import * as acm from 'aws-cdk-lib/aws-certificatemanager';
import * as r53 from 'aws-cdk-lib/aws-route53';
import * as r53Targets from 'aws-cdk-lib/aws-route53-targets';

const zone = r53.HostedZone.fromLookup(this, 'Zone', { domainName: 'example.com' });
const cert = acm.Certificate.fromCertificateArn(this, 'Cert',
  'arn:aws:acm:us-east-1:<account>:certificate/<id>');

const dist = new cf.Distribution(this, 'Dist', {
  // ... 上記に加えて
  domainNames: ['notes.example.com'],
  certificate: cert,
  // ...
});

new r53.ARecord(this, 'AliasRecord', {
  zone,
  recordName: 'notes',
  target: r53.RecordTarget.fromAlias(new r53Targets.CloudFrontTarget(dist)),
});
```

`npx cdk deploy` で再適用。`https://notes.example.com` でアクセスできるようになる。

== ステップ7：監視を1枚追加

```typescript
import * as cw from 'aws-cdk-lib/aws-cloudwatch';

new cw.Dashboard(this, 'Dashboard', {
  dashboardName: 'NotesApp',
  widgets: [
    [
      new cw.GraphWidget({
        title: 'API Requests',
        left: [httpApi.metric('Count', { statistic: 'Sum', period: Duration.minutes(5) })],
      }),
      new cw.GraphWidget({
        title: 'Lambda Errors',
        left: [fn.metricErrors({ statistic: 'Sum' })],
      }),
    ],
    [
      new cw.GraphWidget({
        title: 'DynamoDB Read/Write Capacity',
        left: [
          table.metricConsumedReadCapacityUnits(),
          table.metricConsumedWriteCapacityUnits(),
        ],
      }),
    ],
  ],
});
```

== ステップ8：GitHub Actions で CI/CD（任意）

OIDC で AWS にロール引き受け、`cdk deploy` を自動化する。

```yaml
# .github/workflows/deploy.yml
name: deploy
on:
  push:
    branches: [main]
permissions:
  id-token: write
  contents: read
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '20' }
      - run: npm ci
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::<account>:role/github-actions-cdk
          aws-region: ap-northeast-1
      - run: npx cdk deploy --require-approval never
```

ロール側の信頼ポリシーは3章の例を参照（`StringEquals` で `repo:owner/repo:ref:refs/heads/main` に固定）。

== ステップ9：検証 → 後片付け

確認が終わったら *必ず削除* する。

```bash
npx cdk destroy
```

CloudFront ディストリビューションは削除に10〜15分かかる。完了を待つ。

S3 バケットに残ったオブジェクトがあれば手動で空にしてから再実行。

== 学んだこと

- *S3 + CloudFront + OAC* で安全な静的配信
- *API Gateway HTTP API + Lambda* でサーバーレス API
- *DynamoDB* の `PAY_PER_REQUEST` で完全従量
- *CDK* による IaC、`cdk destroy` でクリーンアップ
- *Route 53 + ACM* でカスタムドメイン HTTPS
- *CloudWatch Dashboard* で監視を1枚

== 発展課題

- Cognito User Pool で認証を追加し、ユーザーごとのメモにする
- DynamoDB Streams + Lambda で更新通知を SES でメール送信
- Lambda レイヤーで共通ライブラリを切り出し
- API Gateway に *使用量プラン + API キー* を入れて公開
- CloudWatch RUM でフロントのリアルユーザーモニタリング
- WAF を CloudFront に紐付けて攻撃ブロック

== トラブルシューティング

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*症状*], [*対処*]),
  [`cdk bootstrap` でエラー], [IAM 権限不足、`AdministratorAccess` で再試行],
  [Lambda が `Cannot find module`], [`NodejsFunction` の bundler 動作確認、`esbuild` インストール],
  [API が CORS エラー], [`corsPreflight` 設定、フロントから同一ドメイン経由で叩く],
  [CloudFront が 403], [OAC ポリシー、S3 オブジェクト存在、ディストリビューション伝播待ち],
  [DynamoDB 書き込み権限なし], [`grantReadWriteData` 呼び出し済みか],
  [カスタムドメインが反映しない], [ACM 検証完了、CloudFront 再デプロイ、DNS TTL 待ち],
  [請求が発生してる], [`cdk destroy`、コンソールで NAT/EIP/EBS 残存確認],
)
