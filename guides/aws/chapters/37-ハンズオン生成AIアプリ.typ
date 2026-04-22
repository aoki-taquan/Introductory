= ハンズオン4：生成 AI チャットアプリ

24〜26章のハンズオンに続き、本章は *Bedrock + Knowledge Bases + API Gateway + Lambda + CloudFront* で社内ドキュメント RAG チャットボットを作る。生成 AI を本番運用品質で組み込む典型構成。

== ゴール

- *S3* に置いたマークダウン / PDF / DOCX を Knowledge Base が取り込み
- *Bedrock Claude* で質問に対して回答生成（引用付き）
- *Cognito* で社内ユーザー認証
- *CloudFront + S3* で React フロントエンド
- 全構成を *CDK*（TypeScript）で IaC 化
- *Guardrails* で安全性フィルタ

== 構成図

```
[User] → CloudFront → S3（フロント）
                   → /api/chat → API Gateway HTTP API → Lambda
                                                          ↓
                                                       Bedrock RetrieveAndGenerate
                                                          ↓
                                                       Knowledge Base
                                                          ↓
                                                    OpenSearch Serverless（Vector）
                                                          ↑（取り込み）
                                                       S3（ドキュメント）
                                                       └ Bedrock Embeddings
[認証] Cognito User Pool → JWT
```

== 前提

- AWS アカウント、CDK 環境（24章参照）
- Bedrock の *モデルアクセス申請* 完了（コンソール → Bedrock → Model access）
- 想定リージョン：`us-east-1` または `ap-northeast-1`（モデル提供状況を確認）
- 想定所要時間：3〜5時間

== ステップ1：プロジェクト初期化

```bash
mkdir -p ~/aws-handson/genai-chat && cd $_
npx cdk init app --language typescript
npm install aws-cdk-lib constructs
```

== ステップ2：Knowledge Base 用 S3 と OpenSearch Serverless

```typescript
import { Stack, StackProps, RemovalPolicy } from 'aws-cdk-lib';
import { Construct } from 'constructs';
import * as s3 from 'aws-cdk-lib/aws-s3';
import * as iam from 'aws-cdk-lib/aws-iam';
import * as opensearchserverless from 'aws-cdk-lib/aws-opensearchserverless';
import * as bedrock from 'aws-cdk-lib/aws-bedrock';

export class KbStack extends Stack {
  constructor(scope: Construct, id: string, props?: StackProps) {
    super(scope, id, props);

    const docsBucket = new s3.Bucket(this, 'DocsBucket', {
      blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
      removalPolicy: RemovalPolicy.DESTROY,
      autoDeleteObjects: true,
      enforceSSL: true,
    });

    const collection = new opensearchserverless.CfnCollection(this, 'KbCollection', {
      name: 'kb-collection',
      type: 'VECTORSEARCH',
    });

    new opensearchserverless.CfnSecurityPolicy(this, 'EncPolicy', {
      name: 'kb-enc',
      type: 'encryption',
      policy: JSON.stringify({
        Rules: [{ ResourceType: 'collection', Resource: ['collection/kb-collection'] }],
        AWSOwnedKey: true,
      }),
    });

    const kbRole = new iam.Role(this, 'KbRole', {
      assumedBy: new iam.ServicePrincipal('bedrock.amazonaws.com'),
    });
    docsBucket.grantRead(kbRole);
    kbRole.addToPolicy(new iam.PolicyStatement({
      actions: ['aoss:APIAccessAll'],
      resources: ['*'],
    }));
    kbRole.addToPolicy(new iam.PolicyStatement({
      actions: ['bedrock:InvokeModel'],
      resources: [
        `arn:aws:bedrock:${this.region}::foundation-model/amazon.titan-embed-text-v2:0`,
      ],
    }));

    const kb = new bedrock.CfnKnowledgeBase(this, 'Kb', {
      name: 'company-kb',
      roleArn: kbRole.roleArn,
      knowledgeBaseConfiguration: {
        type: 'VECTOR',
        vectorKnowledgeBaseConfiguration: {
          embeddingModelArn: `arn:aws:bedrock:${this.region}::foundation-model/amazon.titan-embed-text-v2:0`,
        },
      },
      storageConfiguration: {
        type: 'OPENSEARCH_SERVERLESS',
        opensearchServerlessConfiguration: {
          collectionArn: collection.attrArn,
          vectorIndexName: 'kb-index',
          fieldMapping: { vectorField: 'vector', textField: 'text', metadataField: 'metadata' },
        },
      },
    });

    new bedrock.CfnDataSource(this, 'DataSource', {
      knowledgeBaseId: kb.attrKnowledgeBaseId,
      name: 'docs',
      dataSourceConfiguration: {
        type: 'S3',
        s3Configuration: { bucketArn: docsBucket.bucketArn },
      },
      vectorIngestionConfiguration: {
        chunkingConfiguration: {
          chunkingStrategy: 'FIXED_SIZE',
          fixedSizeChunkingConfiguration: { maxTokens: 500, overlapPercentage: 20 },
        },
      },
    });
  }
}
```

