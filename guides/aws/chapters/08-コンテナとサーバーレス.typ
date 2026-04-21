= コンテナとサーバーレス

EC2 で仮想マシンを立てる方法に加えて、AWS では *コンテナ* や *サーバーレス* でアプリを動かす選択肢がある。運用負荷を AWS に寄せるほど、開発者はアプリケーションロジックに集中できる。本章ではこの領域の主要サービスを俯瞰する。

== コンピュート選択のスペクトラム

#table(
  columns: (1fr, 2fr, 1fr),
  align: left,
  table.header([*レイヤ*], [*責任範囲（利用者側）*], [*例*]),
  [仮想マシン], [OS・ミドルウェア・アプリ], [EC2],
  [コンテナ（IaaS）], [コンテナ・タスク定義], [ECS on EC2、EKS on EC2],
  [コンテナ（サーバーレス）], [コンテナだけ], [ECS on Fargate、EKS on Fargate],
  [サーバーレス関数], [関数コードだけ], [Lambda],
  [フルマネージド PaaS], [アプリコードだけ], [App Runner、Elastic Beanstalk、Amplify],
)

下へ行くほど運用負荷が下がり、抽象度が上がる。

=== 初学者はどこから始めればよいか

選択肢が多いので迷いやすい。目安として以下の順序で検討するとよい。

+ *軽い API・イベント処理*：Lambda + API Gateway から始める。インフラがゼロで、Free Tier の範囲で永続的に試せる
+ *既存の Web アプリ（Docker イメージがある）*：App Runner。Git 連携または ECR から1コマンドで公開できる
+ *コンテナだが本格制御したい*：ECS on Fargate。タスク定義・ALB・Auto Scaling を明示的に組む
+ *Kubernetes の資産がある、他クラウドと共通化したい*：EKS。学習コスト高
+ *既存の EC2 運用ノウハウを活かす*：ECS on EC2 または EC2 + Auto Scaling

「まずは Lambda か App Runner」で小さく始めて、負荷・要件が見えてから上位へ移るのが事故が少ない。

== Lambda（サーバーレス関数）

*AWS Lambda* は、関数単位でコードを実行するサーバーレス基盤である。インフラを意識せず、イベント駆動で動くコードを書ける。

=== 実行モデル

- コードをランタイム（Python、Node.js、Java、Go、Ruby、.NET、Rust）で動かす
- コンテナイメージ（OCI）としてデプロイも可能（最大 10 GB）
- *イベント* をトリガーに起動：API Gateway、S3、SQS、EventBridge、DynamoDB Streams など
- *同時実行数（Concurrency）* でスケール。デフォルト上限はアカウント・リージョンで1000

=== 料金モデル

- *リクエスト数 × 実行時間 × メモリサイズ* の従量課金
- メモリを上げると CPU も連動して増える（時間が短縮されれば相殺される場合も）
- 月 100 万リクエスト、40万 GB秒 までは *Free Tier*（常時無料）

=== コールドスタート

しばらく呼ばれていない Lambda は、次の呼び出し時に *コンテナ起動＋ランタイム初期化* が走る。これが *コールドスタート*。

- 数十 ms 〜 数秒（言語・パッケージサイズに依存）
- 解消策：*Provisioned Concurrency*（事前に温めておく）、*SnapStart*（Java で起動時間短縮）
- VPC 内 Lambda は ENI 初期化でさらに長くなる

=== シンプルな Lambda の例（Python）

```python
import json

def lambda_handler(event, context):
    name = event.get("queryStringParameters", {}).get("name", "world")
    return {
        "statusCode": 200,
        "body": json.dumps({"message": f"hello, {name}!"})
    }
```

デプロイは以下の通り。

```bash
zip -r func.zip lambda_function.py
aws lambda create-function \
  --function-name hello \
  --runtime python3.12 \
  --role arn:aws:iam::123456789012:role/lambda-basic \
  --handler lambda_function.lambda_handler \
  --zip-file fileb://func.zip
```

=== Lambda のユースケース

