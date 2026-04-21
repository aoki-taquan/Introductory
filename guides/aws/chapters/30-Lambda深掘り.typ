= Lambda 深掘り

8章で概要、14章でメッセージング統合の文脈で扱った Lambda を、本章では *本番運用品質* で使うための知識として深掘りする。コールドスタート対策、可観測性、Powertools、テスト、コスト、設計パターンを中心に。

== Lambda の実行モデル再確認

=== 実行環境のライフサイクル

```
1. INIT     コンテナ起動 + ランタイム初期化 + ハンドラ外コード実行
2. INVOKE   ハンドラ実行（複数回繰り返される）
3. SHUTDOWN コンテナ終了（しばらく未使用後）
```

INIT は *リクエストごとには走らない*。同じコンテナが「ウォーム」のうちは INVOKE のみ繰り返される。INIT が走るのが *コールドスタート*。

=== コンテナの再利用

ハンドラ外で初期化したオブジェクト（DB クライアント、SDK、設定キャッシュ）は、同じコンテナのウォーム呼び出しで *再利用* される。これを意識して書くと性能が上がる。

```python
# 良い例：モジュールスコープで初期化
import boto3
ddb = boto3.resource('dynamodb').Table('mytable')

def handler(event, context):
    return ddb.get_item(Key={'id': event['id']})
```

```python
# 悪い例：毎回初期化
def handler(event, context):
    ddb = boto3.resource('dynamodb').Table('mytable')   # 毎回作られる
    return ddb.get_item(Key={'id': event['id']})
```

=== 同時実行とスケーリング

- 1コンテナ = 1リクエスト同時処理
- スケール上限：アカウント・リージョンの *Reserved/Unreserved Concurrency*
- 急激なスパイク：*関数単位で10秒ごとに +1,000 インスタンス*（= 10,000 req/秒 相当）までスケール可能（2023年11月以降の新仕様）
- *Reserved Concurrency*：関数ごとに上限を予約（他関数を圧迫しない）
- *Provisioned Concurrency*：事前ウォーム済みコンテナを確保

== コールドスタート対策

=== 削減の優先順位

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*対策*], [*効果*]),
  [パッケージサイズ削減], [大。デプロイパッケージを小さく],
  [ランタイム選択], [大。Node.js / Python は速い、Java / .NET は遅い],
  [Lambda SnapStart], [大（Java、Python、.NET 対応）],
  [Provisioned Concurrency], [完全回避できるが課金],
  [Lambda Power Tuning], [メモリ最適化で全体短縮],
  [VPC 内 Lambda の改善], [Hyperplane ENI で大幅高速化済（2019〜）],
)

=== Lambda SnapStart

JVM 系言語向けが先行、現在は Python / .NET にも拡大。INIT 後の状態をスナップショットして再利用。コールドスタートを *最大10倍高速化*。

対応ランタイム（2026年4月時点）：

- *Java*：11 / 17 / 21 corretto
- *Python*：3.12 以降
- *.NET*：.NET 8 以降

コンテナイメージ Lambda、カスタムランタイムは SnapStart 非対応。

```bash
aws lambda update-function-configuration \
  --function-name myfunc \
  --snap-start ApplyOn=PublishedVersions
```

注意：

- *Published Version* に対して有効。`$LATEST` には適用されない
- スナップショット時の状態が保存されるため、*乱数や TLS 接続* は recreate ロジックが必要

=== Provisioned Concurrency

事前にウォームコンテナを確保。

```bash
aws lambda put-provisioned-concurrency-config \
  --function-name myfunc \
  --qualifier 1 \
  --provisioned-concurrent-executions 10
```

- 1コンテナあたり時間課金
- *Auto Scaling* と組み合わせて、業務時間中だけ増やす運用が一般的

== ランタイム

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*ランタイム*], [*特徴*]),
  [Node.js 20 / 22], [起動速い、エコシステム豊富],
  [Python 3.11 / 3.12 / 3.13], [起動速い、データ系・ML 系で人気],
  [Java 17 / 21], [JVM 重いが SnapStart で改善],
  [Go (Provided.al2023)], [単一バイナリ、高速],
  [Ruby 3.x], [Rails 周辺で],
  [.NET 8], [SnapStart 対応],
  [Rust (Provided.al2023 + lambda-runtime crate)], [極低レイテンシ・低メモリ],
  [カスタムランタイム], [Bash、PHP、Cobol 等],
  [コンテナイメージ (OCI)], [最大 10GB、独自バイナリ・依存ライブラリ],
)