実際は OpenSearch Serverless の Index 作成が手動 / カスタムリソース実装が必要だが、本章ではコンセプトに集中。

== ステップ3：API Lambda

```typescript
import { BedrockAgentRuntimeClient, RetrieveAndGenerateCommand } from '@aws-sdk/client-bedrock-agent-runtime';

const client = new BedrockAgentRuntimeClient({});
const KB_ID = process.env.KB_ID!;
const MODEL_ARN = process.env.MODEL_ARN!;

export const handler = async (event: any) => {
  const body = JSON.parse(event.body ?? '{}');
  const question = body.question;
  if (!question) return { statusCode: 400, body: JSON.stringify({ error: 'question required' }) };

  const cmd = new RetrieveAndGenerateCommand({
    input: { text: question },
    retrieveAndGenerateConfiguration: {
      type: 'KNOWLEDGE_BASE',
      knowledgeBaseConfiguration: { knowledgeBaseId: KB_ID, modelArn: MODEL_ARN },
    },
  });

  try {
    const resp = await client.send(cmd);
    return {
      statusCode: 200,
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        answer: resp.output?.text,
        citations: resp.citations?.map(c => ({
          retrieved: c.retrievedReferences?.map(r => ({
            content: r.content?.text?.substring(0, 200),
            source: r.location?.s3Location?.uri,
          })),
        })),
      }),
    };
  } catch (e: any) {
    return { statusCode: 500, body: JSON.stringify({ error: e.message }) };
  }
};
```

== ステップ4：API Gateway + Cognito

```typescript
import { HttpApi, HttpMethod } from 'aws-cdk-lib/aws-apigatewayv2';
import { HttpUserPoolAuthorizer } from 'aws-cdk-lib/aws-apigatewayv2-authorizers';
import { HttpLambdaIntegration } from 'aws-cdk-lib/aws-apigatewayv2-integrations';
import { UserPool, UserPoolClient } from 'aws-cdk-lib/aws-cognito';

const userPool = new UserPool(this, 'Users', {
  selfSignUpEnabled: true,
  signInAliases: { email: true },
});
const upClient = new UserPoolClient(this, 'WebClient', { userPool });
const authorizer = new HttpUserPoolAuthorizer('Authz', userPool, { userPoolClients: [upClient] });

const httpApi = new HttpApi(this, 'Api', { defaultAuthorizer: authorizer });
httpApi.addRoutes({
  path: '/api/chat',
  methods: [HttpMethod.POST],
  integration: new HttpLambdaIntegration('ChatInt', chatFn),
});
```

== ステップ5：フロントエンド（簡易版）

```html
<!doctype html>
<html lang="ja">
<head><meta charset="utf-8"><title>社内ナレッジ Bot</title>
<style>
body { font-family: sans-serif; max-width: 800px; margin: 1em auto; padding: 0 1em; }
.chat { height: 60vh; overflow-y: scroll; border: 1px solid #ccc; padding: 1em; }
.msg { padding: 0.5em; border-radius: 0.5em; margin: 0.5em 0; }
.user { background: #cef; }
.bot { background: #efe; }
.cite { font-size: 0.9em; color: #666; }
input { width: 80%; padding: 0.5em; }
button { padding: 0.5em; }
</style></head>
<body>
<h1>社内ナレッジ Bot</h1>
<div id="chat" class="chat"></div>
<form id="form">
  <input id="q" placeholder="質問を入力..."><button>送信</button>
</form>
<script>
const TOKEN = localStorage.getItem('id_token');
const API = '/api/chat';
const chat = document.getElementById('chat');
document.getElementById('form').onsubmit = async (e) => {
  e.preventDefault();
  const q = document.getElementById('q').value;
  if (!q) return;
  appendMsg('user', q);
  document.getElementById('q').value = '';
  const r = await fetch(API, {
    method: 'POST',
    headers: { 'content-type': 'application/json', 'Authorization': `Bearer ${TOKEN}` },
    body: JSON.stringify({ question: q }),
  });
  const data = await r.json();
  appendMsg('bot', data.answer, data.citations);
};
function appendMsg(role, text, citations) {
  const el = document.createElement('div');
  el.className = `msg ${role}`;
  el.innerHTML = `<div>${text}</div>`;
  if (citations) el.innerHTML += '<div class="cite">引用: ' + citations.flatMap(c => c.retrieved).map(r => r.source).join(', ') + '</div>';
  chat.appendChild(el);
  chat.scrollTop = chat.scrollHeight;
}
</script>
</body>
</html>
```

