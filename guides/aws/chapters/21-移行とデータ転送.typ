= 移行とデータ転送

オンプレ・他クラウドから AWS への移行、または AWS 内・AWS 間でのデータ転送を扱う。サーバ移行（MGN）、データベース移行（DMS / SCT）、物理データ転送（Snow ファミリー）、ファイル転送（DataSync / Transfer Family）、アプリケーションリファクタ（Migration Hub）など、多数のサービスを横断的に解説する。

== AWS 移行の段取り

Gartner の *6R* フレームワークが定番。

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*戦略*], [*意味*]),
  [Rehost (Lift \& Shift)], [そのまま EC2 に持っていく。最速。最小変更],
  [Replatform (Lift \& Reshape)], [マネージド DB 化など軽い改造で乗せる],
  [Repurchase], [SaaS に置き換える],
  [Refactor / Re-architect], [クラウドネイティブに作り直す],
  [Retain], [そのままオンプレで残す],
  [Retire], [廃止],
)

最初の波は *Rehost* で量を稼ぎ、次に *Replatform* で運用負荷を下げ、戦略的なシステムだけ *Refactor* するのが現実解。

== Migration Hub

*移行のポートフォリオ管理*。各種 AWS 移行サービスの進捗を1画面で。

- アプリケーション・サーバー単位の移行ステータス管理
- *Migration Hub Strategy Recommendations*：オンプレ環境を分析して 6R を提案
- *Migration Hub Refactor Spaces*：モノリスから少しずつマイクロサービス化を進める

== Application Discovery Service

オンプレ環境の発見・依存関係マッピング。

- *Discovery Agent*：各サーバに導入して詳細データを収集
- *Discovery Connector*：vCenter 経由でエージェントレス収集
- 結果は Migration Hub に集約され、Strategy Recommendations の入力に

== AWS Application Migration Service（MGN）

*サーバ単位の Lift \& Shift* の主力サービス。旧 CloudEndure Migration の後継。

=== 仕組み

オンプレサーバ（Linux / Windows / VMware / Hyper-V / 物理）に *レプリケーションエージェント* を入れると、ブロックレベルでリアルタイムに AWS の *Staging Area*（EBS）にレプリケーション。テストで仮想 EC2 を起動して動作確認、本番カットオーバ時に *DNS / IP 切替* で新 EC2 に切り替える。

=== カットオーバの流れ

+ レプリケーション確立（初回フルコピー → 差分継続）
+ Test インスタンスを起動して動作確認
+ アプリ停止・最終差分同期
+ 本番 EC2 起動、DNS / IP 切替
+ 旧サーバ廃止

ダウンタイムを *分単位* に抑えられる。

=== 大規模移行プロジェクト

数百〜数千台の規模では、*Migration Hub の Application Group* と組み合わせて、関連サーバ一括カットオーバ。

== AWS Database Migration Service（DMS）

DB 移行・継続レプリケーション。

=== サポートする変換

- *同種*：Oracle → Oracle、PostgreSQL → PostgreSQL
- *異種*：Oracle → Aurora PostgreSQL、SQL Server → MySQL など

異種の場合は *AWS Schema Conversion Tool（SCT）* でスキーマ・ストアドプロシージャを変換 → DMS でデータ移行、という二段構え。

=== 主要モード

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*モード*], [*用途*]),
  [Full Load], [一括コピー],
  [Full Load + CDC], [一括コピー後、変更を継続適用（カットオーバまで）],
  [CDC Only], [既存スナップショット復元後、変更だけ追従],
)

CDC を使うとカットオーバ時のダウンタイムを *秒〜分* に圧縮できる。

=== DMS Serverless

2024年以降、サーバ管理不要のサーバーレス DMS が GA。短期・スパイクの移行や検証で便利。

=== Babelfish for Aurora PostgreSQL

SQL Server T-SQL を Aurora PostgreSQL で *そのまま受け入れる* 互換レイヤ。アプリ改修なしで SQL Server から移行できる場合も。

=== ヘテロジニアス移行のリアル

DMS / SCT で完全自動化はできない。実プロジェクトでは：

- *スキーマ・コード*：SCT で7〜8割自動変換、残りは手作業
- *データ*：DMS で大半を自動移行
- *アプリ側変更*：データ型差異・関数差異への対応
- *テスト*：本番並み負荷での性能・互換確認

これらを段階的にやる。

== Server Migration Service（SMS）

VMware からの移行。MGN に統合・置き換え進行中だが、既存案件で言及されることがある。

== Snow ファミリー

13章でも触れたが、移行視点で再整理。

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*デバイス*], [*用途*]),
  [Snowcone], [〜8TB。エッジコンピュート + 小規模オフライン],
  [Snowball Edge SO], [80TB クラス。中規模オフライン],
  [Snowball Edge CO], [計算強化（GPU/EC2 互換）。エッジ AI、現地データ前処理],
)

ペタバイト級は *複数台 Snowball を並列発注*。Snowmobile（40フィートトラック）は新規受注停止。

=== 利用ステップ

+ AWS コンソールから Job 作成、配送先入力
+ 数日で配送
+ 現地で電源・ネットワーク接続、AWS OpsHub（GUI）でセットアップ
+ データコピー（NFS / SMB / S3 互換 API）
+ 集荷依頼 → AWS データセンターへ返送
+ AWS 側で S3 にロード
+ 廃棄処理（NIST 準拠で複数回上書き）

== DataSync

オンライン回線でのファイル・オブジェクト同期。

=== 対応 Source / Destination

