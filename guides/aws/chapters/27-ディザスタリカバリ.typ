= ディザスタリカバリ戦略

リージョン障害・AZ 障害・大規模アカウント事故・ランサムウェア・人為ミスから復旧するための AWS 設計。本章では *RPO/RTO の決め方*、*4つの代表 DR パターン*、*クロスリージョン構成*、*バックアップ戦略*、*演習* を扱う。

== RPO と RTO

DR の話は必ずこの2つの数値から始まる。

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*指標*], [*意味*]),
  [RPO（Recovery Point Objective）], [どこまでデータ損失を許せるか（直近何分・何時間まで戻る）],
  [RTO（Recovery Time Objective）], [復旧までに何分・何時間以内に戻すか],
)

RPO = 0、RTO = 0 は理論上のみ。実際には *コストとのトレードオフ* で決める。経営判断の話で、エンジニアだけでは決まらない。

== 4つの代表 DR パターン

#table(
  columns: (1fr, 1fr, 1fr, 2fr),
  align: left,
  table.header([*パターン*], [*RPO 目安*], [*RTO 目安*], [*概要*]),
  [Backup \& Restore], [時間〜日], [時間〜日], [バックアップだけ保管、災害時に再構築],
  [Pilot Light], [分〜時間], [10分〜時間], [DR リージョンに最小限を稼働、災害時に拡張],
  [Warm Standby], [分], [分〜10分], [DR リージョンで縮小版が常時稼働],
  [Multi-Site Active-Active], [秒], [秒〜分], [両リージョンで本番、Route 53 で切替],
)

下に行くほど RPO/RTO が短く、コストが上がる。

== Backup \& Restore

最もシンプル・低コスト。

=== 構成

```
[Primary] EBS / RDS / S3
   ↓ AWS Backup（クロスリージョンコピー）
[DR Region] バックアップデータのみ保管
   ↓（災害時）
インフラを IaC で立てる + バックアップから復元
```

=== 採用ケース

- 開発・検証環境
- バッチ系・夜間バッチで RTO 余裕あり
- 法令上のバックアップ義務はあるが、即時復旧は不要

=== ベストプラクティス

- *AWS Backup* で複数サービスを横断管理
- *クロスリージョンコピー* でリージョン災害に備える
- *クロスアカウントコピー* で本番アカウント乗っ取りに備える
- *Vault Lock（Compliance モード）* でランサムウェア対策
- *S3 バケットは Versioning + MFA Delete + Replication*
- *リストア演習* を定期実施

== Pilot Light

DR リージョンに「種火」だけ残す。

=== 構成

```
[Primary Region]              [DR Region]
ALB + ASG + Aurora Cluster    Aurora Global DB Secondary（読み取り専用）
   ↓                          AMI / コンテナイメージ レプリケート済
継続的レプリケーション         ASG は0台、ALB は未稼働
                              ↓（災害時）
                              ASG を起動、Aurora を昇格、Route 53 切替
```

=== 採用ケース

- 中規模 Web、本番停止が10〜30分許容
- データは継続レプリケーション、計算は止めて節約

=== ポイント

- *Aurora Global Database* を Pilot Light の中核に
- DynamoDB なら *Global Tables*（Active-Active 風だが Pilot Light 設計でも有効）
- AMI / コンテナイメージは *EC2 AMI Cross-Region Copy* / *ECR レプリケーション*
- IaC（CDK / Terraform）で *DR 構築テンプレート* を整備し、災害時に数分で立ち上げ

== Warm Standby

DR リージョンで縮小版が常時稼働。

=== 構成

```
[Primary]                    [DR]
ALB + ASG min=2,max=20       ALB + ASG min=1,max=2（縮小）
Aurora Writer + Reader×2     Aurora Global Secondary + Reader×1
   継続レプリ + 同期確認       ヘルスチェック合格状態
                              ↓（災害時）
                              ASG を拡張、Aurora を昇格、Route 53 切替
```

=== 採用ケース

- 重要 Web、本番停止が5〜10分許容
- 切替後の負荷を最初から捌くため、最低限の Warm を持つ

=== ポイント