== ステップ6：Guardrails 適用

```typescript
import { CfnGuardrail } from 'aws-cdk-lib/aws-bedrock';

const guardrail = new CfnGuardrail(this, 'Guardrail', {
  name: 'company-guardrail',
  blockedInputMessaging: 'この質問にはお答えできません。',
  blockedOutputsMessaging: 'この回答は提供できません。',
  contentPolicyConfig: {
    filtersConfig: [
      { type: 'SEXUAL',     inputStrength: 'HIGH', outputStrength: 'HIGH' },
      { type: 'HATE',       inputStrength: 'HIGH', outputStrength: 'HIGH' },
      { type: 'VIOLENCE',   inputStrength: 'HIGH', outputStrength: 'HIGH' },
      { type: 'INSULTS',    inputStrength: 'HIGH', outputStrength: 'HIGH' },
      { type: 'MISCONDUCT', inputStrength: 'HIGH', outputStrength: 'HIGH' },
      { type: 'PROMPT_ATTACK', inputStrength: 'HIGH', outputStrength: 'NONE' },
    ],
  },
  sensitiveInformationPolicyConfig: {
    piiEntitiesConfig: [
      { type: 'EMAIL',          action: 'ANONYMIZE' },
      { type: 'PHONE',          action: 'ANONYMIZE' },
      { type: 'CREDIT_DEBIT_CARD_NUMBER', action: 'BLOCK' },
    ],
  },
});
```

Lambda 側で `guardrailIdentifier` と `guardrailVersion` を設定して invoke する。

== ステップ7：取り込みジョブの起動

S3 にドキュメントをアップロードした後、Knowledge Base に取り込みを指示する必要がある。EventBridge → Lambda で自動化：

```python
import boto3, os
br = boto3.client('bedrock-agent')

def handler(event, context):
    br.start_ingestion_job(
        knowledgeBaseId=os.environ['KB_ID'],
        dataSourceId=os.environ['DS_ID'],
    )
```

== ステップ8：監視と Guardrails の効果検証

CloudWatch Metrics で：

- `Invocations`（API GW）
- `BedrockTokens`（カスタム EMF メトリクス）
- `GuardrailIntervened`（Guardrails が止めた回数）

X-Ray で：

- Lambda → Bedrock → KB → OpenSearch のレイテンシ内訳

== ステップ9：コスト確認

Cost Explorer でサービス別：

- *Bedrock*：Claude Sonnet で例えば1質問あたり \$0.003〜\$0.01
- *OpenSearch Serverless*：時間課金、最低でも月 \$300 程度（OCU 課金）
- *Lambda / API Gateway*：数百円程度
- *S3 / CloudFront*：Free Tier 内で収まることが多い

OpenSearch Serverless が *最大コスト要因*。学習目的なら *Aurora pgvector* で代替する手もある（24時間運用で月 \$60〜70 程度）。

== ステップ10：後片付け

```bash
npx cdk destroy
```

OpenSearch Serverless の削除は数分かかる。Bedrock Knowledge Base は依存削除順に注意。

== 学んだこと

- *Bedrock RetrieveAndGenerate* で1コール RAG
- *Knowledge Base* + *OpenSearch Serverless* のセットアップ
- *Cognito + JWT Authorizer* で API 認証
- *Guardrails* で安全性フィルタ + PII マスキング
- *EventBridge* で取り込み自動化

== 発展課題

- *Agents* を使ってツール呼び出し（社内 API、計算）を統合
- *Streaming Response*：Lambda Function URL で SSE
- *マルチターン会話*：Conversation 履歴を DynamoDB で保持
- *Hybrid Search*：ベクトル + キーワード
- *Citation UI*：引用ソースのプレビュー、リンク
- *A/B テスト*：複数モデルで同質問を投げ評価
- *Bedrock Evaluations* で品質計測

== トラブルシューティング

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*症状*], [*対処*]),
  [Model access denied], [コンソールで Model access 申請、リージョン確認],
  [Knowledge Base 取り込み失敗], [S3 権限、ドキュメント形式（PDF/DOCX/MD/TXT/HTML）],
  [OpenSearch Index 未作成], [カスタムリソースで作成、または手動],
  [Lambda Timeout], [Bedrock 応答に最大数十秒。Lambda Timeout 60秒以上],
  [Guardrails で blocked], [CloudWatch でブロック理由、しきい値調整],
  [回答が引用元と矛盾], [プロンプト調整、温度低下、別モデル試行],
  [コスト想定外], [OpenSearch Serverless OCU、Bedrock Provisioned 確認],
  [トークン数オーバー], [チャンクサイズ縮小、コンテキスト削減],
)
