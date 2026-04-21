= メッセージングと統合

サービスを疎結合に保ち、スケーラビリティと耐障害性を高めるために、AWS は豊富なメッセージング・統合サービスを提供する。本章では SQS / SNS / EventBridge / Step Functions を中心に、API Gateway 詳細、AppSync、MQ も扱う。

== イベント駆動アーキテクチャの全体像

=== 同期 vs 非同期

- *同期*：呼び出し側がレスポンスを待つ。HTTP API、gRPC
- *非同期*：呼び出し側はキューにメッセージを置いて即時離脱。バックエンドが順次処理

=== Push vs Pull

- *Push*：送信側が宛先に直接配信（SNS、EventBridge）
- *Pull*：受信側がキューを定期的に読みに行く（SQS）

=== サービス早見表

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*サービス*], [*向いている用途*]),
  [SQS], [ジョブキュー、バックプレッシャ、Worker パターン],
  [SNS], [Pub/Sub、ファンアウト、ユーザー通知],
  [EventBridge], [サービス間イベント連携、SaaS 統合、スケジュール],
  [Step Functions], [ワークフロー、Saga、長時間処理],
  [API Gateway], [HTTP / REST / WebSocket API],
  [AppSync], [GraphQL、リアルタイム],
  [MQ], [既存 ActiveMQ / RabbitMQ 資産の置き換え],
  [Kinesis], [ストリーミング（15章で扱う）],
)

== SQS（Simple Queue Service）

最も枯れたフルマネージドキュー。サーバー不要、HTTP API で送受信。

=== Standard キュー vs FIFO キュー

#table(
  columns: (1fr, 1fr, 1fr),
  align: left,
  table.header([*項目*], [*Standard*], [*FIFO*]),
  [スループット], [ほぼ無制限], [3,000/秒（バッチ）または 300/秒],
  [配信], [少なくとも1回（重複あり）], [厳密に1回],
  [順序], [ベストエフォート], [厳密な FIFO],
  [料金], [基本：\$0.40/100万], [基本：\$0.50/100万],
  [用途], [スループット重視・冪等処理], [順序・重複排除が必須],
)

== 主要パラメータ

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*パラメータ*], [*意味*]),
  [可視性タイムアウト], [メッセージ受信後、他のコンシューマから見えなくなる時間。処理時間より長く設定],
  [メッセージ保持期間], [最大14日（デフォルト4日）],
  [遅延キュー], [送信後、指定秒数は配信されない],
  [Long polling], [`ReceiveMessageWaitTimeSeconds` で空ポーリング削減],
  [DLQ], [N回処理失敗したメッセージを別キューに退避],
  [メッセージ属性], [ヘッダ的な追加情報],
)

== Lambda トリガー

SQS 上のメッセージを Lambda が自動でポーリング・処理する標準パターン。

- *バッチサイズ*：1〜10,000（FIFO は最大 10）
- *バッチウィンドウ*：最大5分待ってからまとめて処理
- *Partial Batch Failure*：一部だけ失敗を返せる（残りは成功扱い）
- *Maximum Concurrency*：同時実行数の上限を SQS イベントソース側で制御

```python
def lambda_handler(event, context):
    failures = []
    for record in event['Records']:
        try:
            process(record['body'])
        except Exception:
            failures.append({"itemIdentifier": record['messageId']})
    return {"batchItemFailures": failures}
```

== ベストプラクティス

- *冪等性*：Standard は重複配信あり前提。`MessageDeduplicationId` 相当の処理側ガード
- *Long polling 必須*：1秒/秒のショートポーリングは API コスト無駄
- *DLQ を必ず設定*：失敗の山が Live キューに残らないように
- *メッセージは小さく*（最大 256KB、超えるなら S3 に置いてキーだけ送る）
- *FIFO の MessageGroupId* は適切な粒度で（ユーザー ID 単位など）。1グループ＝順序単位

== SNS（Simple Notification Service）

Pub/Sub モデル。トピックに publish、サブスクライバーに fan-out。

=== サブスクライバー（プロトコル）

