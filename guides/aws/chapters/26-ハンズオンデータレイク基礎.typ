= ハンズオン3：データレイク基礎

S3 を中心としたデータレイク構築のミニ実装。Bronze / Silver / Gold の3層と、Glue・Athena・QuickSight を使う。

== ゴール

- *Bronze*：生 JSON ログを S3 に蓄積
- *Silver*：Glue ETL で Parquet 化、パーティション化
- *Gold*：日次集計テーブルを Athena CTAS で生成
- *Catalog*：Glue Data Catalog にメタデータ登録
- *可視化*：QuickSight でダッシュボード
- *自動化*：EventBridge Scheduler で日次実行

== 構成図

```
[App / Firehose] → s3://lake/bronze/<table>/year=/month=/day=/
                       ↓ Glue Crawler
                   Glue Data Catalog
                       ↓ Glue ETL Job（PySpark）
                   s3://lake/silver/<table>/year=/month=/day=/  Parquet
                       ↓ Athena CTAS（毎日）
                   s3://lake/gold/<dataset>/                  集計済み
                       ↓
                   QuickSight ダッシュボード
```

== ステップ1：S3 バケット準備

```bash
REGION=ap-northeast-1
ACCT=$(aws sts get-caller-identity --query Account --output text)
BUCKET="lake-${ACCT}-${REGION}"

aws s3api create-bucket --bucket $BUCKET \
  --region $REGION \
  --create-bucket-configuration LocationConstraint=$REGION

aws s3api put-bucket-versioning --bucket $BUCKET \
  --versioning-configuration Status=Enabled

aws s3api put-public-access-block --bucket $BUCKET \
  --public-access-block-configuration \
  "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# ライフサイクル：古いバージョン30日で削除、不完全マルチパート7日で削除
cat > lifecycle.json <<'EOF'
{ "Rules": [{
  "Id": "expire", "Status": "Enabled", "Filter": {},
  "NoncurrentVersionExpiration": { "NoncurrentDays": 30 },
  "AbortIncompleteMultipartUpload": { "DaysAfterInitiation": 7 }
}]}
EOF
aws s3api put-bucket-lifecycle-configuration --bucket $BUCKET \
  --lifecycle-configuration file://lifecycle.json
```

== ステップ2：サンプル生データ投入

```python
# gen.py
import json, random, uuid, datetime, os, sys
N = int(sys.argv[1]) if len(sys.argv) > 1 else 1000
day = sys.argv[2] if len(sys.argv) > 2 else datetime.date.today().isoformat()
events = []
for _ in range(N):
    events.append({
        "event_id": str(uuid.uuid4()),
        "user_id": f"u{random.randint(1, 100)}",
        "event_type": random.choice(["view", "click", "purchase"]),
        "amount": round(random.uniform(0, 1000), 2),
        "ts": f"{day}T{random.randint(0,23):02d}:{random.randint(0,59):02d}:{random.randint(0,59):02d}Z"
    })
print("\n".join(json.dumps(e) for e in events))
```

```bash
# 数日分のデータを生成して投入
for d in 2026-04-{18,19,20,21}; do
  YYYY=${d:0:4}; MM=${d:5:2}; DD=${d:8:2}
  python3 gen.py 5000 $d > /tmp/events.jsonl
  aws s3 cp /tmp/events.jsonl \
    s3://$BUCKET/bronze/events/year=$YYYY/month=$MM/day=$DD/events.jsonl
done

aws s3 ls s3://$BUCKET/bronze/events/ --recursive
```

== ステップ3：Glue Database 作成と Crawler

