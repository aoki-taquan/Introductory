= Route 53 と CloudFront

ユーザーから AWS 上のリソースへ到達するまでの経路は、*DNS 解決*（Route 53）と *エッジ配信*（CloudFront）の2つの基盤に支えられている。本章ではこの2サービスを順に解説し、最後に組み合わせの典型構成をまとめる。

== Route 53 の概要

Amazon Route 53 は、AWS のフルマネージド *権威 DNS* サービスである。加えてドメイン登録、ヘルスチェック、内部 DNS、リゾルバなど、DNS 周りの機能を一通り備える。SLA 100% が公約されている数少ないサービスのひとつ。

=== DNS の基礎おさらい

DNS は「ドメイン名 → IP アドレス」を返す分散型データベースである。

- *権威サーバ（Authoritative Server）*：そのドメインの正解を持つサーバ。Route 53 はここに位置する
- *リゾルバ（Resolver）*：クライアントから問い合わせを受けて再帰的に解決するサーバ
- *TTL（Time To Live）*：レスポンスをリゾルバ・クライアントがキャッシュしてよい秒数
- *レコードタイプ*：A（IPv4）、AAAA（IPv6）、CNAME（別名）、MX（メール）、TXT、NS、SOA、SRV、PTR など

=== Route 53 の主要コンポーネント

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*要素*], [*説明*]),
  [ホストゾーン], [ドメイン（例：`example.com`）に対するレコードの集合],
  [レコードセット], [ホストゾーン内の個別レコード],
  [Alias レコード], [Route 53 独自。AWS リソースへの「論理的な A/AAAA」],
  [ヘルスチェック], [エンドポイントの健全性監視。フェイルオーバに使う],
  [Resolver], [VPC 内の DNS 解決機構],
  [トラフィックポリシー], [複雑なルーティングを GUI で設計],
  [ドメイン登録], [TLD への登録代行],
)

== ホストゾーン

=== パブリックホストゾーン

インターネットに公開する DNS ゾーン。`example.com` を Route 53 で運用するには、まずパブリックホストゾーンを作成し、レジストラ側で *ネームサーバ（NS レコード）を Route 53 のものに設定* する。

```bash
aws route53 create-hosted-zone \
  --name example.com \
  --caller-reference $(date +%s)
```

作成すると4つの NS（`ns-XXX.awsdns-XX.com` など）が割り当てられる。これをレジストラ側に設定すれば委任完了。

=== プライベートホストゾーン

VPC 内部だけに公開する DNS ゾーン。複数 VPC・複数アカウントから参照可能。`internal.example.com` のように内部用ドメインを切るのが定石。

```bash
aws route53 create-hosted-zone \
  --name internal.example.com \
  --caller-reference $(date +%s) \
  --vpc VPCRegion=ap-northeast-1,VPCId=vpc-0abc...
```

== レコードと Alias

通常の A レコードでは IP アドレスを直接書く。AWS リソース（ALB、CloudFront、S3 静的サイト、API Gateway、Global Accelerator など）に対しては *Alias レコード* を使う。

=== Alias レコードの利点

- *エンドポイントの IP 変更に追従する*（ALB の IP は時間で変わる）
- *Apex（例：`example.com`）に直接設定可能*（CNAME は Apex に置けない）
- *追加の DNS クエリ料金がかからない*

```json
{
  "Name": "example.com",
  "Type": "A",
  "AliasTarget": {
    "HostedZoneId": "Z2FDTNDATAQYW2",
    "DNSName": "d111111abcdef8.cloudfront.net.",
    "EvaluateTargetHealth": false
  }
}
```

CloudFront ディストリビューションへの Alias。`HostedZoneId` はサービスごとの固定値（CloudFront はグローバル `Z2FDTNDATAQYW2`）。

== ルーティングポリシー

Route 53 では同名・同タイプのレコードに複数のターゲットを登録し、*DNS 応答を制御* できる。

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*ポリシー*], [*動作*]),
  [Simple], [単一ターゲット],
  [Weighted], [重み付け配分（Blue/Green、A/B テスト）],
  [Latency], [リゾルバから近いリージョンを返す],
  [Failover], [プライマリ／セカンダリ。ヘルスチェック連動],
  [Geolocation], [リクエスト元の国・大陸でターゲット切り替え],
  [Geoproximity], [地理的距離 + バイアス],
  [Multivalue Answer], [複数 IP をランダムに返す],
  [IP-based], [送信元 IP プレフィクスで分岐],
)