- DR 側も *常時アプリが動いている* のでデプロイミスなどに気付ける
- スケール拡張に *Auto Scaling グループの Predictive Scaling* を仕掛けるのも手
- DR 側 Aurora で *Read 負荷を一部分散* して稼ぐ運用も可

== Multi-Site Active-Active

両リージョンで本番。

=== 構成

```
[User] → Route 53（Latency or Geo）
       ├ Tokyo:    ALB → ECS → DynamoDB Global Tables
       └ Virginia: ALB → ECS → DynamoDB Global Tables
                       ↑
                  CloudFront（共通フロント）
```

=== 採用ケース

- グローバル B2C、停止が秒単位で許されない
- DynamoDB / Aurora Global / S3 Cross-Region Replication で *双方向書き込み*
- 競合解決ロジックがアプリに必要（最後勝ち、CRDT など）

=== ポイント

- *最も高コスト・最も複雑*。本当に必要かを先に検討
- データ整合性のレベルを明確化（Eventually Consistent でいいか）
- Route 53 のヘルスチェックでフェイルオーバ
- *スプリットブレイン* 対応（両側が独立稼働した場合の合流）

== コンポーネント別 DR 設計

=== コンピュート（EC2 / ECS / EKS / Lambda）

- *AMI Cross-Region Copy*：定期的に DR リージョンへコピー
- *ECR Cross-Region Replication*：コンテナイメージを自動レプリケート
- *Lambda 関数*：CloudFormation / CDK で DR リージョンにも展開
- *Auto Scaling Plan*：DR 側で Predictive Scaling

=== データベース

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*DB*], [*DR 機能*]),
  [Aurora MySQL/PostgreSQL], [Aurora Global Database（複数リージョン、RPO 通常 1秒未満）],
  [RDS], [Cross-Region Read Replica（昇格で DR 切替）],
  [DynamoDB], [Global Tables（マルチリージョン Active-Active）],
  [ElastiCache], [Global Datastore（Redis）],
  [DocumentDB], [Global Cluster],
  [Neptune], [Cross-Region Snapshot Copy],
  [Redshift], [Cross-Region Snapshot、Concurrency Scaling],
)

=== ストレージ

- *S3 Cross-Region Replication*：継続的レプリケーション
- *S3 Multi-Region Access Points*：複数リージョンの S3 を1エンドポイントで
- *EFS Replication*：別リージョンへ自動レプリ
- *FSx Backup* + クロスリージョンコピー
- *AWS Backup* で横断管理

=== ネットワーク・DNS

- *Route 53 Health Check + Failover*：プライマリ落下を検知して切替
- *Route 53 Application Recovery Controller（ARC）*：DR 切替の調整・手動切替
- *Global Accelerator*：Anycast IP で2リージョンを1 IP として
- *Transit Gateway Inter-Region Peering*：リージョン間 VPC 接続

=== 認証・設定

- *IAM Identity Center*：管理アカウントのリージョンが落ちると影響大。Break Glass 用 IAM ユーザーを別途用意
- *Secrets Manager Cross-Region Replication*：シークレットを DR リージョンへ
- *Parameter Store*：手動 / IaC でレプリケート
- *KMS Multi-Region Keys*：複数リージョンで同じ鍵 ID

== バックアップ戦略

=== 3-2-1 ルール

- *3つのコピー*（本番 + バックアップ × 2）
- *2つの異なるメディア*（S3 Standard + Glacier など）
- *1つはオフサイト*（別リージョン or 別アカウント）

=== AWS Backup の使い方（再掲）

- *バックアップ計画*：頻度・保持・コピー先
- *バックアップボールト*：保存先
- *Vault Lock*：Compliance モードで改ざん防止
- *クロスリージョンコピー*
- *クロスアカウントコピー*
- *Backup Audit Manager*：ポリシー遵守の監査

=== 別アカウント分離（推奨）

```
[本番アカウント] → AWS Backup → ボールト（同一アカウント）
                              → AWS Backup Cross-Account → [バックアップ専用アカウント] ボールト
                                                            ↑
                                                        Vault Lock（Compliance）
```

本番アカウントが乗っ取られても、バックアップ専用アカウントは独立した認証情報で守られる。

