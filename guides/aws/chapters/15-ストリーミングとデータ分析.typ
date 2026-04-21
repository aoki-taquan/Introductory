= ストリーミングとデータ分析

本章ではデータの *収集（ストリーミング）→ 蓄積（データレイク）→ 加工（ETL）→ 分析（クエリ・BI）* の各レイヤを担うサービス群を扱う。

== データ分析の全体像

```
[Source] → [Ingest] → [Storage] → [Process] → [Serve]
  IoT       Kinesis     S3 Lake     Glue        Athena
  App       MSK         Iceberg     EMR         Redshift
  DB        DMS         Hudi/Delta  Spark       OpenSearch
                                                QuickSight
```

=== 各サービスの位置づけ早見表

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*レイヤ*], [*主な選択肢*]),
  [リアルタイムストリーム], [Kinesis Data Streams、MSK],
  [マネージド配信], [Kinesis Data Firehose],
  [ストリーム処理], [Kinesis Data Analytics（Flink）、Lambda、EMR Spark Streaming],
  [データレイク], [S3（+ Iceberg / Hudi / Delta）],
  [メタデータ・ETL], [Glue Data Catalog / Glue ETL / Glue DataBrew],
  [SQL クエリ（オンデマンド）], [Athena],
  [DWH], [Redshift（Serverless / Provisioned）],
  [全文検索・ログ分析], [OpenSearch Service],
  [BI ダッシュボード], [QuickSight],
  [大規模 OSS フレームワーク], [EMR（Spark / Hive / Presto / Flink）],
  [ガバナンス], [Lake Formation、DataZone],
)

== Kinesis ファミリー

=== Kinesis Data Streams

シャードベースのリアルタイムデータストリーム。

- *シャード*：1シャードあたり書き込み 1MB/秒 または 1,000 records/秒、読み出し 2MB/秒
- *保持期間*：標準24時間、最大365日
- *Producer*：KPL、SDK、Kinesis Agent、Firehose 連携
- *Consumer*：KCL、Lambda、Firehose、Flink、Glue
- *拡張ファンアウト（Enhanced Fan-Out）*：コンシューマあたり 2MB/秒の専用スループット
- *On-Demand モード*：シャード管理不要、自動スケール

=== Kinesis Data Firehose

ストリームを *S3 / Redshift / OpenSearch / Splunk / HTTP* に *バッファリングしながら配信* するマネージドサービス。

- バッファ条件（サイズ・時間）でまとめて配信
- *Lambda 変換*：配信前にレコードを加工
- *動的パーティショニング*：S3 配信時にレコード内容で `year=/month=/day=/` パスを動的決定
- フォーマット変換：JSON → Parquet / ORC（Glue カタログ参照）
- ほぼゼロ運用、バッファサイズと配信先だけ決めれば動く

=== Kinesis Data Analytics for Apache Flink

旧 KDA SQL は廃止予定。現行は *Managed Service for Apache Flink*。Flink ジョブをマネージドで実行する。

- ステートフルなストリーム処理（ウィンドウ集計、CEP、結合）
- Java / Scala / Python（PyFlink）
- *Studio Notebooks*：Zeppelin で対話的開発

=== Kinesis Video Streams

動画ストリームの取り込み・保管・再生・分析。Rekognition Video や ML パイプラインと連携。IoT カメラ・監視・スマートホームに。

== MSK（Managed Streaming for Kafka）

フルマネージド Apache Kafka。既存 Kafka エコシステム（Kafka Connect、Schema Registry、ksqlDB、Debezium 等）を使うなら MSK。

=== MSK Provisioned vs MSK Serverless

#table(
  columns: (1fr, 1fr, 1fr),
  align: left,
  table.header([*項目*], [*Provisioned*], [*Serverless*]),
  [ブローカー管理], [サイズ・台数を指定], [自動],
  [スケール], [手動 or 設定変更], [自動],
  [認証], [TLS / SASL / IAM], [IAM 必須],
  [向く規模], [常時高負荷], [スパイク・低頻度],
)