- Email、Email-JSON
- SMS（料金高めなので注意）
- HTTPS / HTTP（任意 URL に POST）
- SQS（最も多用）
- Lambda
- Mobile Push（APNs / FCM）
- Kinesis Data Firehose
- Application（モバイルプッシュ）

=== ファンアウトパターン

```
[Producer] → SNS Topic
              ├ SQS-A → Lambda-A
              ├ SQS-B → Lambda-B
              └ SQS-C → Lambda-C
```

1 publish で複数の処理系を独立に走らせる。各 SQS は再試行・DLQ を独立管理できるため、*片方の処理系が遅れても他に影響しない*。

=== FIFO トピック

順序保証付き SNS。配信先に FIFO SQS を使う。エンドユーザー通知よりも、内部システム連携で順序が必要な場合に。

=== メッセージフィルタリング

サブスクリプション側で *メッセージ属性* に基づくフィルタを設定。「`event_type=order_placed` のときだけこのキューに流す」等。Producer 側のロジックが軽くなる。

=== 配信エラーと DLQ

サブスクリプションごとに DLQ（SQS）を設定。HTTPS エンドポイントが無応答だった場合などに退避。

== EventBridge

サービス間・SaaS との *イベントバス*。SNS よりも構造化・宣言的でルーター能力が高い。

=== バスの種類

- *Default Event Bus*：AWS サービスのイベントが流れてくる（EC2 状態変化、ECS タスク状態など）
- *Custom Event Bus*：自分で定義してアプリ間連携
- *Partner Event Bus*：Datadog、Zendesk、PagerDuty など SaaS からのイベント

=== ルールとターゲット

ルールでイベントパターンを書き、マッチしたイベントをターゲットに送る。

```json
{
  "source": ["aws.ec2"],
  "detail-type": ["EC2 Instance State-change Notification"],
  "detail": {
    "state": ["terminated"]
  }
}
```

ターゲット候補（最大5個）：Lambda、Step Functions、SQS、SNS、Kinesis、ECS タスク、SSM Run Command、API Destination（任意 HTTP）、別 EventBridge バスなど。

=== スケジュール

旧来は *EventBridge ルールの cron 式* で書いていたが、現在は *EventBridge Scheduler* が独立サービスとして推奨される。

- 1分間隔以下〜年単位
- 1回限り（One-time）スケジュールも可
- 最大1年先まで予約可能
- タイムゾーン指定
- グループ化、暗号化

```bash
aws scheduler create-schedule \
  --name daily-report \
  --schedule-expression 'cron(0 9 * * ? *)' \
  --schedule-expression-timezone 'Asia/Tokyo' \
  --target '{"Arn":"arn:aws:lambda:...","RoleArn":"arn:aws:iam:..."}' \
  --flexible-time-window '{"Mode":"OFF"}'
```

=== アーカイブとリプレイ

イベントバス上のイベントを *S3 にアーカイブ* し、後から *リプレイ* してターゲットに再配信できる。障害復旧、テスト環境への流し込みに便利。

=== EventBridge Pipes

*Source → Filter → Enrich → Target* の1対1パイプ。SQS、Kinesis、DynamoDB Streams、MSK、Self-managed Kafka、ActiveMQ 等を Source にして、Lambda や ECS タスクで enrich し、Target に流す。Step Functions や Lambda を経由せずシンプルな ETL/連携が組める。

=== スキーマレジストリ

イベントの JSON スキーマを管理し、SDK のバインディング（Java、Python、TypeScript、Go）を自動生成。

== Step Functions

ステートマシンを宣言する Workflow サービス。

=== 2種類のワークフロー

#table(
  columns: (1fr, 1fr, 1fr),
  align: left,
  table.header([*項目*], [*Standard*], [*Express*]),
  [最長実行時間], [1年], [5分],
  [課金], [ステート遷移ごと], [実行時間 + リクエスト],
  [べき等], [exactly-once], [at-least-once（Async）, exactly-once（Sync）],
  [履歴], [長期保存・可視化], [CloudWatch Logs に],
  [向く用途], [長時間ビジネスプロセス], [高頻度・短時間処理],
)

=== ステートタイプ

