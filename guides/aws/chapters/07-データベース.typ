= データベース

AWS は多様なデータベースサービスを提供している。リレーショナル、NoSQL、インメモリ、時系列、グラフなど、データモデルと負荷特性に合わせて選択する「*Purpose-Built Database*」という思想である。本章では代表的な4系統を扱う。

== サービス選択の早見表

#table(
  columns: (1fr, 2fr, 1fr),
  align: left,
  table.header([*サービス*], [*用途*], [*モデル*]),
  [RDS], [汎用 RDBMS（MySQL、PostgreSQL、Oracle、SQL Server、MariaDB）], [リレーショナル],
  [Aurora], [RDS 上位版。クラウドネイティブな MySQL / PostgreSQL 互換], [リレーショナル],
  [DynamoDB], [サーバーレス KVS／ドキュメント。超スケーラブル], [NoSQL (KVS)],
  [ElastiCache], [Redis / Valkey / Memcached のマネージド], [インメモリ],
  [DocumentDB], [MongoDB 互換], [ドキュメント],
  [Neptune], [グラフ DB], [グラフ],
  [Timestream], [時系列データ], [時系列],
  [Redshift], [データウェアハウス], [列指向],
  [Athena], [S3 上のデータに SQL], [サーバーレス SQL],
  [OpenSearch Service], [全文検索・ログ分析], [検索エンジン],
)

まずは *RDS / Aurora / DynamoDB / ElastiCache* の4つを押さえれば、ほとんどのユースケースに対応できる。

== RDS（Relational Database Service）

RDS は定番 RDBMS をマネージドで提供する。バックアップ・パッチ適用・フェイルオーバーを AWS 側に寄せられる。

=== サポートエンジン

- *MySQL*、*PostgreSQL*、*MariaDB*（オープンソース系）
- *Oracle*、*SQL Server*（商用。ライセンス持ち込み／含みを選べる）

新規アプリでは *PostgreSQL* か *Aurora MySQL / Aurora PostgreSQL* が選ばれることが多い。

=== インスタンスクラスとストレージ

- インスタンスクラス：`db.t3.micro`、`db.m7g.large` などEC2 と同じ命名規則
- ストレージタイプ：`gp3`（汎用SSD、デフォルト）、`io1/io2`（高IOPS）、`magnetic`（旧式）
- ストレージは後から拡張可能、*縮小は不可*

=== 高可用性：Multi-AZ 配置

Multi-AZ には2つの方式がある。

- *Multi-AZ DB インスタンス*（従来型）：別 AZ にスタンバイを置き、同期レプリケーション。*スタンバイは読み取り不可*。障害時に自動で DNS 切り替え（通常1〜2分）
- *Multi-AZ DB クラスター*（2022年以降の新方式、MySQL / PostgreSQL のみ）：*2つのリーダブルスタンバイ* を別 AZ に持ち、読み取りにも使える。フェイルオーバが従来型より高速

本番では *Multi-AZ 必須*、検証では無効にしてコストを抑える。読み取り分散と高可用性を両立したい場合は Multi-AZ DB クラスター、または後述の Aurora を検討する。

=== リードレプリカ

読み取りを分散するための非同期レプリカ。Multi-AZ と別物で、以下の特徴がある。

- 最大15台（MySQL / PostgreSQL）
- 別リージョンにも置ける（DR 用途）
- レプリカを昇格させて独立 DB にすることも可能

=== バックアップと復元

- *自動バックアップ*：デフォルト7日、最大35日。ポイントインタイム復元（PITR）が可能
- *手動スナップショット*：任意のタイミングで取る。別リージョンにコピー可
- *AWS Backup* で横断管理も可能

PITR は「3日前の午前10時15分」のような粒度で復元できる、便利機能。

=== パラメータグループとオプショングループ

- *パラメータグループ*：`max_connections` など DB 設定を管理
- *オプショングループ*：Oracle / SQL Server 向けの追加機能を管理

本番環境では *デフォルトのパラメータグループを使わず、自前のものを作る* と後から変更しやすい。

== Aurora

RDS と同じ感覚で使えるが、ストレージが *独自の分散ストレージ層* になっている。

=== Aurora の特徴

- *MySQL 5.7/8.0 互換*、*PostgreSQL 互換* の2系統
- *3 AZ × 2 コピー = 6 コピー* を AWS 側で自動管理
- 1つのクラスタ内に最大15台のリーダーを置ける
- *最大128 TiB* まで自動拡張
- *Aurora Serverless v2* では負荷に応じて自動でスケール

=== Aurora Serverless v2

ACU（Aurora Capacity Unit）単位で自動スケールする。

- 2024年11月以降、対応バージョンで *0 ACU まで自動ポーズ*（Aurora PostgreSQL 13.15+/14.12+/15.7+/16.3+、Aurora MySQL 3.08+）。再開時は約15秒のウォームアップが入る
- 検証・低頻度利用・スパイクがあるワークロードに向く
- Multi-AZ 相当の可用性