=== Kinesis Data Streams との使い分け

- *Kafka エコシステムが必要* → MSK
- *AWS ネイティブで完結* → Kinesis Data Streams
- *スループット要件が極端に高い* → どちらも対応可、コスト計算で比較
- *Lambda 統合のシンプルさ* → Kinesis Data Streams が一段楽

== S3 をデータレイクの中心に

=== Medallion アーキテクチャ

- *Bronze*：生データ（取り込んだまま、変換なし）
- *Silver*：クレンジング・正規化済み
- *Gold*：ビジネス用集計・分析向け

レイヤごとに S3 プレフィクス（`s3://lake/bronze/`、`silver/`、`gold/`）を分ける。

=== ファイルフォーマット

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*フォーマット*], [*特性*]),
  [JSON / CSV], [人間可読、互換性高、サイズ大],
  [Parquet], [列指向、圧縮効率高、Athena/Spark の標準],
  [ORC], [列指向、Hive エコシステム],
  [Avro], [行指向、スキーマ進化に強い、Kafka との相性],
)

データレイクは *Parquet + Snappy 圧縮* が定番。

=== パーティショニング

```
s3://lake/events/year=2026/month=04/day=21/hour=15/file.parquet
```

Hive 形式パスにすることで、Athena / Glue / Spark がパーティションを認識し、不要なパーティションをスキャンしないため *コストとパフォーマンス両方が改善* する。

=== Iceberg / Hudi / Delta Lake

行レベルの更新・削除、トランザクション、Time Travel、スキーマ進化を S3 上で実現する *テーブルフォーマット*。

- *Apache Iceberg*：AWS が公式に推す。Athena / Glue / EMR / Redshift Spectrum でサポート
- *Apache Hudi*：レコード単位の更新が得意
- *Delta Lake*：Databricks 主導。EMR / Glue でサポート

=== S3 Tables（2024年末 GA）

S3 が *Iceberg ネイティブ* テーブルをマネージドで提供する新機能。

- メタデータ、コンパクション、スナップショット管理を AWS 側で
- 通常の S3 General Purpose よりクエリ性能が大幅に向上
- 標準 S3 テーブルバケット、料金は別体系

== AWS Glue

サーバーレスな ETL／メタデータ統合プラットフォーム。

=== Glue Data Catalog

Hive メタストア互換の *中央メタデータ*。

- データベース → テーブル → パーティション の階層
- Athena / Redshift Spectrum / EMR / Glue ETL から共有参照
- カラム統計、Iceberg メタデータ管理
- *Lake Formation* と連携してきめ細かなアクセス制御

=== Glue Crawler

S3 上のデータをスキャンしてスキーマ推定 → Data Catalog に登録。新しいパーティションも検出。スケジュール起動も可。

=== Glue ETL

PySpark / Scala / Python Shell / Ray でジョブを書ける。

- *DynamicFrame*：Spark の DataFrame 拡張、スキーマ揺れに強い
- *Glue Studio*：GUI で ETL パイプラインを設計
- *ジョブブックマーク*：処理済みデータを記憶し、増分処理を実現
- *ワーカータイプ*：G.1X、G.2X、G.4X、G.8X

```python
import sys
from awsglue.transforms import *
from awsglue.context import GlueContext
from pyspark.context import SparkContext

sc = SparkContext()
glueContext = GlueContext(sc)

src = glueContext.create_dynamic_frame.from_catalog(
    database="raw", table_name="events"
)
clean = src.drop_fields(["password"]).resolve_choice(specs=[("amount","cast:double")])
glueContext.write_dynamic_frame.from_options(
    frame=clean,
    connection_type="s3",
    connection_options={"path": "s3://lake/silver/events/", "partitionKeys": ["year","month","day"]},
    format="parquet"
)
```

=== Glue DataBrew

ノーコードのデータ準備 GUI。300以上の変換を組み合わせる。

