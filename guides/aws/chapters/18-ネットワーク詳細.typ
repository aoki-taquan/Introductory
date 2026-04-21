= ネットワーク詳細

4章では VPC 単体の基礎を、12章では Route 53 と CloudFront を扱った。本章は *VPC 間*・*VPC ⇔ オンプレ*・*グローバル分散* など、より大規模なネットワーク領域を扱う。

== 大規模ネットワーク設計の選択肢

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*シナリオ*], [*主な選択肢*]),
  [VPC 2〜数個], [VPC ピアリング],
  [VPC 多数 / 複数アカウント], [Transit Gateway],
  [グローバル統合管理], [Cloud WAN],
  [オンプレ ↔ AWS（簡易）], [Site-to-Site VPN],
  [オンプレ ↔ AWS（高品質・高帯域）], [Direct Connect],
  [リモートワーク端末], [Client VPN],
  [サービス間アプリ通信], [VPC Lattice、PrivateLink],
  [グローバル低レイテンシ], [Global Accelerator],
)

== Transit Gateway

VPC・VPN・Direct Connect Gateway をハブ＆スポークで接続するリージョナルサービス。VPC ピアリングの「推移的ルーティング不可」「N×N の管理コスト」を解決する。

=== アタッチメントとルーティング

- *アタッチメント*：VPC、VPN、Direct Connect Gateway、Transit Gateway Peering、Connect（GRE 経由 SD-WAN）
- *ルートテーブル*：複数作成し、アタッチメントごとに「使うルートテーブル」と「伝播するルートテーブル」を選ぶ
- *関連付け（Association）*：そのアタッチメントが参照するルートテーブル
- *伝播（Propagation）*：そのアタッチメントのルートを掲載するルートテーブル

=== セグメンテーションパターン

「Prod 同士は通信、Dev 同士は通信、Prod ⇔ Dev は不可」という設計：

- ルートテーブル `tgw-rt-prod` と `tgw-rt-dev` を作る
- Prod の VPC は `tgw-rt-prod` に関連付け、`tgw-rt-prod` にだけ伝播
- Dev も同様
- Prod ⇔ Dev のルートは存在しないので通信不可

=== マルチリージョン

*Inter-Region Peering*：別リージョンの Transit Gateway とピアリングし、AWS バックボーン経由で接続。データ転送は AWS 内ネットワーク。

=== 料金感

- アタッチメント時間課金：\$0.07/時/アタッチメント（東京）
- データ処理：\$0.02/GB
- アタッチメントが10個あれば月 \$500 を超える固定費。検証で立てっぱなしは厳禁

== Cloud WAN

*グローバルネットワーク全体* を宣言的に管理するメタ層。Transit Gateway を内包し、ポリシーベースで複数リージョン・複数アカウントの接続を一元化する。

=== コア概念

- *Core Network*：グローバル単一論理ネットワーク
- *Network Policy*：JSON ベースで定義（リージョン、セグメント、共有、ルーティング）
- *Segment*：論理的なネットワーク区切り（≒ Transit Gateway のルートテーブル相当）
- *Attachment*：VPC、VPN、Direct Connect Gateway、Transit Gateway Connect

=== いつ Cloud WAN、いつ Transit Gateway か

- *単一リージョン or 数個まで* → Transit Gateway
- *3+リージョンを統合管理したい、ポリシーで自動化したい* → Cloud WAN

== Direct Connect

専用線で AWS に接続。1 Gbps〜400 Gbps、専有 / 共有。

=== 種類

- *Dedicated Connection*：物理ポートを丸ごと借りる（1/10/100/400 Gbps）
- *Hosted Connection*：パートナー経由で割り当てられた論理線（50 Mbps〜10 Gbps）

=== Virtual Interface（VIF）

- *Private VIF*：自社 VPC への接続（VGW or Direct Connect Gateway 経由）
- *Public VIF*：AWS パブリックサービス（S3、DynamoDB 等）への直接到達
- *Transit VIF*：Direct Connect Gateway → Transit Gateway 経由で複数 VPC に分配

=== Direct Connect Gateway

複数 VPC・複数リージョンに専用線を分配する論理ゲートウェイ。

=== MACsec 暗号化

10/100 Gbps ポートで MACsec（L2 暗号化）に対応。金融・医療等で要求される場合に。

=== 冗長化

