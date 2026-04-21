= Aurora 深掘り

7章で扱った Aurora を、本格運用視点で深掘りする。アーキテクチャの内部構造、Serverless v2、Global Database、Zero-ETL、性能チューニング、Babelfish、移行とコスト。

== Aurora のアーキテクチャ

Aurora は MySQL / PostgreSQL 互換のデータベースエンジンを搭載しつつ、*ストレージ層を完全に書き直し* たクラウドネイティブ DB。

=== ストレージ層

```
[Aurora インスタンス]
       ↓ ログ送信
[Aurora ストレージ層]
   3 AZ × 2 コピー = 計 6 コピー
   各データブロックは 10GB セグメント
   Quorum：書き込み 4/6、読み取り 3/6
```

- *自動修復*：故障セグメントを健全な5個から再構築
- *自動拡張*：10GB ずつ最大128TiB
- *ストレージ I/O 課金*：標準は I/O 量、I/O Optimized 設定で固定料金
- *スナップショット*：高速、増分、暗号化、リージョン間コピー

=== 読み取りスケーリング

クラスタ内に最大15台の *リーダー* を配置可能。書き込みはライターから *直接ストレージへ*、リーダーは差分バッファを最小遅延で受信。

== クラスタの構成要素

- *DB クラスタ*：論理単位。1つのストレージを共有する複数インスタンス
- *ライターインスタンス*：書き込み可（1台）
- *リーダーインスタンス*：読み取り専用（最大15台）
- *クラスタエンドポイント*：常にライターを指す DNS
- *リーダーエンドポイント*：リーダー間で負荷分散
- *カスタムエンドポイント*：特定のリーダー集合を選んで提供（分析用、報告用など）

=== Aurora MySQL vs Aurora PostgreSQL

#table(
  columns: (1fr, 1fr, 1fr),
  align: left,
  table.header([*項目*], [*Aurora MySQL*], [*Aurora PostgreSQL*]),
  [互換], [MySQL 5.7 / 8.0], [PostgreSQL 13 / 14 / 15 / 16],
  [Babelfish], [—], [○（SQL Server T-SQL 互換）],
  [pg\_vector], [—], [○],
  [機能性], [シンプル], [豊富（拡張、JSON、ウィンドウ関数等）],
)

新規開発は *Aurora PostgreSQL が一般的に有利*。MySQL 互換アプリの移植には Aurora MySQL。

== Aurora Serverless v2

ACU（Aurora Capacity Unit）= 約 2 GB メモリ + 比例 CPU。

=== 自動スケーリング

```
[Min ACU]   0.5（または 0、対応バージョン）
[Max ACU]   1〜256
```

負荷に応じて *秒単位で自動スケール*。

=== 0 ACU 自動ポーズ

2024年11月以降、対応バージョンで *0 ACU まで自動ポーズ*。長時間アクセスがないと完全停止し、再アクセス時に約15秒で再開。

対応バージョン：

- Aurora PostgreSQL 13.15+/14.12+/15.7+/16.3+
- Aurora MySQL 3.08+

検証環境・PoC・低頻度バッチで *月コスト数百円〜数千円* に圧縮できる。

=== Provisioned との使い分け

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*シナリオ*], [*推奨*]),
  [安定的な常時負荷], [Provisioned + Reserved Instance],
  [スパイク・予測困難], [Serverless v2],
  [検証・開発], [Serverless v2（0 ACU）],
  [マルチテナント SaaS], [Serverless v2（テナントごと）],
)

== Aurora Global Database

複数リージョンにまたがるレプリケーション。

```
[Primary Region: 東京]                    [Secondary Region: バージニア]
   Writer + Readers                          Read-only Readers
        ↓ 物理レプリケーション（< 1秒 RPO）↗
   Aurora Storage（東京 6コピー）            Aurora Storage（バージニア 6コピー）
```