```bash
# Database 作成
aws glue create-database --database-input '{"Name":"lake_db"}'

# Crawler 用 IAM ロール作成
cat > trust.json <<'EOF'
{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"glue.amazonaws.com"},"Action":"sts:AssumeRole"}]}
EOF
aws iam create-role --role-name GlueLakeRole --assume-role-policy-document file://trust.json
aws iam attach-role-policy --role-name GlueLakeRole \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole

cat > s3policy.json <<EOF
{"Version":"2012-10-17","Statement":[
  {"Effect":"Allow","Action":["s3:GetObject","s3:PutObject","s3:DeleteObject","s3:ListBucket"],
   "Resource":["arn:aws:s3:::$BUCKET","arn:aws:s3:::$BUCKET/*"]}
]}
EOF
aws iam put-role-policy --role-name GlueLakeRole --policy-name S3Access \
  --policy-document file://s3policy.json

# Crawler 作成
aws glue create-crawler \
  --name lake-bronze-events \
  --role GlueLakeRole \
  --database-name lake_db \
  --targets "{\"S3Targets\":[{\"Path\":\"s3://$BUCKET/bronze/events/\"}]}"

aws glue start-crawler --name lake-bronze-events
# 数分待つ
sleep 90
aws glue get-table --database-name lake_db --name events --query 'Table.StorageDescriptor.Columns'
```

== ステップ4：Athena でクエリ

Athena 結果出力用 S3 バケットを設定（`s3://lake-XXXX/athena-results/`）。コンソールで指定してもよいし、CLI でも。

```bash
# Workgroup の結果出力先設定
aws athena update-work-group \
  --work-group primary \
  --configuration-updates "ResultConfigurationUpdates={OutputLocation=s3://$BUCKET/athena-results/}"

# クエリ実行
QID=$(aws athena start-query-execution \
  --query-string "SELECT event_type, COUNT(*) FROM lake_db.events GROUP BY event_type" \
  --result-configuration "OutputLocation=s3://$BUCKET/athena-results/" \
  --query QueryExecutionId --output text)
sleep 5
aws athena get-query-results --query-execution-id $QID
```

== ステップ5：Glue ETL ジョブで Silver 生成

`silver.py`（PySpark スクリプト）を S3 に置く。

```python
# silver.py
import sys
from awsglue.utils import getResolvedOptions
from awsglue.context import GlueContext
from pyspark.context import SparkContext
from awsglue.dynamicframe import DynamicFrame

args = getResolvedOptions(sys.argv, ['JOB_NAME', 'BUCKET'])
sc = SparkContext()
gc = GlueContext(sc)
spark = gc.spark_session

src = gc.create_dynamic_frame.from_catalog(
    database="lake_db", table_name="events"
)

df = src.toDF()
df = df.withColumn("ts", df["ts"].cast("timestamp"))
df = df.dropna(subset=["event_id"])

dyf = DynamicFrame.fromDF(df, gc, "silver")
gc.write_dynamic_frame.from_options(
    frame=dyf,
    connection_type="s3",
    connection_options={
        "path": f"s3://{args['BUCKET']}/silver/events/",
        "partitionKeys": ["year", "month", "day"]
    },
    format="parquet"
)
```

```bash
aws s3 cp silver.py s3://$BUCKET/scripts/silver.py

aws glue create-job \
  --name lake-silver-events \
  --role GlueLakeRole \
  --command "Name=glueetl,ScriptLocation=s3://$BUCKET/scripts/silver.py,PythonVersion=3" \
  --default-arguments "{\"--BUCKET\":\"$BUCKET\",\"--enable-glue-datacatalog\":\"true\"}" \
  --glue-version 5.0 \
  --worker-type G.1X \
  --number-of-workers 2

aws glue start-job-run --job-name lake-silver-events
```

完了したら Crawler を Silver にも仕掛けて Catalog に登録。

```bash
aws glue create-crawler \
  --name lake-silver-events \
  --role GlueLakeRole \
  --database-name lake_db \
  --targets "{\"S3Targets\":[{\"Path\":\"s3://$BUCKET/silver/events/\"}]}"
aws glue start-crawler --name lake-silver-events
```

これで Athena から `lake_db.events` (Silver, Parquet) が高速にクエリできる。

== ステップ6：Athena CTAS で Gold 生成

```sql
-- Athena コンソールで実行
CREATE TABLE lake_db.events_daily_summary
WITH (
  format = 'PARQUET',
  external_location = 's3://lake-XXXX/gold/events_daily_summary/',
  partitioned_by = ARRAY['day']
) AS
SELECT
  event_type,
  user_id,
  SUM(amount) AS total_amount,
  COUNT(*) AS cnt,
  CONCAT(year, '-', month, '-', day) AS day
FROM lake_db.events
GROUP BY event_type, user_id, year, month, day;
```