=== Aurora Global Database

複数リージョンにまたがるレプリケーション。典型的には主リージョン＋副リージョンで DR を構成する。物理ストレージレベルのレプリケーションで、通常1秒未満の RPO を実現する。

== DynamoDB

フルマネージドの NoSQL KVS / ドキュメントストア。サーバーレスで、スキーマ設計さえ合えば極端にスケールする。

=== 基本構造

- *テーブル*、*アイテム*（行に相当）、*属性*（列に相当）
- *パーティションキー*（必須）と *ソートキー*（任意）で主キーを構成
- *セカンダリインデックス*：*GSI*（グローバル）と *LSI*（ローカル）

=== 料金モード

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*モード*], [*特徴*]),
  [オンデマンド], [リクエスト単位の課金。スパイク・不定期アクセスに],
  [プロビジョンド], [秒あたりの容量（RCU/WCU）を予約。Auto Scaling 可],
)

新規プロジェクトは *オンデマンド* で始めて、負荷が読めてきたらプロビジョンドに移すのが無難。

=== Single Table Design

DynamoDB では RDB 的な「テーブルごとに正規化」は不向き。*1テーブルに複数エンティティを詰め込み、アクセスパターンごとにキー設計する* という思想が推奨される。学習コストは高めだが、これを受け入れるとスループットとコストが大きく変わる。

=== DynamoDB Streams

テーブルへの変更を24時間キャプチャする。Lambda をトリガーに、監査ログ出力、キャッシュ更新、他サービス連携などが組める。

=== Global Tables

複数リージョンのテーブルを双方向でレプリケーションする。リージョン障害時にもアプリが動き続ける「アクティブ／アクティブ」構成。

== ElastiCache

インメモリデータストアのマネージド。Redis / Valkey / Memcached をサポート。

=== 選び方

- *Valkey / Redis*：機能豊富。永続化、Pub/Sub、トランザクション、各種データ構造
- *Memcached*：シンプル KVS。マルチスレッドで純粋なキャッシュ用途

新規利用では *Valkey*（Redis フォーク、より積極的にメンテされている）か *Redis* を選ぶ。

=== 典型的なユースケース

- *セッションストア*：ALB + EC2 の後ろに置いて、セッションを共有
- *DB 前面キャッシュ*：RDS / Aurora の読み取りをキャッシュ
- *レートリミット*：API Gateway 前段での制限カウント
- *ランキング／リアルタイム集計*：Redis の Sorted Set を活用

=== クラスタモード

- *クラスタモード無効*：1つのプライマリ＋レプリカ。小〜中規模に十分
- *クラスタモード有効*：シャーディングで水平スケール。超大規模向け

=== MemoryDB for Redis

Redis 互換だが *耐久性* が大きく違う。Multi-AZ への同期書き込み、Transaction log で *DB 級の耐久性*。ElastiCache より高価。用途：

- マイクロサービスのプライマリ DB（シンプルな KV ユースケース）
- キャッシュ用途には ElastiCache、*永続 KVS* なら MemoryDB

== OpenSearch Service

全文検索・ログ分析。15章で詳述するが、DB 文脈でも重要な選択肢：

- 商品検索、全文検索
- ログ分析（CloudWatch Logs → Firehose → OpenSearch）
- ベクトル検索（KNN、RAG 用）
- Elasticsearch / Kibana 互換

Provisioned と Serverless（OCU 課金）の2モード。

== DocumentDB と Keyspaces

- *DocumentDB*：MongoDB 互換。既存 Mongo 資産の移行先
- *Keyspaces*：Cassandra 互換。Cassandra 互換ドライバから接続可

MongoDB / Cassandra をフルマネージドで使いたい場合の選択肢。ただし *100% 完全互換ではない* ため、使用機能の対応状況を事前確認。

== Neptune

グラフデータベース（Property Graph と RDF）。ソーシャルグラフ、レコメンド、不正検知、ナレッジグラフの用途。

- *Neptune Analytics*：グラフ分析 + ベクトル検索の統合
- Amazon Neptune ML：グラフ ML
- Gremlin、openCypher、SPARQL クエリ言語対応

== Timestream

時系列データベース（IoT センサー、メトリクス、金融時系列）。

- 自動的にホット層（最近）とコールド層（古い）に分離
- SQL 風クエリ
- Kinesis / IoT Core から直接取り込み
- *Timestream for InfluxDB*：InfluxDB 互換のバリアント（2024〜）

== Redshift

データウェアハウス（DWH）。列指向 MPP。15章で詳述。

- *Provisioned*（ra3 ノード）と *Serverless*
- *Spectrum* で S3 データに SQL
- *Zero-ETL* 統合（Aurora / DynamoDB → Redshift）

分析系は Redshift、トランザクション系は Aurora / DynamoDB が分担。