- 通常 *RPO 1秒未満*、*RTO 1分未満*
- セカンダリで *読み取り負荷分散*
- リージョン障害時、セカンダリを新プライマリに昇格（*Managed Failover* で自動化）
- セカンダリ最大5リージョン

== Zero-ETL 統合

ETL ジョブを書かずに、Aurora のデータを *リアルタイム* で他サービスへ複製。

=== Aurora → Redshift

書き込み発生から *数秒* で Redshift に反映。分析系クエリは Redshift 側で実行、トランザクション系は Aurora で。

=== Aurora → S3 / OpenSearch

S3 へのエクスポートや OpenSearch への複製も Zero-ETL 化進行中（プレビュー含む）。

=== Aurora PostgreSQL → DynamoDB

逆方向（DynamoDB → Redshift / OpenSearch）も Zero-ETL 対応。

== Aurora ML

Aurora から *SQL で SageMaker / Bedrock を呼ぶ*。

```sql
-- Aurora ML 関数の例
SELECT
  customer_id,
  aws_sagemaker.invoke_endpoint(
    'churn-prediction-endpoint',
    NULL, customer_features
  ) AS churn_score
FROM customers;
```

- ETL なしで本番 DB に推論結果を組み込める
- バッチ処理よりリアルタイム性を求める分析向け

== Babelfish for Aurora PostgreSQL

SQL Server T-SQL を *そのまま受け入れる* 互換レイヤ。Aurora PostgreSQL の追加機能。

- TDS（Tabular Data Stream）プロトコルでアプリは SQL Server だと思って接続
- 既存 .NET / Java アプリの移行コスト大幅削減
- 100% 完全互換ではない（カバレッジは公式マトリクス）
- 段階的に PostgreSQL ネイティブに置き換える経路を提供

== I/O Optimized

ストレージ I/O が大量なワークロードで *固定料金*（インスタンス・ストレージ料金が高くなるが、I/O 課金が消える）。

- I/O コストが全体の 25% を超えるなら検討
- 解析系・大量更新系のワークロード向け

== パフォーマンスチューニング

=== Performance Insights

DB の負荷を *待機イベント単位* で可視化。SQL ごと、ユーザーごと、ホストごとに集計。

- 「どの SQL が遅い」「どのテーブルがホット」
- 過去7日（無料）/ 24か月（追加料金）保持
- API で取得して自前ダッシュボードも可

=== クエリチューニング

- *EXPLAIN / EXPLAIN ANALYZE*：実行計画
- *pg\_stat\_statements*（Aurora PostgreSQL）：SQL 別統計
- *MySQL Performance Schema*（Aurora MySQL）

=== インデックス戦略

- B-tree（標準）、Hash、GIN（JSONB / 全文検索）、GiST、BRIN
- 複合インデックスは *選択性高い順*
- 部分インデックス、被覆インデックス
- 過剰なインデックスは書き込み性能を下げる

=== コネクションプール

Aurora の最大接続数は *インスタンスサイズ依存*。アプリ側で接続プール、または *RDS Proxy*。

=== RDS Proxy

接続プーリング + フェイルオーバ高速化 + IAM 認証 + Secrets Manager 統合。Lambda から Aurora を叩くときに必須に近い。

```bash
# Lambda は RDS Proxy のエンドポイントに接続
aws rds-data execute-statement \
  --resource-arn "arn:aws:rds:...:db-proxy:my-proxy" \
  --secret-arn "arn:aws:secretsmanager:..." \
  --sql "SELECT * FROM users LIMIT 10"
```

== Aurora の高可用性

=== フェイルオーバ

ライター障害時は *リーダーから自動昇格*（通常 30〜60 秒）。

- アプリは *クラスタエンドポイント* に接続することで自動追従
- 接続エラー時のリトライロジックが重要

=== Backtrack（Aurora MySQL のみ）

過去72時間まで *DB を巻き戻せる*。誤更新からの即時復旧（バックアップ＆リストアより速い）。

