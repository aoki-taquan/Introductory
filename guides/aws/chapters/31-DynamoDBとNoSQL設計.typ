= DynamoDB と NoSQL 設計

7章でデータベース全般の中で触れた DynamoDB を、本章では本格的な設計手法と運用面で深掘りする。Single Table Design、GSI/LSI、トランザクション、Streams、容量設計、TTL、グローバル分散まで。

== DynamoDB の本質

NoSQL を「SQL の弱体版」と捉えると失敗する。DynamoDB は *アクセスパターン駆動* の設計で、SQL の正規化思想とは別物。

=== 強み

- *無制限スケール*：パーティション分散、自動シャーディング
- *ミリ秒台レイテンシ*：シングルキー操作で安定 1〜10ms
- *サーバーレス*：容量管理・パッチ・バックアップが自動
- *耐久性*：3 AZ に同期書き込み
- *グローバル分散*：Global Tables でマルチリージョン Active-Active

=== 弱み

- *柔軟なクエリ不可*：スキャンは高コスト、JOIN なし
- *スキーマ変更が前提のクエリ*：あとからアクセスパターンを増やすと再設計
- *容量予測の難しさ*：オンデマンドが救いだが青天井
- *学習コスト*：SQL とは設計思想が根本的に違う

== 主要概念の整理

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*概念*], [*説明*]),
  [テーブル], [トップレベル],
  [アイテム], [テーブル内の1レコード（最大400KB）],
  [属性], [アイテム内のキー・値ペア],
  [パーティションキー (PK)], [必須。ハッシュ値でアイテムを分散],
  [ソートキー (SK)], [任意。同じ PK 内で順序付け],
  [プライマリキー], [PK 単独 or PK + SK],
  [セカンダリインデックス], [GSI (Global) / LSI (Local)],
  [Read/Write Capacity Unit], [プロビジョンド時の単位],
  [On-Demand], [リクエスト課金、容量管理不要],
)

== Single Table Design

DynamoDB のベストプラクティス。*1テーブルに複数エンティティを詰める* 設計。

=== なぜ単一テーブルか

- *リクエスト数最小化*：1 query で関連エンティティをまとめて取得
- *トランザクション境界*：1テーブル内で `TransactWriteItems` が使える
- *コスト効率*：複数テーブルより容量管理が楽

=== 実例：注文システム

```
PK              SK                  type      attrs
USER#u1         PROFILE             User      name, email
USER#u1         ORDER#o1            Order     total, status
USER#u1         ORDER#o2            Order     total, status
ORDER#o1        ITEM#i1             OrderItem product_id, qty
ORDER#o1        ITEM#i2             OrderItem product_id, qty
PRODUCT#p1      META                Product   name, price
PRODUCT#p1      REVIEW#r1           Review    rating, text
```

これで以下のクエリが *1 query* で解決：

- `PK=USER#u1` → ユーザー＋全注文
- `PK=USER#u1, SK begins_with ORDER#` → 注文一覧
- `PK=ORDER#o1` → 注文＋全アイテム
- `PK=PRODUCT#p1, SK begins_with REVIEW#` → 商品レビュー

=== Generic な属性名

- `PK`、`SK`：プライマリキー
- `GSI1PK`、`GSI1SK`：GSI1 のキー
- `entity_type`：論理エンティティ識別

エンティティごとに属性名を変えると GSI 設計が破綻する。*論理名は値（type 属性）で表現* する。

== セカンダリインデックス

=== GSI（Global Secondary Index）

別の PK・SK で *別の view* を作る。最大20個。元テーブルから *非同期で射影* される。

```
GSI1: PK=email, SK=USER         → email でユーザー検索
GSI2: PK=ORDER, SK=created_at   → 注文を時系列で
GSI3: PK=status, SK=updated_at  → ステータス別注文
```

=== LSI（Local Secondary Index）

PK は同じで *別の SK* を持つ。テーブル作成時のみ作れる、最大5個。同期書き込み（強整合性可）。