定期更新は `INSERT INTO ... SELECT` を Glue Workflow / EventBridge Scheduler で。

== ステップ7：QuickSight で可視化

+ QuickSight にサインアップ（Free Trial 30日）
+ 「Datasets → New dataset → Athena」
+ Workgroup は `primary`、Database は `lake_db`、Table は `events_daily_summary`
+ Direct query または SPICE インポート（小規模なら SPICE）
+ Analysis を作成、棒グラフ・折れ線グラフ・ピボット
+ Dashboard として共有

== ステップ8：日次自動化

```python
# scheduler.tf 抜粋
resource "aws_scheduler_schedule" "daily_etl" {
  name                = "daily-etl"
  schedule_expression = "cron(0 1 * * ? *)"   # 毎日 01:00 UTC
  schedule_expression_timezone = "Asia/Tokyo"
  flexible_time_window { mode = "OFF" }
  target {
    arn      = "arn:aws:scheduler:::aws-sdk:glue:startJobRun"
    role_arn = aws_iam_role.scheduler.arn
    input    = jsonencode({ JobName = "lake-silver-events" })
  }
}
```

Step Functions でクローラ → ETL → CTAS の連結も可。

== ステップ9：Lake Formation でアクセス制御（任意）

Lake Formation を有効化し、`lake_db.events` の特定列（例：`user_id` をマスク）を別グループに見せるなどの行・列・タグベース制御を導入できる。本格運用では必須。

== ステップ10：後片付け

```bash
# Glue
aws glue delete-job --job-name lake-silver-events
aws glue delete-crawler --name lake-bronze-events
aws glue delete-crawler --name lake-silver-events
aws glue delete-table --database-name lake_db --name events
aws glue delete-table --database-name lake_db --name events_daily_summary
aws glue delete-database --name lake_db

# IAM
aws iam delete-role-policy --role-name GlueLakeRole --policy-name S3Access
aws iam detach-role-policy --role-name GlueLakeRole \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole
aws iam delete-role --role-name GlueLakeRole

# QuickSight：コンソールから「Manage QuickSight → Account settings → Unsubscribe」（必要なら）

# S3
aws s3 rm s3://$BUCKET --recursive
aws s3api delete-bucket --bucket $BUCKET
```

== 学んだこと

- *Medallion アーキテクチャ*：Bronze / Silver / Gold の責務分離
- *S3 ライフサイクル + バージョニング* で安全運用
- *Glue Crawler + Catalog* でメタデータ集約
- *Glue ETL（PySpark）* でデータ加工
- *Athena CTAS* でサーバーレス DWH 風
- *QuickSight* で BI ダッシュボード
- *EventBridge Scheduler* で日次自動化

== 発展課題

- *S3 Tables（Iceberg）* で Bronze を Iceberg 化、UPSERT/DELETE をサポート
- *Lake Formation* で行・列・タグレベル権限
- *Glue DataBrew* でノーコード前処理
- *Athena Federated Query* で DynamoDB / RDS と JOIN
- *Redshift Spectrum* で同じデータを Redshift から
- *DataZone* でデータカタログ＋ガバナンスの組織化
- *SageMaker Data Wrangler* で ML 用前処理に拡張

== トラブルシューティング

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*症状*], [*対処*]),
  [Crawler が Glue ロールでアクセス拒否], [S3 バケットポリシー、ロールアタッチ確認],
  [Athena が空], [パーティション登録、Crawler 結果、`MSCK REPAIR TABLE`],
  [ETL ジョブが OOM], [DPU、Worker サイズアップ、partitioning 見直し],
  [Athena が高い], [パーティション、列指向（Parquet）、`SELECT *` 回避],
  [QuickSight 接続失敗], [Service Role 権限、Athena Workgroup 結果バケット],
  [パスのケース揺れ], [`year=2026/month=04/day=21` のようにゼロ埋め統一],
)