- *API バックエンド*：API Gateway ＋ Lambda
- *ファイル処理*：S3 アップロード → Lambda でサムネイル生成・ウイルススキャン
- *ストリーム処理*：DynamoDB Streams、Kinesis
- *スケジュールジョブ*：EventBridge Scheduler で cron 相当
- *ChatOps / Slack Bot*：WebHook 受信処理
- *IoT バックエンド*：IoT Core からの軽い処理

=== 制限

- *実行時間 15 分上限*：長時間処理には向かない（Step Functions や Fargate と組み合わせる）
- *メモリ上限 10 GB*、*一時ディスク 10 GB*
- *同時実行数の制限*：急激なスケールでスロットリングに注意

== API Gateway

HTTP / REST / WebSocket の API をマネージドで提供する。Lambda、HTTP バックエンド、VPC Link 経由で NLB / ALB にも接続できる。

=== 種類

- *HTTP API*：軽量・低レイテンシ・安価。新規は基本これ
- *REST API*：機能豊富（使用量プラン、APIキー、WAF 連携、リクエスト検証）
- *WebSocket API*：双方向通信

=== Lambda Proxy 連携

API Gateway HTTP API の典型パターン。リクエストを Lambda にそのまま渡し、Lambda のレスポンスを HTTP レスポンスに変換する。

=== 認証／認可

- *Cognito オーソライザー*：ユーザー認証（JWT）
- *Lambda オーソライザー*：独自ロジックで認可
- *IAM 認可*：SigV4 署名付きリクエスト

== ECS / EKS / Fargate

=== ECS（Elastic Container Service）

AWS 独自のコンテナオーケストレーション。*タスク定義* という概念で Docker コンテナの起動仕様を記述する。

- *クラスタ* ＞ *サービス* ＞ *タスク* という階層
- タスクは *EC2 上* または *Fargate 上* で動く
- ELB との統合、Auto Scaling、Blue/Green デプロイ対応

EKS より *シンプル・学習コストが低い*。AWS だけで完結する運用なら ECS の方が扱いやすいことが多い。

=== EKS（Elastic Kubernetes Service）

Kubernetes（k8s）のコントロールプレーンをマネージドで提供する。

- *Kubernetes のエコシステムをそのまま使える*
- オンプレや他クラウドとの移植性が高い
- 運用ノウハウが必要。IAM・ENI・CoreDNS・Ingress で AWS 固有の癖あり
- *Karpenter* を使うとノードスケーリングが賢くなる

「Kubernetes の知識があり移植性重視」なら EKS、「シンプルに回したい」なら ECS。

=== Fargate

コンテナを *サーバーレス* で動かす仕組み。EC2 ノードを自前で管理せず、必要な vCPU・メモリだけ指定してタスクを起動する。

- EC2 ノードの OS パッチやスケーリングから解放される
- *タスクの vCPU × 時間* で課金
- ネットワーク的には VPC の ENI が各タスクに付く

小〜中規模で運用負荷を下げたい場合は *ECS on Fargate*、k8s 要件があるなら *EKS on Fargate* が第一候補。

=== ECR（Elastic Container Registry）

OCI 互換のコンテナレジストリ。Docker Hub の AWS 内版。

- *パブリックレジストリ*（誰でも pull 可）と *プライベートレジストリ*
- IAM でアクセス制御
- 脆弱性スキャン、イメージ署名
- ECS / EKS / Lambda（コンテナイメージ方式）から引かれる

```bash
# ECR にログイン
aws ecr get-login-password --region ap-northeast-1 \
  | docker login --username AWS --password-stdin \
    123456789012.dkr.ecr.ap-northeast-1.amazonaws.com

# タグ付けして push
docker tag myapp:latest \
  123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/myapp:latest
docker push \
  123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/myapp:latest
```

=== ECS タスク定義の例

```json
{
  "family": "web",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "512",
  "memory": "1024",
  "executionRoleArn": "arn:aws:iam::123456789012:role/ecsTaskExecutionRole",
  "containerDefinitions": [{
    "name": "nginx",
    "image": "123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/myapp:latest",
    "portMappings": [{ "containerPort": 80 }],
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "/ecs/web",
        "awslogs-region": "ap-northeast-1",
        "awslogs-stream-prefix": "web"
      }
    }
  }]
}
```

