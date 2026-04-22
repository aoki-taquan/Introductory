= 追加のストレージサービス

EBS（ブロック）と S3（オブジェクト）は前章までで扱った。本章ではそれ以外のストレージサービス、特に *共有ファイルシステム*（EFS / FSx）、*ハイブリッド*（Storage Gateway）、*バックアップ*（AWS Backup）、*物理データ移送*（Snow ファミリー）を扱う。

== ストレージ選択の早見表

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*種類*], [*主な選択肢*]),
  [ブロック（単一サーバー）], [EBS、FSx for OpenZFS（NVMe）],
  [ファイル共有（NFS）], [EFS、FSx for Lustre、FSx for OpenZFS、FSx for NetApp ONTAP],
  [ファイル共有（SMB）], [FSx for Windows File Server、FSx for NetApp ONTAP],
  [オブジェクト], [S3],
  [バックアップ], [AWS Backup（一元管理）],
  [ハイブリッド・既存システム], [Storage Gateway],
  [大容量物理移送], [Snowball / Snowcone / Snowmobile],
  [テープライブラリ置換], [Storage Gateway Tape Gateway],
)

== EFS（Elastic File System）

*Amazon EFS* は NFSv4.1 互換のフルマネージド共有ファイルシステム。複数の EC2、Fargate タスク、Lambda 等から *同時マウント* できる。

=== 主な特徴

- *マルチ AZ で耐久性*：自動的に複数 AZ に冗長保管（One Zone クラス除く）
- *自動拡張・縮小*：使った分だけ課金、容量プロビジョニング不要
- *POSIX 互換*：UID/GID、パーミッション、シンボリックリンク
- *マウントターゲット*：AZ ごとに ENI を作成し、その IP に NFS マウント

=== ストレージクラス

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*クラス*], [*用途*]),
  [Standard], [複数 AZ・頻繁アクセス],
  [Standard-IA], [複数 AZ・低頻度アクセス（30日以上未使用）],
  [One Zone], [単一 AZ・頻繁アクセス。安価],
  [One Zone-IA], [単一 AZ・低頻度。最安],
  [Archive], [年に数回のアクセス。さらに安価（2024〜）],
)

*ライフサイクル管理* で「30日触られていないファイルを IA に」「90日触られていないファイルを Archive に」等を自動化できる。

=== スループットモード

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*モード*], [*特性*]),
  [Bursting], [容量に比例した baseline + bursting credit],
  [Provisioned], [容量と独立してスループットを予約],
  [Elastic（推奨デフォルト）], [需要に応じて自動でスケール。ほとんどのワークロードで第一選択],
)

=== マウント例

```bash
# amazon-efs-utils 経由（推奨）
sudo dnf install -y amazon-efs-utils
sudo mkdir -p /mnt/efs
sudo mount -t efs -o tls fs-0123456789abcdef0:/ /mnt/efs

# 標準 NFS クライアント
sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2 \
  fs-0123456789abcdef0.efs.ap-northeast-1.amazonaws.com:/ /mnt/efs
```

`/etc/fstab` に登録して恒久マウントする運用が一般的。

=== アクセスポイント

EFS の *アクセスポイント* は、ファイルシステム内の特定パスとユーザー ID を固定して提供する仕組み。

- アプリケーションごとに別々のディレクトリを使わせる
- root（UID=0）を強制的に別ユーザーに置き換える
- IAM で「このアクセスポイントだけアクセス可」と絞れる
- Lambda から EFS をマウントするときに必須

=== 典型ユースケース

- WordPress / Drupal などの共有メディア
- データサイエンス用の共有データセット
- コンテナ（ECS / EKS）の永続ボリューム
- 共有設定ファイル、共有ログ
- ML 訓練の中間成果物

=== 料金感

- Standard：\$0.36/GB/月（東京）
- Standard-IA：\$0.027/GB/月 ＋ アクセス料
- One Zone：Standard より約20%安
- Archive：Standard-IA よりさらに安
- Provisioned スループット：別途課金

== FSx ファミリー

EFS では合わない要件向けに、FSx は4種類の専用ファイルシステムを提供する。

=== FSx for Windows File Server

*SMB プロトコル + Active Directory 統合* の Windows 共有。Windows 業務アプリ、Microsoft SQL Server のファイルシェア、ファイルサーバ移行先として使う。

- マネージド AD 統合（または既存 AD 連携）
- DFS 名前空間、シャドウコピー（VSS）
- マルチ AZ オプションあり
- *AzureFiles のような Linux 共有需要には EFS / FSx for OpenZFS を選ぶ*

=== FSx for Lustre

*高速並列ファイルシステム*。HPC、ML 訓練、ゲノム解析などに。

- スループット数百 GB/s、IOPS 数百万
- *S3 とリンク* できる：S3 のオブジェクトをファイルとして読み書き、結果を自動同期
- Persistent / Scratch の2モード（Scratch は短期計算向け）
- Linux 用（Lustre クライアント）

=== FSx for OpenZFS

*ZFS の機能をフルマネージドで*。スナップショット、クローン、圧縮、データ整合性チェック。

- NFSv3 / v4
- 高 IOPS NVMe SSD
- スナップショットの低コスト保持、クローンの瞬時作成
- 開発環境を本番のクローンから瞬時に作る、といった使い方が得意

=== FSx for NetApp ONTAP

*既存 NetApp 資産を AWS でも*。SnapMirror、SnapVault、FlexClone、デデュプ、圧縮、Fabric Pool（コールド層を S3 に）対応。

- マルチプロトコル（NFS / SMB / iSCSI）
- オンプレ ONTAP との *SnapMirror* 連携
- 大規模 SAP、データベース、企業の汎用ファイラ