GSI が柔軟性高く実用的、LSI は設計初期に固める覚悟があるとき。

=== Sparse Index

一部のアイテムにしかキー属性が存在しない GSI。「ステータスが `pending` のものだけインデックス」のような絞り込みに有用。

== 容量モード

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*モード*], [*特徴*]),
  [On-Demand], [リクエスト課金、自動スケール、上限なし。新規・スパイク向け],
  [Provisioned], [RCU/WCU を予約、Auto Scaling 可。安定負荷向け],
)

=== Capacity Unit の計算

- *RCU*：強整合性 1個 = 4KB/秒、結果整合性 = 半分、トランザクション = 2倍
- *WCU*：1個 = 1KB/秒、トランザクション = 2倍

例：10 KB のアイテムを毎秒10回読む（強整合性）→ 10 × 3 RCU = 30 RCU

=== Auto Scaling

Provisioned で目標利用率（例：70%）を設定し、自動でスケール。応答が遅いので *スパイク前提なら On-Demand*。

=== Reserved Capacity

Provisioned の長期予約で割引。

== トランザクション

`TransactWriteItems` / `TransactGetItems` で *最大100個のオペレーション* をアトミックに。

```python
ddb.meta.client.transact_write_items(TransactItems=[
    {'Put': {'TableName': 't', 'Item': {'PK': 'X', 'SK': 'A'}}},
    {'Update': {'TableName': 't', 'Key': {'PK': 'X', 'SK': 'B'},
                'UpdateExpression': 'SET counter = counter + :one',
                'ExpressionAttributeValues': {':one': 1}}},
    {'ConditionCheck': {'TableName': 't', 'Key': {'PK': 'X', 'SK': 'C'},
                        'ConditionExpression': 'attribute_exists(PK)'}},
])
```

WCU は2倍消費。トランザクション失敗時は全部ロールバック。

=== Optimistic Locking

`version` 属性を持たせ、`UpdateExpression` で `:expectedVersion` 条件チェック。

== DynamoDB Streams

テーブルへの変更を24時間キャプチャ。

- レコードに OLD\_IMAGE / NEW\_IMAGE / KEYS\_ONLY / NEW\_AND\_OLD\_IMAGES の4種
- *Lambda トリガー*：変更を非同期処理
- *Kinesis Data Streams へ送信*（拡張オプション）：より長期保持、複数コンシューマ

=== ユースケース

- *監査ログ*：変更を別ストレージに記録
- *他 DB へのレプリケーション*：DynamoDB → ElastiCache、OpenSearch
- *Outbox パターン*：DB 変更をイベントとして発行
- *マテリアライズドビュー*：別 PK で再保存

== TTL（Time To Live）

特定属性に *Unix エポック秒* を入れておくと、その時刻を過ぎたアイテムが自動削除される（48時間以内）。

```python
import time
item['expires_at'] = int(time.time()) + 30 * 24 * 60 * 60   # 30日後
```

セッション、一時データ、ログのライフサイクル管理に。

== Global Tables

複数リージョンに *双方向レプリケーション*。Active-Active のマルチリージョン構成を実現。

- レプリケーションラグ通常1秒未満
- Last-Writer-Wins（LWW）で競合解決
- 各リージョンで独立に書き込み可

=== ユースケース

- グローバル B2C アプリのレイテンシ削減
- リージョン障害時のフェイルオーバ
- 開発・ステージング環境の地理分散

== バックアップとリカバリ

- *On-Demand Backup*：手動スナップショット、長期保持
- *Point-in-Time Recovery（PITR）*：5分単位で過去35日まで復元
- *AWS Backup* との統合：横断管理、クロスリージョン・アカウントコピー
- *Export to S3*：JSON / Ion / DynamoDB JSON 形式で全件エクスポート、Athena で分析

== パフォーマンスチューニング

=== Hot Partition（熱いパーティション）