=== コンテナイメージ Lambda

ECR にイメージを push して指定するだけで Lambda として動く。サイズ上限が 10GB と大きく、ML モデルや巨大ライブラリも詰められる。Cold Start は zip より遅め。

```dockerfile
FROM public.ecr.aws/lambda/python:3.12

COPY requirements.txt .
RUN pip install -r requirements.txt --target ${LAMBDA_TASK_ROOT}
COPY app.py ${LAMBDA_TASK_ROOT}

CMD ["app.handler"]
```

== Lambda Powertools

AWS 公式の *本番運用支援ライブラリ*（Python / TypeScript / Java / .NET）。

主な機能：

- *Logger*：構造化 JSON ログ、相関 ID 自動付与
- *Tracer*：X-Ray のセグメント自動作成
- *Metrics*：CloudWatch EMF 形式で効率的にメトリクス送信
- *Event Source Data Classes*：API GW / S3 / SQS など各イベントの型安全アクセス
- *Parser*：Pydantic ベースのバリデーション
- *Idempotency*：DynamoDB を使った冪等性ヘルパー
- *Feature Flags*：AppConfig 統合
- *Parameters*：Parameter Store / Secrets Manager のキャッシュ付き取得
- *Batch*：SQS / Kinesis / DynamoDB Streams の Partial Batch Failure を簡潔に
- *Validation*：JSON Schema 検証

```python
from aws_lambda_powertools import Logger, Tracer, Metrics
from aws_lambda_powertools.metrics import MetricUnit

logger = Logger(service="orders")
tracer = Tracer(service="orders")
metrics = Metrics(namespace="MyApp", service="orders")

@logger.inject_lambda_context(correlation_id_path="requestContext.requestId")
@tracer.capture_lambda_handler
@metrics.log_metrics(capture_cold_start_metric=True)
def handler(event, context):
    logger.info("order received", extra={"item_count": len(event["items"])})
    metrics.add_metric(name="OrdersProcessed", unit=MetricUnit.Count, value=1)
    return {"statusCode": 200}
```

これだけで構造化ログ、相関 ID 伝播、X-Ray トレース、CloudWatch メトリクス、Cold Start メトリクスが揃う。Powertools は *Lambda 開発の事実上の標準*。

== 設計パターン

=== 単機能・薄い Lambda

複雑なロジックは Lambda 外（Step Functions、SDK サービス統合）に出して、Lambda は薄く保つ。

```
[API GW] → Lambda（バリデーション） → DynamoDB
                                      → 失敗時 Step Functions で複雑処理
```

=== Single-purpose vs Mono-Lambda

- *Single-purpose*：エンドポイント1つ = Lambda 1つ。役割明確、独立スケール、独立 IAM
- *Mono-Lambda*（Lambdalith）：複数エンドポイントを1 Lambda に（Express / FastAPI ベース）。コールドスタートを共有、コード共有が楽

新規はまず Mono-Lambda で始め、性能・隔離要件が出たら分割するのが楽。

=== ストリーム処理（SQS / Kinesis / DynamoDB Streams）

- *バッチサイズ* と *バッチウィンドウ* で効率調整
- *Partial Batch Failure*：失敗だけを返して残りは成功
- *Maximum Concurrency*：同時実行数を制限してダウンストリーム保護
- *DLQ / On-Failure 宛先*：失敗イベントの隔離

=== Async vs Sync

- *Sync*：API GW、ALB、CLI Invoke → 戻り値が直接返る
- *Async*：S3、SNS、EventBridge → 裏で実行、戻り値は使われない
- *Stream-based*：SQS、Kinesis、DynamoDB Streams → Lambda が pull して処理

Async では *Destinations*（成功・失敗で別宛先に流せる）と *DLQ*（失敗時の退避）を必ず設定。

== Lambda Function URL

API Gateway なしで *直接 HTTPS エンドポイント* を Lambda に付ける機能。

- 認証：`AWS_IAM` または `NONE`（バックエンドに認証ロジック）
- CORS 設定可
- 料金：API Gateway より安い（Lambda 通常料金のみ）
- 制約：使用量プラン、API キー、リクエスト変換などはなし

簡易 Webhook 受け、PoC、内部ツール用に。

== テスト戦略

=== ローカルテスト

- *AWS SAM CLI*：`sam local invoke`、`sam local start-api`
- *LocalStack*：AWS サービスのローカルエミュレータ

```bash
sam local start-api
curl http://127.0.0.1:3000/api/notes
```