- *Task*：Lambda 呼び出しや AWS サービス統合
- *Choice*：条件分岐
- *Parallel*：並列実行
- *Map*：配列要素ごとに並列実行（最大10,000）
- *Wait*：時間待機 or 特定時刻まで
- *Pass*：データ加工
- *Succeed* / *Fail*：終了

=== Service Integration Patterns

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*パターン*], [*動作*]),
  [Request Response], [呼び出してすぐ次へ。デフォルト],
  [.sync], [サービス完了まで待つ（ECS RunTask など）],
  [.waitForTaskToken], [Token を渡し、外部からのコールバックを待つ（人手承認など）],
)

=== ASL（Amazon States Language）の例

```json
{
  "Comment": "Order processing",
  "StartAt": "Validate",
  "States": {
    "Validate": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:::function:validate",
      "Next": "IsValid"
    },
    "IsValid": {
      "Type": "Choice",
      "Choices": [{
        "Variable": "$.valid",
        "BooleanEquals": true,
        "Next": "Charge"
      }],
      "Default": "Reject"
    },
    "Charge": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:::function:charge",
      "Retry": [{
        "ErrorEquals": ["TransientError"],
        "IntervalSeconds": 2,
        "MaxAttempts": 3,
        "BackoffRate": 2.0
      }],
      "Catch": [{
        "ErrorEquals": ["States.ALL"],
        "Next": "Reject"
      }],
      "End": true
    },
    "Reject": {
      "Type": "Fail",
      "Cause": "Order rejected"
    }
  }
}
```

=== Workflow Studio

GUI でステートマシンを設計できる。生成された ASL は Git 管理し、CI/CD で deploy するのが定石。

=== 料金感

- Standard：100ステート遷移あたり \$0.025（東京）
- Express：100万リクエストあたり \$1 + 実行時間
- 高頻度・短時間処理は Express、長時間業務処理は Standard

== API Gateway 詳細

8章では Lambda Proxy 統合を中心に紹介した。本節ではその他の機能を補完する。

=== HTTP API vs REST API vs WebSocket API

#table(
  columns: (1fr, 1fr, 1fr, 1fr),
  align: left,
  table.header([*機能*], [*HTTP API*], [*REST API*], [*WebSocket API*]),
  [基本料金], [\$1.00/100万], [\$3.50/100万], [\$1.00/100万 + メッセージ],
  [API キー], [×], [○], [×],
  [使用量プラン], [×], [○], [×],
  [WAF], [○], [○], [×（CloudFront 経由）],
  [リクエスト変換], [基本], [VTL でフル制御], [—],
  [認証], [JWT/Lambda/IAM], [Cognito/Lambda/IAM], [IAM/Lambda],
  [プライベート], [×], [○], [×],
  [Mock 統合], [×], [○], [×],
)

新規構築は *基本 HTTP API*、機能が必要なら REST API、双方向通信なら WebSocket。

=== ステージとデプロイ

REST API では *ステージ*（`dev` / `prod`）にデプロイし、ステージごとにスロットリング・キャッシュ・ロギングを設定。*カナリアリリース* で新バージョンに10%トラフィックだけ流す、なども可能。

=== カスタムドメイン

API Gateway のデフォルト URL は不格好なので（`https://abc123.execute-api...`）、カスタムドメインに ACM 証明書を紐づけて使う。エンドポイントタイプは Edge / Regional / Private の3種。

=== 認証

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*方式*], [*用途*]),
  [IAM 認可], [SigV4 署名。サービス間呼び出しに],
  [Cognito オーソライザー], [User Pool で発行された JWT を検証],
  [Lambda オーソライザー], [独自ロジックで認可（古いトークン形式、外部 IdP 連携）],
  [JWT オーソライザー（HTTP API）], [一般的な JWT を直接検証（Cognito 以外もOK）],
  [API キー + 使用量プラン], [サードパーティ向け公開 API でレート制限・課金],
)

=== マッピングテンプレート（VTL）

REST API でリクエスト・レスポンスを変換できる。Apache Velocity 構文。`$input.json('$.path')` のような式で JSON 加工。複雑になりがちなので、必要なら Lambda で変換する設計が無難。