- 1拠点 + 1接続：SLA なし
- 1拠点 + 2接続：SLA 99.9%
- 2拠点 + 2接続：SLA 99.99%

本番では2拠点以上に分散する。バックアップとして Site-to-Site VPN を併用するのも一般的。

=== いつ VPN ではなく Direct Connect か

- 帯域 1 Gbps 以上の安定要件
- レイテンシが安定して低い必要がある
- 大量データ転送（VPN 経由は転送料金が高い）
- セキュリティ・コンプライアンス上の要請

== Site-to-Site VPN

IPsec で AWS とオンプレを接続。

- Customer Gateway（オンプレ側ルータ・FW）と AWS 側 VGW or Transit Gateway
- 1接続あたり2トンネル（同一 BGP 配下、片系障害時に自動フェイルオーバ）
- Static Route or BGP
- *Accelerated Site-to-Site VPN*：Global Accelerator 経由でレイテンシ改善
- 帯域の上限：1トンネル 1.25 Gbps（合計 2.5 Gbps）。それ以上は複数トンネル束ね

設定が比較的簡単で、料金も Direct Connect より安いため、まず VPN で始めて要件に応じて Direct Connect に進むのが定番。

== Client VPN

リモートワーク端末向け OpenVPN ベース。

=== 認証方式

- *相互認証*（証明書ベース）
- *Active Directory*（AD Connector or Managed AD）
- *SAML 2.0*（外部 IdP）

=== 接続フロー

ユーザー → AWS Client VPN Endpoint → ENI → ターゲット（VPC、VPC 間、オンプレ）

接続あたり時間課金 + アクティブ接続時間課金。長時間ずっとつなぎっぱなしは高くつくため、ゼロトラスト系のソリューション（AWS Verified Access）も検討。

== AWS Verified Access

社内アプリへの *VPN レス* アクセスを実現するゼロトラストサービス。Identity Center / 外部 IdP からの認証 + デバイスポスチャ（Jamf / CrowdStrike 等の連携）でアクセス可否を判定。アプリは ALB / NLB / Endpoint Groups で公開。

== Global Accelerator

AWS グローバルネットワークを *Anycast IP* で利用するアクセラレーター。

- 静的アニーキャスト IP × 2（複数リージョン宛先のフロントとして）
- AWS バックボーン経由で最寄り PoP からエンドポイントへ
- 自動フェイルオーバ、ヘルスチェック
- Custom Routing（多人数のクライアントを特定 EC2 へバインド）

=== CloudFront との違い

- *CloudFront*：HTTP/HTTPS、キャッシュあり、ウェブ向け
- *Global Accelerator*：TCP/UDP 任意、キャッシュなし、ゲーム / IoT / 独自プロトコル / API も可

両者を *併用* することもできる：CloudFront → ALB（オリジン） を Global Accelerator 経由にして、ALB へのレイテンシも安定させる。

== VPC Lattice

VPC・アカウントをまたぐ *アプリケーション層のネットワーキング*。Service Mesh 的な機能をマネージドで。

=== コンセプト

- *Service Network*：論理的なネットワーク
- *Service*：1つの実サービス（ALB / NLB / Lambda / EC2 を背後に）
- *Listener / Rule / Target Group*：Path / Header ルーティング
- *Auth Policy*：IAM ベース認可

VPC ピアリングや Transit Gateway を使わずに、*アプリケーション単位で* サービスを共有する。マイクロサービスのインターネット代替として注目されている。

== PrivateLink 詳細

4章で簡単に触れたが、PrivateLink は *NLB（または GWLB）の前段に Endpoint Service を作り、別アカウントの Interface Endpoint からプライベート IP でアクセスする* 仕組み。

=== 主要ユースケース

- AWS マネージドサービス（KMS、SQS、Secrets Manager 等）への VPC 内アクセス
- *自社 SaaS の他アカウントへの提供*（PrivateLink 経由でテナントに公開）
- 他ベンダ SaaS（Snowflake、Datadog 等）の VPC 内取り込み

=== Cross-Region Endpoints

PrivateLink が *リージョンをまたぐ* 形でも提供できるようになり、グローバル SaaS との統合が楽に。

== Network Firewall

VPC 内の *ステートフル FW*。Suricata 互換ルール、IP set、ドメインリスト。

=== 配置パターン