== データベースの選び方（再掲＋詳細）

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*要件*], [*推奨 DB*]),
  [汎用 RDBMS、OSS 互換], [Aurora PostgreSQL / Aurora MySQL],
  [既存 Oracle / SQL Server], [RDS for Oracle / SQL Server],
  [シンプル Key-Value、極端なスケール], [DynamoDB],
  [永続 KVS（耐久性必要）], [MemoryDB for Redis],
  [キャッシュ・Pub/Sub], [ElastiCache (Valkey/Redis)],
  [全文検索・ログ分析], [OpenSearch Service],
  [時系列], [Timestream],
  [グラフ], [Neptune],
  [MongoDB 互換], [DocumentDB],
  [Cassandra 互換], [Keyspaces],
  [分析・BI], [Redshift + S3 Lake],
  [機密データ・規制], [RDS / Aurora + KMS + VPC],
)

新規プロジェクトの第一候補は *Aurora PostgreSQL*（柔軟、互換、Serverless v2 で安い）。アクセスパターンが単純・高スケール要件なら *DynamoDB*。

== DB 選定のガイドライン

=== 「まず RDBMS」で始める

アクセスパターンが読めない段階では、*Aurora PostgreSQL* のような柔軟な RDBMS で始め、ボトルネックが見えてから DynamoDB / ElastiCache を足すのが安全である。初手 DynamoDB は、アクセスパターンを読み違えるとスキーマ設計のやり直しになりやすい。

=== マネージドかセルフホストか

EC2 に自前で MySQL を立てるのは、ほぼ非推奨。*バックアップ、フェイルオーバー、バージョンアップ、パッチ適用* すべて自前で面倒を見ることになり、マネージドサービスの料金差をすぐ上回るコストになる。個人検証でも Aurora Serverless v2 などでフルマネージドを使うのがよい。

=== 商用ライセンスの扱い

Oracle / SQL Server は *ライセンスインクルード* か *BYOL（持ち込み）* を選べる。既存ライセンス資産があれば BYOL、なければインクルードで試算する。

=== ユースケース別の目安

迷ったときの目安。あくまで出発点で、要件次第で見直す。

#table(
  columns: (1fr, 1.2fr, 1fr),
  align: left,
  table.header([*アプリ例*], [*主 DB*], [*付加*]),
  [個人ブログ / 社内ツール], [Aurora Serverless v2 PostgreSQL（0 ACU 対応）], [—],
  [Web アプリ（MAU 数万）], [Aurora PostgreSQL r7g.large + リーダ1台], [ElastiCache（セッション）],
  [ソーシャル系の高頻度 KV / 連番 ID 無し], [DynamoDB オンデマンド], [DynamoDB Streams → Lambda],
  [ECサイト（注文 × 検索）], [Aurora MySQL], [OpenSearch（商品検索） + ElastiCache],
  [リアルタイムランキング], [DynamoDB], [ElastiCache（Redis Sorted Set）],
  [大量センサーデータ], [Timestream], [S3 + Athena（長期保管）],
  [分析・BI], [Redshift または Aurora + Athena（S3 レイク）], [—],
  [既存 Oracle 資産], [RDS for Oracle（BYOL）], [段階的に PostgreSQL に移行],
)

== DB 周りのネットワーク

RDS / Aurora / ElastiCache は通常 *プライベートサブネット* に置く。

- DB サブネットグループ（2つ以上の AZ を指定）を作って、その中に配置
- SG で *アプリサーバの SG からのみ接続可* にする
- *パブリックアクセスを有効化しない*（個人検証でも基本禁止）

社外から接続したい場合は、踏み台 EC2 や *SSM セッションマネージャのポートフォワーディング* を使う。

```bash
# ローカルから RDS に SSM 経由でトンネリング
aws ssm start-session \
  --target i-0bastion... \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters '{"host":["mydb.xyz.ap-northeast-1.rds.amazonaws.com"],"portNumber":["5432"],"localPortNumber":["15432"]}'
```

== バックアップとリカバリのベストプラクティス

- *RPO / RTO を明確にする*：どれくらいのデータ損失と復旧時間を許容するか
- *ポイントインタイム復元* を有効化
- *定期的にリストア演習* をする：取っただけのバックアップは「使えるか」分からない
- *クロスリージョンスナップショットコピー* でリージョン災害に備える
- *IAM で削除・暗号化解除を絞る*：誰でも `DeleteDBInstance` できる状態にしない

== コスト最適化のポイント

- *アイドル DB を止める* または削除する。開発用はスケジュールで夜間停止
- *Aurora Serverless v2* で低負荷期間を 0 ACU に近づける
- *IOPS を無闇に上げない*。gp3 の場合、スループット・IOPS も課金対象
- *リードレプリカの数を見直す*：余計なレプリカは費用がかさむ
- *DynamoDB のプロビジョンドキャパシティを Auto Scaling で最適化*