=== Weighted の例

```
example.com → A × 2
  - 重み 90 → ALB-blue
  - 重み 10 → ALB-green
```

Blue/Green デプロイの段階切替や、新環境のカナリアテストに使う。

=== Failover の例

```
api.example.com
  - Primary   → ALB（東京）  ヘルスチェック付き
  - Secondary → S3「メンテナンス中」ページ
```

プライマリが落ちると即座にセカンダリへフェイルオーバ。

== ヘルスチェック

Route 53 のヘルスチェックは以下を監視できる。

- HTTP / HTTPS / TCP のエンドポイント疎通
- CloudWatch アラームの状態
- 他のヘルスチェックの集計（Calculated Health Check）

ヘルスチェック失敗時、Failover ポリシーや Weighted ポリシーでターゲットから自動的に外れる。30秒・10秒間隔のいずれか、しきい値1〜10、複数リージョンからの確認が可能。

== ドメイン登録と DNSSEC

Route 53 はレジストラ機能も持つ。`.com` `.jp` `.org` など多数の TLD に対応。既存の他社レジストラから移管も可能（Auth Code が必要）。

DNSSEC も Route 53 で有効化できる。署名鍵は KMS の非対称キー（`ECC_NIST_P256` 等）で管理。改ざん検知が必要な業務ドメインで導入する。

== Route 53 Resolver と内部 DNS

VPC 内では予約アドレス（例：`10.0.0.2`）でリゾルバが動いている。*Resolver Endpoint* を追加することで、オンプレ ↔ VPC 間の名前解決が可能。

- *インバウンドエンドポイント*：オンプレから VPC 内ホスト名を解決
- *アウトバウンドエンドポイント*：VPC 内から *Resolver Rule* に基づいてオンプレ DNS へ転送

ハイブリッド環境では必須。

=== Route 53 Resolver DNS Firewall

DNS クエリのドメイン単位での許可・ブロック。マルウェアが C2 サーバへ問い合わせるのをブロック、特定 SaaS をブロック、といった用途。

== Route 53 Profiles

複数 VPC に対して、プライベートホストゾーン関連付け、Resolver Rule、DNS Firewall ルールなどを *まとめて適用* する仕組み。マルチアカウント・マルチ VPC 環境で有用。

== Route 53 の料金感

- ホストゾーン：\$0.50/月
- 標準クエリ：\$0.40/100万クエリ（最初の10億）
- Latency / Geo / Geoproximity ベースクエリ：\$0.60/100万クエリ
- ヘルスチェック：基本 \$0.50/月、AWS 外エンドポイントは \$0.75
- DNS Firewall：\$0.60/100万クエリ + ルールグループ料金

個人運用なら *月 1〜2 ドル程度* に収まる。

== CloudFront の概要

Amazon CloudFront は AWS のグローバル CDN。世界中の *エッジロケーション* と *リージョナルエッジキャッシュ* にコンテンツをキャッシュし、ユーザーに近い場所から配信する。

=== 主要メリット

- *レイテンシ削減*：地理的に近い PoP から応答
- *オリジン負荷軽減*：キャッシュヒットすればオリジンには行かない
- *DDoS 対策*：Shield Standard が無料適用
- *HTTPS 終端*：ACM 証明書で簡単に
- *エッジコンピュート*：CloudFront Functions / Lambda\@Edge

== ディストリビューションとオリジン

CloudFront の単位は *ディストリビューション*。1〜複数の *オリジン* を持つ。

=== オリジンの種類

- *S3 オリジン*：S3 バケットを直接、または OAC 経由で
- *Custom HTTP オリジン*：ALB、EC2、独自サーバ
- *Origin Group*：プライマリ／セカンダリでフェイルオーバ
- *VPC Origins*：CloudFront から VPC 内のプライベートな ALB / NLB / EC2 に直接接続

== ビヘイビアとポリシー