- NFS / SMB（オンプレ）
- HDFS
- オブジェクトストレージ（S3 互換、Azure Blob、Google Cloud Storage）
- AWS：S3、EFS、FSx 全種、SMB / NFS

=== 主な機能

- 並列・チャンク化転送で高速
- 完全性検証（チェックサム）
- メタデータ・ACL 保持
- スケジュール起動・継続的同期
- 帯域制御、マルチタスク
- KMS 暗号化、PrivateLink

オンプレからの ETL データ集約、クロスリージョン S3 同期、FSx 系の移行などに。

== AWS Transfer Family

SFTP / FTPS / FTP / AS2 のフルマネージド受け口。

=== ユースケース

- パートナー企業との *EDI 連携*
- 既存 SFTP クライアントから受信したファイルを S3 / EFS に
- AS2 で *B2B 取引メッセージ* を受信

認証は IAM、AD、カスタム ID プロバイダ（Lambda）、API Gateway。Workflows でアップロード後の処理（変換、解凍、PII 検出）を自動化。

== Storage Gateway とのハイブリッド転送

13章で触れたが、移行コンテキストでは：

- *File Gateway*：オンプレに NFS/SMB 提供、裏は S3。徐々にデータを S3 に移しながら使い続けられる
- *Tape Gateway*：物理テープ運用を仮想化、S3/Glacier に保存。テープライブラリ廃止プロジェクトで使う

== Database Migration の典型シナリオ

=== Oracle → Aurora PostgreSQL

+ *SCT* でスキーマ・PL/SQL の変換、変換不可コードを洗い出し
+ アプリ側の Oracle 固有 SQL を PostgreSQL 互換に修正
+ DMS で *Full Load + CDC* レプリケーション開始
+ 並行運用で動作検証
+ カットオーバ：アプリ停止 → 最終差分 → アプリを Aurora 接続に切替 → 起動

=== SQL Server → Aurora PostgreSQL（Babelfish 経由）

+ Babelfish 有効化した Aurora PostgreSQL を構築
+ アプリは *T-SQL のまま* で接続変更だけで動作（Babelfish が翻訳）
+ 段階的に PostgreSQL ネイティブ機能に置き換え

=== MySQL on EC2 → Aurora MySQL

+ Aurora MySQL クラスタ作成
+ *DMS Full Load + CDC*（または Aurora の `mysqldump` リストア）
+ アプリ接続切替

== サーバ移行の典型シナリオ

=== VMware → EC2（MGN）

+ 各 VM に MGN エージェント導入
+ レプリケーション確立、Staging Area で数日同期
+ Test 起動して動作・性能確認
+ 移行ウェーブ計画（業務関連のサーバ群を1単位で）
+ 計画停止時間内にカットオーバ
+ 本番 EC2 を Auto Scaling / Load Balancer 配下に登録

=== コンテナ化（モダナイゼーション）

- *App2Container*：Java / .NET の既存アプリを *Docker イメージ化* するツール
- *Porting Assistant for .NET*：.NET Framework → .NET Core 移行支援
- *Microservice Extractor for .NET*：モノリスから API 候補を抽出

== ライセンスと EULA

商用ソフト（Windows / SQL Server / Oracle / SAP）の移行ではライセンスが大問題。

- *License Included*：AWS 提供 AMI のライセンス込み（Windows、SQL Server）
- *BYOL*：自社ライセンスを持ち込む
- *Dedicated Host*：BYOL で *物理サーバ専有* が必要なケース（Oracle の特定エディション、Windows のソケット課金）

License Manager で利用状況を可視化。

== クラウド間の移行（GCP / Azure → AWS）

公式サービスは少ないが、以下を組み合わせる。

- *DMS*：DB 移行（Cloud SQL → Aurora など）
- *DataSync*：オブジェクトストレージ間（GCS / Azure Blob → S3）
- *MGN*：VM 移行（Compute Engine / Azure VM → EC2）
- *Migration Hub Strategy Recommendations*：移行戦略立案

== 移行の品質を上げるコツ

- *最初に Discovery を徹底*：知らないサーバ・依存は移行できない
- *本番を1台移して教訓を得る*（パイロット）
- *並行稼働期間を設ける*：1日でアプリ全切替は事故の元
- *DNS TTL を事前に短くする*：切替時の伝播時間短縮
- *ロールバック計画* を最初に決めておく
- *セキュリティベースライン* を移行先で先に整備
- *監視・ログ* を移行先で稼働させてから本番切替

== 移行後にやるべきこと

- *コスト最適化*：Reserved Instance / Savings Plans
- *マネージド化*：EC2 → ECS Fargate / Lambda / Aurora Serverless へ段階的に
- *監視刷新*：CloudWatch / X-Ray / Application Signals 導入
- *Well-Architected Review*（28章）

== よくあるトラブル

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*症状*], [*対処*]),
  [MGN レプリケーションが進まない], [帯域、エージェント側のディスク、SG、エージェント再インストール],
  [DMS の CDC ラグが大きい], [ターゲットの IOPS、テーブル並列度、長時間トランザクション排除],
  [SCT で変換不能コード多数], [手動修正、ロジックを Lambda / アプリ側へ寄せる],
  [Snowball が温度警告], [輸送中の振動・温度、AWS Support に連絡],
  [DataSync 失敗], [権限、検証エラー、ファイル名特殊文字、SMB v3 必須],
  [移行後に性能劣化], [Right-sizing、ディスクタイプ、リージョン選定],
  [Babelfish 互換性問題], [サポート関数リスト、限定機能の代替実装],
)