=== Glue Workflows

複数ジョブ・クローラを *DAG* で連結。Step Functions / EventBridge で代替も可。

== Athena

S3 上のデータに *SQL* を実行するサーバーレスクエリ。

- エンジン：Presto / Trino ベース
- フォーマット：CSV / JSON / Parquet / ORC / Avro / Iceberg / Hudi / Delta
- 料金：*スキャン量*（\$5/TB）または *Provisioned Capacity*（一定の DPU 確保）
- *CTAS*（Create Table As Select）：結果を別の S3 + Glue テーブルとして保存
- *INSERT*：既存テーブルへの追記
- *Federated Query*：DynamoDB、RDS、Snowflake、HBase 等に SQL でアクセス
- *Athena for Apache Spark*：PySpark ノートブック
- *Workgroup*：チームごとにクエリ履歴・コスト・データ範囲を分離

=== パフォーマンス＆コスト最適化

- *列指向（Parquet/ORC）*：必要列だけスキャン
- *圧縮*：Snappy / Zstd
- *パーティション*：WHERE 句で絞り込んで不要パーティションをスキップ
- *パーティション射影（Projection）*：Glue にパーティション登録なしでも高速
- *小ファイル問題*：Iceberg コンパクション、Glue ジョブで集約
- *Bloom Filter*：高選択性カラムに付ける
- *結果再利用（Result Reuse）*：直近の結果をキャッシュ

== Redshift

列指向 MPP（Massively Parallel Processing）データウェアハウス。

=== Provisioned vs Serverless

#table(
  columns: (1fr, 1fr, 1fr),
  align: left,
  table.header([*項目*], [*Provisioned*], [*Serverless*]),
  [ノード], [`ra3.xlplus`、`ra3.4xlarge` 等を選択], [選択不要],
  [スケール], [手動 or 自動], [自動],
  [課金], [ノード時間], [RPU 時間（必要時のみ）],
  [向き], [常時稼働 BI], [スパイク・PoC],
)

=== Redshift Managed Storage

ストレージとコンピュートが分離されており、データ量と計算リソースを独立にスケール。

=== Redshift Spectrum

S3 のデータに *Redshift から直接 SQL*。Athena と似ているが、Redshift の DWH と組み合わせて *レイクハウス* を構成する用途。

=== Zero-ETL 統合

Aurora / RDS for MySQL / DynamoDB → Redshift への *リアルタイム複製*。ETL ジョブを書かずに DWH 側で分析できる。2024年〜順次拡大。

=== マテリアライズドビューとデータ共有

- *Materialized View*：頻出クエリの事前集計、自動リフレッシュ
- *Data Sharing*：複数 Redshift クラスタ間でテーブルをコピーなしで共有

=== Concurrency Scaling と RA3

ピーク時に追加クラスタを自動スピンアップ。料金は1日1時間まで無料相当（クレジット）。

== OpenSearch Service

Elasticsearch / OpenSearch をマネージドで。

=== Provisioned vs Serverless

#table(
  columns: (1fr, 1fr, 1fr),
  align: left,
  table.header([*項目*], [*Provisioned*], [*Serverless*]),
  [ノード], [選択], [自動],
  [スケール], [手動 or UltraWarm], [自動],
  [向き], [常時稼働ログ基盤], [スパイク・短期分析],
)

=== 主要ユースケース

- *ログ分析*：CloudWatch Logs / Firehose / Logstash → OpenSearch → Dashboards
- *全文検索*：商品検索、サポート FAQ
- *ベクトル検索*：KNN プラグインで近傍検索（RAG 用途）

=== OpenSearch Ingestion

旧 Data Prepper のマネージド版。Source → Processor → Sink のパイプラインで OpenSearch に取り込み。

=== UltraWarm / Cold

ホット（SSD）→ ウォーム（S3 + キャッシュ）→ コールド（S3 のみ）と自動移行。長期ログ保管のコスト削減。

== QuickSight

サーバーレス BI / ダッシュボード。