ディストリビューションごとに *ビヘイビア* を複数定義し、*パスパターン*（`/api/*`、`/static/*`、`*`）で振り分ける。各ビヘイビアに以下のポリシーを設定する。

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*ポリシー*], [*用途*]),
  [Cache Policy], [キャッシュキーに含める要素と TTL],
  [Origin Request Policy], [オリジンに転送する要素],
  [Response Headers Policy], [レスポンスヘッダの追加・削除（CORS、HSTS、CSP）],
)

AWS マネージドポリシーが豊富にあり、`CachingOptimized`、`CachingDisabled`、`Managed-AllViewer`、`SecurityHeadersPolicy` 等を使い回すのが定石。

=== TTL の優先順位

1. オリジン側のキャッシュヘッダ（`Cache-Control`、`Expires`）
2. Cache Policy の Min/Max/Default TTL
3. ビューア側のリクエスト（`Cache-Control: max-age=0`）

== OAC（Origin Access Control）

S3 オリジンでバケットを *非公開のまま CloudFront にだけ読ませる* 仕組み。旧来の OAI の後継で、*新規構築では OAC を使う*。

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Sid": "AllowCloudFrontOAC",
    "Effect": "Allow",
    "Principal": { "Service": "cloudfront.amazonaws.com" },
    "Action": "s3:GetObject",
    "Resource": "arn:aws:s3:::my-static-site/*",
    "Condition": {
      "StringEquals": {
        "AWS:SourceArn": "arn:aws:cloudfront::123456789012:distribution/E1ABCDEF12345"
      }
    }
  }]
}
```

== 署名付き URL / 署名付き Cookie

特定ユーザー・期間限定のアクセス制御。動画配信、有料コンテンツ、レポートダウンロードで使う。

- *署名付き URL*：1ファイルだけに有効
- *署名付き Cookie*：同一プレフィックス配下の複数ファイルに有効（HLS 動画など）

CloudFront Key Group を作って秘密鍵で署名する。

== エッジコンピュート

=== CloudFront Functions

軽量・超高速の JavaScript（ECMAScript 5.1 ベース）。リクエスト／レスポンス時に走る。

- 用途：URL 書き換え、A/B テスト、ヘッダ追加、シンプル認証
- 実行時間：1ms 以下、メモリ 2MB
- *安価*：100万リクエストあたり \$0.10
- ビューアリクエスト・ビューアレスポンスでのみ動作

```javascript
function handler(event) {
  var request = event.request;
  var uri = request.uri;
  if (uri.endsWith('/')) {
    request.uri += 'index.html';
  } else if (!uri.includes('.')) {
    request.uri += '/index.html';
  }
  return request;
}
```

=== Lambda\@Edge

Node.js / Python の Lambda をエッジで実行。

- 用途：複雑な認証、画像変換、SEO 対応の SSR、HTTP ヘッダ精密制御
- ビューアリクエスト／ビューアレスポンス／オリジンリクエスト／オリジンレスポンスの4箇所で動作
- *us-east-1 にデプロイ* → グローバルにレプリケート
- 実行時間 5〜30 秒、メモリ最大 10GB
- 通常の Lambda よりやや高い

CloudFront Functions で済むなら Functions、SDK 呼び出しや複雑処理が必要なら Lambda\@Edge。

== WAF / Shield 連携

CloudFront は WAF の関連付け先として最も自然な配置。グローバルの Web ACL を貼ることで、エッジで不正リクエストを遮断できる。Shield Standard は CloudFront 経由で自動適用。

== ログとメトリクス

- *Standard Logs（v2）*：S3 / Kinesis Firehose / CloudWatch Logs に出力。最新版（2024年後半 GA）はリアルタイム性とフィルタが向上
- *Real-time Logs*：Kinesis Data Streams 経由でほぼリアルタイム
- *CloudWatch Metrics*：リクエスト数、4xx/5xx 率、転送量
- *CloudFront Functions Metrics*：実行時間、エラー数

ログは Athena でクエリすると分析が楽。

== カスタムドメインと ACM

CloudFront でカスタムドメインを使うには ACM 証明書を *us-east-1 リージョン* で取得する必要がある（CloudFront はグローバルサービスだが、設定は北バージニア固定）。

```bash
aws acm request-certificate \
  --domain-name 'example.com' \
  --subject-alternative-names '*.example.com' \
  --validation-method DNS \
  --region us-east-1