=== Continuous Backup

PITR が標準で有効、過去35日まで秒単位で復元。

== セキュリティ

- *IAM データベース認証*：パスワードレスで接続（短期トークン）
- *KMS 暗号化*（保管時、転送時）
- *VPC エンドポイント*（RDS API 用）
- *Database Activity Streams*：すべての DB アクティビティを Kinesis にストリーミング、監査統合

== コストの内訳

- *インスタンス時間*（Provisioned）または ACU 時間（Serverless v2）
- *ストレージ*（GB-月、I/O Optimized で挙動変化）
- *I/O リクエスト*（標準のみ）
- *バックアップストレージ*（クラスタストレージサイズ超過分）
- *Global Database*（追加リージョンの読み取り、レプリケート I/O）
- *Performance Insights*（標準7日無料、長期は別料金）
- *RDS Proxy*（vCPU 時間）

=== コスト最適化のコツ

- *Serverless v2* で 0 ACU まで落とす（対応バージョン）
- *Reserved Instance*（Provisioned 1〜3年）
- *Aurora I/O Optimized* を試算
- *リーダー数を最小化*、必要時に増やす
- *Performance Insights 7日* で十分な場合は長期保存無効
- *Backtrack* は MySQL のみで料金あり、不要なら無効

== 移行

7章・21章でも触れたが、Aurora への移行ハイライト：

=== Oracle / SQL Server → Aurora PostgreSQL

- *AWS SCT* でスキーマ・PL/SQL 変換
- *DMS* でデータ移行（Full Load + CDC）
- *Babelfish* で SQL Server からはアプリ無修正の場合も
- アプリ側 SQL の差異対応（ROWNUM → LIMIT、NVL → COALESCE 等）

=== MySQL → Aurora MySQL

互換性高く、移行は比較的容易。`mysqldump` + 復元 or DMS。

=== PostgreSQL → Aurora PostgreSQL

ほぼ無修正で移行可。`pg_dump` + 復元 or DMS。

== モニタリング

- *CloudWatch メトリクス*：CPU、メモリ、接続数、レプリケーションラグ、ディスク I/O
- *Performance Insights*：SQL レベル
- *Database Activity Streams*：監査ログ
- *Enhanced Monitoring*：OS レベルメトリクス（CPU、ディスク、ネットワーク）
- *スロークエリログ*

CloudWatch アラームの典型しきい値：

- CPU > 80% で5分継続
- レプリケーションラグ > 30 秒
- ディスクキューデプス > 1
- 接続数 > インスタンス上限の80%

== Aurora vs RDS の判断

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*要件*], [*推奨*]),
  [新規・OSS互換 (MySQL/PG)], [Aurora],
  [既存 RDS の延長], [そのまま RDS、要件あれば Aurora 移行],
  [SQL Server / Oracle], [RDS（Aurora は MySQL/PG のみ）],
  [極端な高可用性・グローバル], [Aurora（Global Database）],
  [単純・低コスト・最低限], [RDS],
  [Serverless 必須], [Aurora Serverless v2 が現実的],
)

== よくあるトラブル

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*症状*], [*対処*]),
  [接続数枯渇], [RDS Proxy、アプリ側プール、インスタンスサイズアップ],
  [Failover で接続切れ], [リトライロジック、クラスタエンドポイント使用、RDS Proxy],
  [リーダーが追従遅延], [書き込み負荷、リーダーサイズ、ネットワーク],
  [Storage Full], [128TiB 上限近い、データ整理、Aurora Limitless],
  [I/O コスト高い], [I/O Optimized 検討、クエリ最適化、キャッシュ],
  [スロークエリ], [Performance Insights、EXPLAIN、インデックス見直し],
  [Babelfish で機能不足], [互換マトリクス、PostgreSQL ネイティブで書き直し],
  [Serverless v2 がスケールしない], [Min/Max ACU、CPU/Mem の余地確認],
)