=== 統合タイプ

- *Lambda Proxy*：素直にイベント全体を Lambda へ
- *Lambda Custom*：マッピングテンプレートで変換
- *AWS Service*：直接 DynamoDB、SQS 等にプロキシ（Lambda レス）
- *HTTP*：別の HTTP バックエンドへプロキシ
- *Mock*：固定レスポンスを返す（モック・ダミー）

=== WebSocket API

`$connect` `$disconnect` `$default` の3つのデフォルトルートと、`action` フィールドベースのカスタムルート。

- 接続 ID を DynamoDB で管理し、配信時に `PostToConnection` で個別送信
- 双方向リアルタイム通信（チャット、ライブ更新、ゲーム）
- レイテンシ重視ならプロデューサ側で Pub/Sub を組む

== AppSync

GraphQL のフルマネージド実装。

=== 主な特徴

- *Subscription*（リアルタイムプッシュ、WebSocket / MQTT）
- データソース：DynamoDB、Lambda、HTTP、RDS、OpenSearch、EventBridge
- 複数データソースから1リクエストで取得（GraphQL の本来の利点）
- 認証：Cognito User Pool、IAM、API Key、OIDC、Lambda
- *AppSync Merged APIs*：複数の AppSync API を統合
- *Pipeline Resolvers*：複数データソースを順に呼ぶ

=== いつ使うか

- フロント／モバイルが *柔軟なクエリ* を必要とする
- リアルタイム更新が要件
- マイクロサービスを統合したい

REST と GraphQL の選び方は宗教戦争になりがちだが、*クライアント側の柔軟性 vs サーバー側のシンプルさ* のトレードオフ。

== MQ（Managed Broker）

ActiveMQ / RabbitMQ をマネージドで提供。

- 既存システムが JMS / AMQP / STOMP / MQTT に依存している場合の移行先
- 新規構築では SQS / SNS / EventBridge を優先（料金・スケール）

== 統合パターン集

=== ファンアウト

```
[API] → SNS → SQS-A → Worker-A
            → SQS-B → Worker-B
            → SQS-C → Worker-C
```

1イベントで複数処理。各 Worker が独立にスケール、独立に DLQ 管理。

=== バッファリング

```
[Burst Traffic] → SQS → Lambda（同時実行数で制御）
```

スパイクトラフィックを SQS で吸収し、バックエンドを過負荷から守る。

=== Saga / 長時間トランザクション

```
Step Functions:
  予約 → 決済 → 在庫確保 → メール
       ↑                ↓
       └── キャンセル補償 ←─ 失敗
```

各ステップが冪等で、失敗時に補償トランザクションを実行する分散トランザクション。

=== Choreography（コレオグラフィー）

```
[Service A] → EventBridge → [Service B]
                          → [Service C]
[Service B] → EventBridge → [Service D]
```

サービス間が直接呼び出さず、イベントで疎結合に連動。マイクロサービスの典型。

=== Outbox パターン

DB トランザクションと外部メッセージ送信の整合性を保つ。DynamoDB Streams → Lambda → EventBridge / SQS の連携。

=== 人手承認

Step Functions の `.waitForTaskToken` を使い、Slack / メールでユーザーに承認 URL を送り、コールバックで再開。

== よくあるトラブル

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*症状*], [*対処*]),
  [SQS メッセージが2回処理される], [Standard は重複配信あり前提。受信側で冪等化],
  [Lambda が SQS を処理しない], [可視性タイムアウト > Lambda 実行時間、IAM 権限、Trigger 有効],
  [SNS から HTTPS 配信失敗], [HTTPS エンドポイントの応答コード 200、TLS 証明書],
  [EventBridge ルール一致しない], [パターンの完全一致 vs 部分一致、Test event で検証],
  [Step Functions のループが多い], [Map state に置換、Express を検討],
  [API Gateway 504], [Lambda タイムアウト 29 秒、バックエンド遅延],
  [CORS が効かない], [API Gateway 側の CORS 設定 + Lambda 側のヘッダ両方必要],
)