```

DNS 検証用の CNAME レコードを Route 53 に追加する（コンソールから1クリックで生成可）。

== キャッシュ無効化

デプロイ後にキャッシュを即時破棄したいときは *Invalidation* を実行する。

```bash
aws cloudfront create-invalidation \
  --distribution-id E1ABCDEF12345 \
  --paths '/*' '/index.html'
```

無料枠は月 *1,000 パス* まで。それを超えると \$0.005/パス。

*運用ヒント*：パスでのバージョニング（`/static/v123/app.js`）にすればそもそも無効化が要らなくなる。

== CloudFront の料金感

- *データ転送*：リージョン別。東京 PoP からなら \$0.114/GB（最初の10TB）
- *リクエスト*：HTTPS で \$0.0120/10,000 リクエスト（北米・欧州）
- *無料枠*：永続無料 1TB/月の HTTP/HTTPS データ転送、1,000万リクエスト
- *Functions*：\$0.10/100万リクエスト
- *Lambda\@Edge*：通常 Lambda の数倍

個人サイト規模なら *常時無料枠* に収まることが多い。

== 統合パターン

=== 静的サイト

```
[Browser] → Route 53 (alias) → CloudFront → S3 (OAC, 非公開)
                            └ ACM (us-east-1)
                            └ WAF
```

最も典型的な構成。SPA のホスティングに最適。

=== API バックエンド

```
[Browser] → Route 53 → CloudFront ─ /static/* ─ S3
                              └─ /api/*    ─ ALB → ECS/EC2
                                              ALB → Lambda
```

静的アセットを長期キャッシュ、API はキャッシュ無効＋ Origin Request Policy で必要なヘッダのみ転送。

=== マルチリージョン

```
example.com (Latency)
  - 東京      → CloudFront → ALB-東京
  - バージニア→ CloudFront → ALB-バージニア
```

CloudFront 自体がグローバルなので、マルチリージョンは *オリジンを Route 53 で振り分け* る。Origin Group + フェイルオーバとの組み合わせも有効。

== Global Accelerator との比較

#table(
  columns: (1fr, 1fr, 1fr),
  align: left,
  table.header([*項目*], [*CloudFront*], [*Global Accelerator*]),
  [プロトコル], [HTTP/HTTPS 中心], [TCP/UDP 任意],
  [キャッシュ], [あり], [なし],
  [対象], [Web コンテンツ・API], [ゲーム、IoT、独自プロトコル],
  [IP], [配信ごとの DNS 名], [固定 Anycast IP × 2],
  [料金モデル], [リクエスト + 転送], [固定 \$18/月 + 転送],
)

ゲームサーバや独自プロトコルなら Global Accelerator、Web 配信なら CloudFront。

== よくあるトラブル

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*症状*], [*確認ポイント*]),
  [DNS が反映されない], [TTL、レジストラ側 NS、ローカル DNS キャッシュ（`dig`）],
  [CloudFront が 403], [OAC バケットポリシー、Origin Path、署名付き URL 期限切れ],
  [HTTPS が動かない], [ACM が us-east-1 か、ドメイン検証完了済みか、CNAME 一致],
  [古いコンテンツが返る], [TTL 設定、Invalidation 到達待ち、ブラウザキャッシュ],
  [API レスポンスがおかしい], [Cache Policy / Origin Request Policy のヘッダ・Cookie 設定],
  [Lambda\@Edge デプロイできない], [us-east-1、信頼ポリシーに `edgelambda.amazonaws.com`],
  [キャッシュヒット率が低い], [クエリ文字列・ヘッダ・Cookie がキャッシュキーに入りすぎ],
)

== 学習の進め方

+ Route 53 でホストゾーンを作り、無料の `.tk` などで実験
+ S3 + CloudFront + ACM の静的サイトを立てる（Free Tier 内）
+ Failover ポリシーで意図的にプライマリを落とし切り替えを確認
+ CloudFront Functions で URL 書き換えを書いて挙動を見る
+ 商用利用なら Standard Logs を S3 に出して Athena でアクセス分析