=== ユニットテスト

依存（DynamoDB、S3）はモック化。`moto`（Python）、`aws-sdk-client-mock`（Node.js）。

```python
import boto3
from moto import mock_aws

@mock_aws
def test_handler():
    boto3.client('dynamodb').create_table(
        TableName='mytable',
        KeySchema=[{'AttributeName': 'id', 'KeyType': 'HASH'}],
        AttributeDefinitions=[{'AttributeName': 'id', 'AttributeType': 'S'}],
        BillingMode='PAY_PER_REQUEST',
    )
    from app import handler
    result = handler({'id': '1'}, None)
    assert result['statusCode'] == 200
```

=== 統合テスト

実 AWS にデプロイして E2E。CDK / SAM / Terraform で *PR ごとに一時環境* を作る運用も一般的。

== 監視と可観測性

=== CloudWatch Metrics

標準で：

- `Invocations` / `Errors` / `Throttles`
- `Duration` / `IteratorAge`（ストリーム系）
- `ConcurrentExecutions`
- `ProvisionedConcurrency*`

=== CloudWatch Logs

`/aws/lambda/<function-name>` に自動出力。*保持期間を必ず設定*（デフォルト無期限）。Logs Insights で検索。

=== X-Ray

Powertools Tracer で自動セグメント作成。downstream（DynamoDB、HTTP）も統合。

=== Application Signals

CloudWatch の APM 機能。Lambda + Powertools で SLI/SLO ベースのモニタリング（35章参照）。

== コスト最適化

- *Memory tuning*：*Lambda Power Tuning*（Step Functions のオープンソース）で実行時間 vs メモリの最適点を探す
- *ARM (Graviton)*：x86 より 20% 安く 19% 高速のことが多い
- *Provisioned Concurrency*：本当に必要な時間帯だけ
- *Tiered Pricing*：月60億 GB秒以降は割引
- *Compute Savings Plans* でも Lambda は割引対象

=== Lambda Power Tuning

```bash
{
  "lambdaARN": "arn:aws:lambda:ap-northeast-1:123456789012:function:myfunc",
  "powerValues": [128, 256, 512, 1024, 1536, 2048, 3008],
  "num": 50,
  "payload": {"key": "value"},
  "strategy": "balanced"
}
```

128MB〜3GB の各メモリで実行コストとレイテンシを比較。最適値を選ぶ。

== セキュリティ

- *最小権限の実行ロール*
- *環境変数の暗号化*：機密値は KMS 暗号化または Secrets Manager / Parameter Store
- *VPC 内 Lambda*：プライベートリソース（RDS など）にアクセス時、Hyperplane ENI で起動時間影響は最小
- *Code Signing*：Lambda パッケージの署名検証
- *リソースベースポリシー*：他アカウント / サービスからの呼び出し許可
- *Lambda extensions*：Datadog、Splunk、New Relic などのオブザーバビリティエージェント

== Lambda の制限値（覚えておくべき数値）

#table(
  columns: (1fr, 1fr),
  align: left,
  table.header([*項目*], [*上限*]),
  [メモリ], [128MB〜10,240MB（1MB 刻み）],
  [実行時間], [最大 15 分],
  [一時ディスク `/tmp`], [512MB〜10,240MB],
  [デプロイパッケージ（zip）], [50MB（直接）/ 250MB（解凍後）],
  [コンテナイメージ], [10GB],
  [環境変数], [4KB（合計）],
  [同時実行数], [アカウント当初 1,000（緩和申請可）],
  [ペイロード（同期）], [6MB],
  [ペイロード（非同期）], [256KB],
)

== よくあるトラブル

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*症状*], [*対処*]),
  [Cold Start が遅い], [SnapStart、Provisioned Concurrency、ARM、軽量ランタイム],
  [Throttling], [Reserved/Unreserved Concurrency、上限緩和申請],
  [タイムアウト], [メモリ増、外部 API 待ち時間、SDK timeouts],
  [VPC 内で外部 API 不通], [NAT Gateway、VPC エンドポイント設置],
  [Logs が大量・高コスト], [サンプリング、保持期間、Powertools の log level],
  [メモリ不足 OOM], [メモリ増、ストリーミング処理、巨大データの S3 経由化],
  [permissions エラー], [実行ロール、リソースベースポリシー、暗号化キー権限],
  [Async が再試行され続ける], [Destinations / DLQ、最大試行回数調整],
  [SQS でメッセージが消えない], [可視性タイムアウト > Lambda 実行時間、partial batch failure],
)