=== FSx の選び方

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*要件*], [*推奨*]),
  [Windows 共有・AD 統合], [FSx for Windows File Server],
  [HPC / ML 並列ファイル I/O], [FSx for Lustre],
  [ZFS 機能（snap/clone/圧縮）], [FSx for OpenZFS],
  [既存 NetApp 資産・マルチプロトコル], [FSx for NetApp ONTAP],
  [汎用 NFS で十分], [EFS],
)

== Storage Gateway

オンプレからクラウドへのハイブリッド接続を提供する。3つのタイプがある。

=== File Gateway

オンプレに *NFS / SMB* のエンドポイントを提供し、書き込まれたファイルを *S3 オブジェクト* として保存する。

- ローカルキャッシュ（読み出し高速化）
- POSIX メタデータの保持
- バックアップ、メディアアーカイブ、ML データ集約に

=== Volume Gateway

*iSCSI* ボリュームを提供し、裏で S3 + EBS スナップショット相当に保管する。

- *Cached モード*：プライマリは S3、ホット部分だけローカルキャッシュ
- *Stored モード*：プライマリはローカル、定期的に S3 へバックアップ

=== Tape Gateway

*仮想テープライブラリ（VTL）*。バックアップソフト（Veeam、NetBackup 等）から見ると LTO テープに見えるが、裏は S3 / Glacier。物理テープ運用の置き換え。

== AWS Backup

複数サービスを *横断的に* バックアップ管理する統合サービス。各サービスの個別バックアップ機能を一元化する。

=== 対応リソース

EBS、EC2 イメージ、RDS、Aurora、DynamoDB、EFS、FSx ファミリー、Storage Gateway、Neptune、DocumentDB、S3、Redshift、CloudFormation スタック、SAP HANA on EC2、VMware（Backup Gateway 経由）など。

=== 主要概念

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*概念*], [*説明*]),
  [バックアップ計画], [いつ取るか、どこに保存するか、何日保持するか],
  [バックアップボールト], [バックアップの保存先（KMS で暗号化）],
  [バックアップセレクション], [どのリソースを対象にするか（タグや ARN で指定）],
  [リカバリポイント], [個別のバックアップ実体],
  [ライフサイクル], [Cold storage 移行、削除のスケジュール],
)

=== クロスリージョン・クロスアカウントコピー

- *DR 用途* でリージョン災害に備える
- *監査用* に別アカウント（バックアップ専用アカウント）にコピーし、本番側からは削除できなくする

=== ボールトロック（Vault Lock）

バックアップボールトに *WORM* を効かせる機能。

- *Compliance モード*：誰も削除できない（ルートユーザーでも）
- *Governance モード*：特定権限を持つ管理者は解除可能

ランサムウェア対策・規制対応の決定版。

=== AWS Backup Audit Manager

バックアップが定義したフレームワーク（バックアップ頻度、保持期間、ボールトロック）を満たしているかを継続評価。レポート生成・SNS 通知。

== Snow ファミリー

ペタバイト級データの物理移送、エッジコンピューティング向け。

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*デバイス*], [*用途*]),
  [Snowcone], [小型・8TB 程度。エッジ・小規模オフライン],
  [Snowball Edge Storage Optimized], [80TB 超のオフライン移送],
  [Snowball Edge Compute Optimized], [現地でのコンピュート＋ストレージ],
  [Snowmobile（提供終了）], [40フィートコンテナ。エクサバイト級。後継は大量 Snowball],
)

「100TB を月の回線でアップロードすると数か月かかる、Snowball で送る方が速くて安い」というケースで採用。デバイス物理輸送のリードタイム（1〜2週間）を含めて計画する。

== DataSync

オンプレ ↔ AWS、AWS 間でのデータ同期サービス。

- 対応元／先：NFS / SMB / HDFS / オブジェクトストレージ / S3 / EFS / FSx
- 並列・高速転送、検証付き
- スケジュール実行、増分差分転送
- 帯域制御
- KMS 暗号化、整合性チェック

オンライン回線でリーズナブルな時間で送れる規模なら DataSync、それを超えるなら Snow。

== ストレージ コスト最適化のコツ

- *S3*：ライフサイクルで階層化、Intelligent-Tiering、不完全マルチパート削除、バージョン整理
- *EBS*：未使用ボリュームの削除、`gp2 → gp3` 移行（性能割安）
- *EFS*：ライフサイクルで IA・Archive へ、Elastic スループットで自動最適化
- *FSx*：Lustre は計算終了後すぐ破棄、OpenZFS のスナップショット定期整理
- *Backup*：Cold ストレージ移行（Glacier 相当）、リージョン分離戦略の見直し
- *Storage Gateway*：ローカルキャッシュサイズの妥当性検証

== ベンチマーク・パフォーマンス計測

- *fio*（Linux）：ブロック・ファイル両方の汎用ベンチ
- *iperf*：ネットワーク帯域
- *AWS 公式パフォーマンス計測スクリプト*：EFS 用、Lustre 用に提供あり

ストレージはワークロード特性次第で適合解が変わる。本番投入前に必ず実データで検証する。

== よくあるトラブル

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*症状*], [*対処*]),
  [EFS マウントできない], [SG で 2049（NFS）開放、`amazon-efs-utils`、IAM Mount 権限],
  [EFS が遅い], [Bursting Credit 枯渇 → Elastic スループットに変更],
  [FSx Windows に AD ログインできない], [DNS 名解決、AD 同期、SMB 暗号化要件],
  [Storage Gateway がオフラインに], [VM のリソース、ネットワーク疎通、アクティベーションキー再発行],
  [AWS Backup ジョブが失敗], [IAM ロール、リソースポリシー、ボールト KMS 権限],
  [Snowball が届かない], [配送業者追跡、税関、AWS Support に問い合わせ],
)