== App Runner / Elastic Beanstalk / Amplify

より高レベルの PaaS 的サービス群。

=== App Runner

*コンテナまたは GitHub リポジトリから URL 付きの Web アプリを直接起動* できる。VPC や ALB の設定も自動でやってくれる。

- シンプルな Web アプリ（API、SSR フロントエンド等）に最適
- 料金は vCPU × 時間 ＋ リクエスト数
- Fargate より抽象度が高い

=== Elastic Beanstalk

古くからある PaaS。アプリをアップロードすれば EC2 / ALB / RDS を含めて環境を自動構築。

- 機能的には枯れているが、新規採用は減少傾向
- *裏のリソースにアクセスできる* のが特徴（Lock-in が少ない）

=== Amplify

フロントエンド・モバイル向けのフルスタックホスティング。

- Git 連携で自動ビルド・デプロイ
- 認証（Cognito）、API（GraphQL / REST）、ストレージ（S3）、ホスティング（CloudFront）を統合
- React / Vue / Next.js などの SSR / SPA をそのまま乗せられる

Next.js や Nuxt.js の個人プロジェクトをデプロイするなら Amplify または App Runner が楽。

== イベント駆動・非同期アーキテクチャ

サーバーレス／コンテナと組み合わせて使われる重要サービス。

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*サービス*], [*役割*]),
  [SQS], [メッセージキュー。Standard / FIFO の2種],
  [SNS], [Pub/Sub。トピックに発行すると複数宛に配信（メール・SMS・HTTP・SQS・Lambda）],
  [EventBridge], [イベントバス。AWS サービス＋ SaaS を統合],
  [Step Functions], [ステートマシン。Lambda / サービスを組み合わせたワークフロー],
  [Kinesis], [ストリーミング。Data Streams / Firehose / Analytics],
  [MSK], [マネージド Kafka],
)

=== SQS + Lambda の基本パターン

1. Producer（Web / Lambda）が SQS にメッセージを送る
2. Lambda が SQS をポーリングして1件ずつ処理
3. 失敗時は DLQ（Dead Letter Queue）に退避

このパターンは、*ピークをキューで吸収し、バックエンドを非同期化* する定番。バーストトラフィックを受ける Web アプリで多用する。

=== Step Functions

Lambda や AWS サービス呼び出しを *ステートマシン* で繋ぐ。長時間処理、分岐、リトライ、並列実行を JSON で宣言できる。

```
[Start] → [画像解析Lambda] →(成功)→ [サムネイル生成] →(並列)→ [通知]
                        └(失敗)→ [エラーログ] → [End]
```

Lambda 単体の15分上限を超える処理や、複雑なフローの可視化に有用。

== サーバーレス／コンテナの選定指針

- *単純な HTTP エンドポイント*：API Gateway + Lambda、または App Runner
- *バッチ処理・非同期ジョブ*：SQS + Lambda、または ECS Fargate タスク
- *長時間処理*：Step Functions または ECS Fargate タスク
- *既存 Docker アプリを動かす*：ECS on Fargate
- *Kubernetes 資産を持っている*：EKS
- *フロントエンド中心*：Amplify / CloudFront + S3
- *自前でスケーリング込みで運用できる*：EC2 + Auto Scaling

「まずは Lambda → 限界が見えたら ECS / Fargate → さらに複雑なら EKS」という段階的なステップアップが一つの筋道である。

== 参考アーキテクチャ：サーバーレス Web アプリ

```
[ユーザー]
  ↓ HTTPS
[CloudFront] —— [S3 (静的フロント)]
  ↓ /api/*
[API Gateway]
  ↓
[Lambda]
  ↓
[DynamoDB]    [Cognito (認証)]
```

このスタックは *インフラを1台も立てずに* Web アプリを動かせる。コストもアクセスが少ないうちは Free Tier の範囲内で収まることが多く、学習・個人プロジェクトの定番になっている。