- *分散モデル*：各 VPC 内に Network Firewall
- *中央集約モデル*：Inspection VPC を作り、Transit Gateway でトラフィックを集約 → Network Firewall → 外向き

中央集約は管理が楽だがレイテンシ・コストが上がる。規制要件次第で選択。

=== Firewall Manager との連携

組織横断で Network Firewall ポリシーを一元管理。

== Route 53 Resolver と DNS Firewall

12章でも触れたが、ネットワーク詳細の文脈で再整理。

- *Resolver Endpoint*（インバウンド／アウトバウンド）：オンプレ ↔ VPC の名前解決
- *Resolver Rule*：条件付きフォワーディング（`*.onprem.example.com` はオンプレ DNS へ）
- *DNS Firewall*：ドメイン単位の許可・ブロック

== IPv6 戦略

AWS は段階的に IPv6 化を進めている。

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*要素*], [*IPv6 対応*]),
  [VPC], [デュアルスタック / IPv6 専用 / IPv4 専用],
  [Subnet], [デュアルスタック / IPv6 専用],
  [EC2 / ENI], [対応],
  [ALB / NLB], [デュアルスタック対応],
  [RDS], [デュアルスタックは限定。新世代エンジンから対応],
  [S3], [対応（デュアルスタック / IPv6 専用エンドポイント）],
  [Egress-only IGW], [IPv6 の外向き専用ゲートウェイ],
  [課金], [IPv6 アドレスは無料（IPv4 は2024年から課金）],
)

新規構築では *デュアルスタック* または *IPv6 専用* を検討する価値がある。IPv4 アドレス枯渇とコスト増の両面から。

== マルチアカウント・マルチリージョンの典型構成

=== 中央 Inspection VPC モデル

```
[各 VPC] →┐
          ├ Transit Gateway → Inspection VPC（NW Firewall）→ Internet
[各 VPC] →┘                                                ↑
                                                       NAT GW（中央）
```

すべての外向き通信を中央で検査。コンプライアンス要件で多用される。

=== Cloud WAN ハブ＆スポーク

```
Network Policy で宣言：
  - Region: ap-northeast-1, us-east-1
  - Segments: prod, dev, shared
  - Sharing: shared 共通、prod ⇔ dev 禁止
```

ポリシー JSON で全体構造を定義し、リージョン追加もポリシー更新だけで完結。

=== 小規模メッシュ

VPC が3〜5個ならピアリング全網で十分。Transit Gateway 固定費を回避できる。

== コスト整理

#table(
  columns: (1fr, 1fr),
  align: left,
  table.header([*転送*], [*目安料金*]),
  [同一 AZ 内], [無料（プライベート IP 経由）],
  [別 AZ（同一 VPC・同一リージョン）], [\$0.01/GB（送受双方）],
  [VPC ピアリング・Transit Gateway 越え（同一リージョン）], [\$0.01/GB + TGW \$0.02/GB],
  [別リージョン], [\$0.02〜\$0.09/GB（リージョン組み合わせで異なる）],
  [インターネットへ送信], [\$0.114/GB（東京、最初の10TB）],
  [CloudFront へ S3 から], [無料（CloudFront 経由のオリジンプル）],
  [VPC エンドポイント（Gateway型 S3/DynamoDB）], [無料],
  [VPC エンドポイント（Interface型）], [\$0.014/時 + \$0.01/GB],
)

== よくあるトラブル

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*症状*], [*確認ポイント*]),
  [VPC 間で疎通しない], [Transit Gateway ルート、SG、NACL、ルートテーブル],
  [Direct Connect が落ちた], [BGP セッション、物理リンク、AWS 障害情報],
  [VPN トンネルが片系のみ Up], [Customer Gateway 設定、IKE/IPsec パラメータ],
  [Client VPN で接続できない], [証明書、CRL、AD トラスト、エンドポイントルート],
  [Global Accelerator のヘルスチェック失敗], [リスナー設定、SG、ターゲットへの疎通],
  [PrivateLink で名前解決失敗], [Endpoint の Private DNS 有効化、Route 53 ホストゾーン],
  [TGW のデータ転送料が高い], [本当に必要なルートか、別 AZ 越えが多すぎないか確認],
  [IPv6 の外向きが通らない], [Egress-only IGW ルート、SG の IPv6 ルール],
)
