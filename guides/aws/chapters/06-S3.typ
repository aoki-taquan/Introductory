= S3（オブジェクトストレージ）

*Amazon S3（Simple Storage Service）* は、インターネット経由でアクセスできるオブジェクトストレージである。AWS で最も古いサービスの一つで、事実上無制限の耐久性・スケーラビリティを持ち、ログ保管から動画配信、データレイク、静的サイトホスティング、バックアップまで幅広く使われる。

== S3の基本概念

=== バケットとオブジェクト

- *バケット*：オブジェクトを格納する最上位の入れ物。名前はグローバルに一意
- *オブジェクト*：ファイル本体＋メタデータ＋キー（ファイルパスに相当する文字列）
- *キー（Key）*：バケット内でオブジェクトを一意に識別する文字列（例：`logs/2026/04/21/app.log`）

S3 には「ディレクトリ」は存在しない。キーに `/` を含めることで、*あたかもディレクトリ構造があるように見える* だけである。

=== 耐久性と可用性

- *耐久性（Durability）*：99.999999999%（イレブンナイン）。年間で1万個に1個失う確率が約0.0000001%
- *可用性（Availability）*：Standard は年間 99.99%（設計上）
- 内部では *複数 AZ に冗長コピー* されるため、AZ 障害を吸収できる

=== バケット名の制約

- 3～63文字、英小文字・数字・ハイフンのみ
- *グローバルで一意*（他人が `company-backup` を使っていたら作れない）
- 一度作ったら変更不可。削除して作り直す必要がある

命名規則は `<組織>-<環境>-<用途>-<リージョン>` のようにしておくと衝突しづらい（例：`acme-prod-logs-apne1`）。

== ストレージクラス

用途に合わせてストレージクラスを選ぶことで、大幅にコスト削減できる。

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*クラス*], [*特徴*]),
  [S3 Standard], [デフォルト。頻繁アクセス用],
  [S3 Intelligent-Tiering], [アクセスパターン不明な場合。自動で階層移動],
  [S3 Standard-IA (低頻度)], [月1回程度の読み出し。最小30日課金],
  [S3 One Zone-IA], [1 AZ のみ。再生成可能な二次データ],
  [S3 Glacier Instant Retrieval], [年1回程度のアクセスで即時取得],
  [S3 Glacier Flexible Retrieval], [分〜時間単位の取り出し時間を許容],
  [S3 Glacier Deep Archive], [12時間程度の取り出し。最安。長期アーカイブ],
  [S3 Express One Zone], [超低レイテンシ。ML 訓練などの高IO用],
)

個人検証では *Standard* で十分。大量ログやバックアップを貯めるなら *Glacier Deep Archive* にすると TB あたり月 \$1 程度まで落ちる。

=== ライフサイクルルール

オブジェクトの経過日数に応じて、自動的にストレージクラスを移動したり削除したりできる。

```json
{
  "Rules": [{
    "Id": "archive-old-logs",
    "Status": "Enabled",
    "Filter": { "Prefix": "logs/" },
    "Transitions": [
      { "Days": 30,  "StorageClass": "STANDARD_IA" },
      { "Days": 90,  "StorageClass": "GLACIER" },
      { "Days": 365, "StorageClass": "DEEP_ARCHIVE" }
    ],
    "Expiration": { "Days": 2555 }
  }]
}
```

これは「logs/ 配下を30日で IA、90日で Glacier、1年で Deep Archive、7年で削除」というルール。*ログ系は必ずライフサイクルルールを入れる*。

== 操作の基本

=== CLI によるアップロード／ダウンロード

```bash
# バケット一覧
aws s3 ls

# バケット作成
aws s3 mb s3://my-bucket-20260421 --region ap-northeast-1

# ファイルアップロード
aws s3 cp ./report.pdf s3://my-bucket-20260421/reports/

# ディレクトリ再帰アップロード
aws s3 sync ./dist s3://my-bucket-20260421/site/ --delete

# ダウンロード
aws s3 cp s3://my-bucket-20260421/reports/report.pdf ./

# 削除
aws s3 rm s3://my-bucket-20260421/reports/report.pdf

# バケット削除（空でない場合は --force）
aws s3 rb s3://my-bucket-20260421 --force
```

`aws s3api` は低レベル API、`aws s3` は高レベルのラッパ。普段使いは `aws s3` が便利。

=== プリサインド URL

一時的にオブジェクトへのアクセスを許可する URL。アプリから直接 S3 にアップロード／ダウンロードさせる用途で多用する。

```bash
aws s3 presign s3://my-bucket-20260421/reports/report.pdf \
  --expires-in 3600
```

URL の有効期間内は、認証なしでそのオブジェクトだけにアクセスできる。ログインユーザーに限定公開するファイル配信などに便利。

== アクセス制御

S3 のアクセス制御は歴史的経緯から *複数のレイヤ* が重なっている。これが初心者の混乱の原因になりがち。