特定の PK に書き込み・読み込みが集中するとスロットルが起きる。

- *書き込みシャーディング*：PK に乱数 suffix を付ける（`USER#u1#0`〜`USER#u1#9`）→ 読み出し時は10回 query して合算
- *Adaptive Capacity*：DynamoDB 側が自動で Hot Partition に余分容量割当（一定範囲）
- *書き込みのバッチ化* と *バッファリング*

=== Query vs Scan

- *Query*：PK 指定の効率的な検索
- *Scan*：全件走査。本番では原則禁止。バッチ処理でも *Parallel Scan* で並列化

=== DAX（DynamoDB Accelerator）

DynamoDB 専用のインメモリキャッシュ。マイクロ秒台レスポンス。

- ItemCache（個別 GET の結果）と QueryCache
- 書き込みは write-through（キャッシュ＋本体両方更新）
- VPC 内に配置、SDK が透過的に利用

== コスト最適化

- *On-Demand vs Provisioned*：使用パターンを Cost Explorer で見て切り替え
- *PITR* は別料金。検証環境では無効化検討
- *DAX* で読み出しコスト削減
- *S3 Export* で長期保管を低単価に
- *TTL* で不要データを自動削除
- *RCU/WCU の予約購入*（Reserved Capacity）

== セキュリティ

- *KMS 暗号化*（デフォルト有効、CMK に切替可）
- *VPC エンドポイント*（Gateway 型、無料）：プライベートサブネットから利用
- *IAM ポリシー*：`Condition` で `dynamodb:LeadingKeys` を使い *PK ベースの行レベルアクセス* 制御
- *Resource-based policy*：別アカウント共有

```json
{
  "Effect": "Allow",
  "Action": ["dynamodb:GetItem", "dynamodb:Query"],
  "Resource": "arn:aws:dynamodb:*:*:table/MyTable",
  "Condition": {
    "ForAllValues:StringEquals": {
      "dynamodb:LeadingKeys": ["${aws:PrincipalTag/TenantId}"]
    }
  }
}
```

== 監視

CloudWatch メトリクス：

- `ConsumedRead/WriteCapacityUnits`
- `ThrottledRequests`
- `SystemErrors`、`UserErrors`
- `SuccessfulRequestLatency`
- `ReturnedItemCount`

CloudWatch Contributor Insights：*どの PK が熱い* かを可視化。

== Single Table Design vs RDB の判断

新規プロジェクトで NoSQL を採用するべきか：

#table(
  columns: (1fr, 1fr),
  align: left,
  table.header([*要件*], [*向き*]),
  [アクセスパターンが固定], [DynamoDB 有利],
  [毎週新しい分析クエリ], [RDB / 列指向 DB],
  [スパイク・スケール性], [DynamoDB 有利],
  [JOIN 多用], [RDB 有利],
  [トランザクション複雑], [RDB 有利],
  [グローバル分散], [DynamoDB Global Tables 有利],
  [厳密な ACID], [RDB / Aurora],
  [スキーマレス・進化], [DynamoDB 柔軟],
)

「*まず Aurora で始めて、ボトルネックや特定要件で DynamoDB に部分移行*」が安全。

== よくある罠

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*罠*], [*対処*]),
  [Scan で本番遅い・高い], [Query 設計、必要なら GSI 追加],
  [Hot Partition でスロットル], [シャーディング、Adaptive Capacity],
  [後からアクセスパターンを増やしたい], [GSI 追加、テーブル再設計覚悟],
  [`UpdateExpression` の予約語衝突], [`ExpressionAttributeNames` で別名],
  [サイズ超過 (>400KB)], [大きなフィールドを S3 に置き、参照だけ DynamoDB],
  [TTL が即時消えない], [削除は最大48時間遅延、これは仕様],
  [GSI が遅延], [非同期。書き込み直後の整合性は期待しない],
  [Global Tables で競合], [LWW、競合検知ロジックをアプリ側で],
)