== ランサムウェア対策

ランサムウェアの典型攻撃は *バックアップごと暗号化・削除*。これに対抗するには：

- *別アカウント*にバックアップを置く
- *Vault Lock（Compliance モード）* で削除不能化
- *S3 Object Lock* で WORM 保管
- *MFA Delete* 有効化
- *最小権限*：本番ユーザーがバックアップを削除できない設計
- *Backup の暗号化キー* も別管理（KMS は別アカウント所有）

== 演習（Game Day）

DR は *演習しないと使えない*。最低でも年に1回、できれば四半期ごとに：

- *バックアップからのリストア演習*：実際に別アカウントに復元してみる
- *リージョン切替演習*：Route 53 の切替、DNS 伝播、アプリ動作確認
- *データベース昇格演習*：Aurora Global の Failover、整合性確認
- *人手承認フロー*：誰が判断、誰が実行、連絡経路
- *Runbook の更新*：実施で気づいた手順抜けを反映

AWS Resilience Hub を使うと、構成からレジリエンスポリシー違反を検出し、推奨を提示してくれる。

== AWS Resilience Hub

アプリケーションの *レジリエンス（耐障害性）* を評価・改善するサービス。

- アプリを CloudFormation スタック / Resource Group / EKS / AppRegistry から取り込む
- レジリエンスポリシー（RPO/RTO）と比較
- 違反を検出、推奨修正を提示
- 評価結果のレポート、IaC への組み込み

== Route 53 ARC（Application Recovery Controller）

DR 切替を *確実に* 行うための調整サービス。

- *Routing Control*：複数の Route 53 レコードを *まとめて* 切替（フェイルオーバの整合性）
- *Cluster*：5つの Cell に分散され、3/5 過半数で操作確定
- *Readiness Check*：DR 側の準備状態を継続評価

クリティカルな DR では Route 53 通常のヘルスチェックよりも ARC が安全。

== クロスアカウント DR の典型構成

```
[本番アカウント / 東京]   ──┐
                            ├ S3 Replication / Aurora Global / Backup CrossAccount
                            ↓
[DR アカウント / バージニア]
  ├ S3 バケット（受け側、Object Lock）
  ├ Aurora Global Secondary
  ├ Backup ボールト（Vault Lock）
  └ AMI / ECR コピー先
```

本番アカウントが侵害されても、DR アカウントは独立して守られる。

== コスト感

- *Backup \& Restore*：本番コストの数% 程度
- *Pilot Light*：本番コストの 5〜15%
- *Warm Standby*：本番コストの 25〜50%
- *Active-Active*：本番コストの 100%超（双方フル稼働）

ビジネス価値（ダウンタイム1時間あたりの損失額）と比較して妥当性を判断。

== チェックリスト

新規システムを設計するときに自問する項目：

- [ ] RPO / RTO は文書化されている
- [ ] バックアップは別リージョンと別アカウントに存在
- [ ] バックアップは Vault Lock or Object Lock で守られている
- [ ] リストア演習を直近6か月以内に実施
- [ ] DR リージョンで IaC の差分なく構築できる
- [ ] DNS 切替手順が文書化されている
- [ ] DB のフェイルオーバ手順が文書化されている
- [ ] Break Glass 用の認証情報が金庫保管されている
- [ ] インシデント連絡経路が定義されている
- [ ] DR 構成に対する月額コストが把握されている

== よくある落とし穴

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*落とし穴*], [*対策*]),
  [バックアップを取っただけで満足], [リストア演習、自動検証],
  [DR 側の IaC が古い], [本番デプロイ時に DR も同時 apply],
  [KMS 鍵が単一リージョン], [Multi-Region Keys に変更],
  [DNS TTL が長い], [TTL を短く（60秒程度）、切替前に短縮],
  [Aurora Global 昇格に時間がかかる], [事前に手順書、ARC で自動化],
  [Route 53 ヘルスチェック誤検知], [複数リージョンチェック、Calculated Health Check],
  [Identity Center が DR 不可], [Break Glass IAM ユーザー、リージョン障害想定],
  [演習せず本番事故で初練習], [Game Day 計画、定期演習],
)