=== 階層

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*レイヤ*], [*役割*]),
  [ブロックパブリックアクセス], [公開設定を全面禁止する強力なスイッチ（推奨 ON）],
  [IAM ポリシー], [IAM ユーザー／ロール側からバケットへの権限],
  [バケットポリシー], [バケット側に貼るリソースベースポリシー],
  [オブジェクト ACL], [旧方式。原則使わない（無効化が推奨）],
  [S3 Object Ownership], [バケット所有者に所有権を寄せる設定（推奨）],
)

=== 推奨デフォルト

新規バケットは以下の設定で作る。

- *Block all public access*：ON
- *S3 Object Ownership*：Bucket owner enforced（ACL 無効化）
- *バケット暗号化*：SSE-S3 または SSE-KMS を有効化（AWS 管理キーで十分）
- *バージョニング*：必要に応じて有効化

特別な理由（静的サイト公開など）がなければ、まずはこの「*全部閉じる*」状態にして、必要な穴だけバケットポリシーで開ける。

=== バケットポリシーの例

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowReadFromVPCE",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::my-bucket/*",
      "Condition": {
        "StringEquals": {
          "aws:SourceVpce": "vpce-0abc123..."
        }
      }
    }
  ]
}
```

「特定の VPC エンドポイントから来るリクエストだけ GetObject を許可」という制御。Principal に `*` を書いても Condition で絞っていれば安全。

=== ブロックパブリックアクセスのバイパス

公開バケット（静的サイトなど）が必要なときだけ、明示的にブロックを解除する。

```bash
aws s3api put-public-access-block \
  --bucket my-public-site \
  --public-access-block-configuration \
  "BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false"
```

この操作自体が *イベント通知されるように CloudTrail で監視* することが望ましい。

== バージョニングとオブジェクトロック

=== バージョニング

バケットごとにオン／オフを切り替える。有効にすると、上書きや削除しても過去バージョンが残る。

- *誤削除からの復旧*：`DeleteMarker` を外せば元に戻せる
- *ランサムウェア対策*：攻撃者が削除してもバージョンが残る
- *ストレージ料金が増える* ため、ライフサイクルルールで古いバージョンを削除する

=== オブジェクトロック（WORM）

法規制対応のための Write-Once-Read-Many。一度書いたら指定期間削除・上書き不可にする。

- *Governance* モード：特定権限を持つ者は解除可能
- *Compliance* モード：ルートユーザーでも解除不可

監査ログや金融系のエビデンスを改ざんから守る用途で使う。

== 静的ウェブサイトホスティング

S3 バケットで静的サイト（HTML/CSS/JS）を配信できる。

+ バケットを作成、*ブロックパブリックアクセスを解除*
+ *プロパティ* → *静的ウェブサイトホスティング* を有効化
+ インデックスドキュメントを `index.html`、エラーを `error.html` に設定
+ バケットポリシーで `s3:GetObject` を `*` に許可
+ `http://<bucket>.s3-website-<region>.amazonaws.com` でアクセスできる

ただし S3 単体では HTTPS を提供しない。*本番では CloudFront + ACM* を前段に置いて HTTPS 化するのが標準構成。

```
[ユーザー] → CloudFront (HTTPS, キャッシュ)
             ↓ OAC (Origin Access Control)
           [S3 バケット (非公開)]
```

この構成なら S3 はブロックパブリックアクセスを維持したまま、CloudFront 経由だけ許可できる。

== イベント通知

S3 へのオブジェクト作成・削除をトリガーに、Lambda / SQS / SNS / EventBridge を起動できる。

- 画像アップロード → Lambda でサムネイル生成
- ログ到着 → SQS 経由でワーカーへ
- 不正なアップロードを EventBridge で検知・通知

これは「S3 をイベント起点にした非同期処理」の定番パターン。サーバーレス構成と相性がよい。

== クロスリージョンレプリケーションと S3 Replication Time Control

耐災害性のために、別リージョンへ自動コピーする機能。

- *CRR*：クロスリージョンレプリケーション
- *SRR*：同一リージョンレプリケーション（別バケットへ）
- バージョニング有効が前提
- *S3 RTC* 付きなら 99.99% のオブジェクトが15分以内にレプリケーションされる SLA を得られる

DR（Disaster Recovery）要件があれば検討する。

== コスト最適化のポイント

- *ライフサイクルで階層化*：古いものを IA → Glacier → Deep Archive に流す
- *Intelligent-Tiering*：アクセスパターンが読めないデータに一律適用
- *不完全なマルチパートアップロードを消す*：ライフサイクルで自動削除（放置すると永久に残る）
- *バージョニング有効バケットの古いバージョン削除*：同じくライフサイクルで
- *データ転送課金に注意*：別リージョンへの転送やインターネット配信は高い
- *S3 Storage Lens* でバケット全体の使用状況を可視化

== S3 のよくあるつまずき

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*症状*], [*対処*]),
  [403 AccessDenied], [ブロックパブリックアクセス、バケットポリシー、IAMポリシーを順に確認],
  [バケットが作れない], [グローバル一意の名前にする、DNS 準拠の名前にする],
  [料金が想定外], [Cost Explorer で「S3 > リクエスト課金」「データ転送」を分析],
  [削除できない], [バージョニング有効バケット内は、全バージョンとDeleteMarkerを消す],
  [アップロード遅い], [マルチパート、Transfer Acceleration、並列数を調整],
)