- *SPICE*：インメモリ列指向エンジン
- 行・列レベルセキュリティ、データセットでのフィルタ
- 埋め込みダッシュボード（自社サービスへ組み込み）
- *Q*：自然言語クエリ
- *Generative BI*：プロンプトからダッシュボード自動生成
- 料金：作成者（Author）と閲覧者（Reader）で異なる

データソース：Redshift、Athena、RDS、S3、SaaS（Salesforce 等）、JDBC 接続。

== EMR（Elastic MapReduce）

Hadoop / Spark / Hive / Presto / Trino / Flink / HBase 等の OSS クラスタをマネージドで。

=== 形態

- *EMR on EC2*：従来形。クラスタを EC2 で
- *EMR on EKS*：Kubernetes 上で実行
- *EMR Serverless*：クラスタ管理ゼロ。Spark / Hive を必要時のみ
- *EMR on Outposts*：オンプレ環境

=== 適用シーン

- 既存 OSS Spark / Hive 資産の移行
- Glue より細かい制御や非標準フレームワーク
- 大規模バッチ ETL、ML 訓練前処理

Glue で済むなら Glue、独自要件があるなら EMR。

== Lake Formation と DataZone

=== Lake Formation

データレイク（S3 + Glue Catalog）の *きめ細かなアクセス制御*。テーブル・列・行・タグベースで権限を付与し、Athena / Redshift Spectrum / EMR / Glue ETL に統一適用。

=== DataZone

データカタログ＋ガバナンス＋協業のポータル。「データプロデューサ／コンシューマ」モデルで、ドメインごとにデータ製品を公開・申請・承認する仕組み。

== 典型アーキテクチャ

=== リアルタイムログ分析

```
App → CloudWatch Logs → Subscription Filter → Firehose → S3
                                                       → OpenSearch
                                            → Lambda（フィルタ・整形）
                                  → Athena / OpenSearch Dashboards
```

=== バッチ ETL

```
App → S3（Bronze） → Glue Crawler → Catalog
                  → Glue ETL（PySpark） → S3（Silver/Gold）
                                       → Redshift
                                   → Athena → QuickSight
```

=== リアルタイムダッシュボード

```
IoT / App → Kinesis Data Streams → Managed Flink
                                → DynamoDB / OpenSearch
                                → QuickSight ダッシュボード
```

=== レイクハウス

```
S3 + Iceberg ←→ Athena
              ←→ Redshift Spectrum
              ←→ EMR Spark
              ←→ Glue ETL
              ←→ Lake Formation（権限）
```

== コスト最適化のヒント

- *Athena*：パーティション、列指向、圧縮、結果再利用、ワークグループの上限
- *Redshift*：Serverless で開発、Provisioned + Reserved Instance で本番
- *Glue*：DPU 数を必要最小、ジョブブックマークで増分処理
- *Kinesis*：On-Demand と Provisioned のクロスオーバーを試算
- *OpenSearch*：UltraWarm / Cold の活用、不要インデックス削除
- *Firehose*：バッファサイズを調整して S3 PUT リクエスト数削減

== よくあるトラブル

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*症状*], [*対処*]),
  [Athena が遅い・高い], [パーティション、Parquet、CTAS、結果サイズ確認],
  [Glue ジョブ OOM], [DPU 数、Worker サイズ、partition、broadcast join 検討],
  [Kinesis でホットシャード], [パーティションキー設計の見直し、シャード分割],
  [Firehose 配信失敗], [IAM ロール、宛先側容量、KMS 権限],
  [Redshift がスロー], [VACUUM/ANALYZE、ディストリビューションキー設計、Concurrency Scaling],
  [OpenSearch のクラスタ Yellow/Red], [シャード数、ディスク満杯、ノード追加],
  [QuickSight でデータが見えない], [権限、データセット更新、SPICE 容量],
  [Iceberg テーブルが膨らむ], [Snapshot expiration、Compaction の定期実行],
)
