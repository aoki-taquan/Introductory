= IoT・エッジ・メディア

業界向けの専門領域として、*IoT*（モノとクラウド連携）、*エッジコンピューティング*（クラウドの拡張）、*メディア配信*（動画ストリーミング）を扱う。これらは個別のドメインだが、AWS の主要サービス領域として無視できない。

== AWS IoT サービス群

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*サービス*], [*用途*]),
  [IoT Core], [デバイスとの MQTT/HTTPS/WebSocket メッセージング、デバイス認証],
  [IoT Device Management], [デバイスのプロビジョニング・グループ管理・ファーム更新],
  [IoT Device Defender], [デバイス挙動の異常検知],
  [IoT Greengrass], [エッジ実行環境（Lambda / Docker / 機械学習をデバイスで）],
  [IoT Analytics], [IoT データの収集・前処理・分析],
  [IoT Events], [複雑イベント処理、デバイス状態管理],
  [IoT SiteWise], [産業用 IoT データの収集・モデリング],
  [IoT TwinMaker], [デジタルツイン構築],
  [FreeRTOS], [マイコン向けリアルタイム OS],
)

== IoT Core

IoT の中核。

=== デバイス接続

- *MQTT*（推奨、軽量パブサブ）
- *MQTT over WebSocket*（ファイアウォール越え）
- *HTTPS*（送信のみ、デバイス少なめ）
- *LoRaWAN*（IoT Core for LoRaWAN）

=== 認証

- *X.509 証明書*：デバイス1台ごとに発行
- *IAM 認証*：SDK / モバイルアプリ
- *Custom Authorizer*：独自のトークンベース

=== Things、Thing Group、Thing Type

デバイスを *Thing* として登録し、グループ・タイプで分類。属性（製造番号、ファーム版、所属拠点）を付ける。

=== Device Shadow

デバイスの *最新状態* を JSON で AWS 側に保持。オフライン中に変更されても、復帰時に同期される。

```json
{
  "state": {
    "desired": { "temperature": 22 },
    "reported": { "temperature": 21 },
    "delta": { "temperature": 22 }
  }
}
```

=== Rules Engine

デバイスから来る MQTT メッセージを SQL 風に *選択 → 加工 → ターゲット送信*。

```sql
SELECT *, topic(2) as device_id FROM 'iot/+/telemetry'
WHERE temperature > 30
```

ターゲット：Lambda、Kinesis、DynamoDB、S3、SNS、SQS、IoT Analytics、CloudWatch、再 publish など。

=== 料金感

- 接続：\$0.08/100万分（接続時間）
- メッセージング：\$1.00/100万メッセージ（5KBブロック）
- Device Shadow / Registry / Rules：別料金
- 数千デバイス規模なら月数十ドル〜

== IoT Device Management

- *Fleet Provisioning*：大量デバイスを安全にプロビジョニング
- *Jobs*：デバイス群への一斉指示（再起動、設定更新、ファーム更新 OTA）
- *Secure Tunneling*：NAT 越しにデバイスへ SSH 相当アクセス
- *Fleet Hub*：デバイス可視化ダッシュボード

== IoT Greengrass

エッジ実行環境。クラウドで開発したコンポーネントをデバイス上で動かす。

=== コア機能

- *Lambda 関数のローカル実行*
- *Docker コンテナの実行*
- *機械学習推論*（クラウドで訓練したモデルをエッジへデプロイ）
- *ローカル MQTT ブローカ*（オフライン中もデバイス間通信）
- *Stream Manager*（バッファリングしてオンライン時にクラウドへ送信）

工場・店舗・車両・建設現場など、ネットワーク不安定な環境で活躍。

=== Greengrass v2 のコンポーネント

宣言的に「このデバイスにはこれらのコンポーネント」と指定し、デプロイ。バージョン管理付き。

== IoT Analytics

IoT データの ETL + 分析。Kinesis + Glue で組むよりも IoT 特化で楽。

- *Channel*：生データ受け口
- *Pipeline*：フィルタ・変換
- *Datastore*：処理済みデータ
- *Dataset*：SQL クエリ結果

QuickSight で可視化、SageMaker で ML パイプラインに連携。

== IoT Events

複雑なイベント処理（CEP）。

- *Detector Model*：状態機械
- 例：「温度 > 50℃ が10分続いたら警告」「3つのセンサーが同時に異常なら緊急停止」

== IoT SiteWise

産業用設備（工場ライン、発電設備）のデータモデリング・収集に特化。OPC-UA、Modbus などのプロトコルから収集。階層的なアセットモデルでデータを構造化。

== IoT TwinMaker

物理空間の *デジタルツイン* を構築。3D シーン + リアルタイムデータ + AI 推論を統合。Grafana プラグインでダッシュボード化。

== FreeRTOS

組込み用 RTOS（リアルタイム OS）。Cortex-M、ESP32 等の MCU 向け。AWS と直接接続するためのライブラリ（IoT Device SDK）を含む。

== エッジコンピューティング

IoT を超えた、より広いエッジ系サービス。

=== AWS Outposts

*AWS のラックを自社データセンターに置く*。EC2 / EBS / S3 / RDS / EKS / ECS が *オンプレで動く*。低レイテンシ要件、データ主権、ネットワーク制約があるユースケースで。

- *Outposts ラック*：標準サーバラック型
- *Outposts サーバ*：1U / 2U の小型版

=== AWS Local Zones

主要都市内に AWS のミニリージョンを配置。リージョンより *さらに低レイテンシ*（数ms）。ゲーミング、メディア制作、リアルタイム ML 推論に。日本では現時点で Local Zones なし、東京リージョンを直接使う。

=== AWS Wavelength

5G キャリアのモバイルネットワーク内に AWS インフラを置く。モバイル端末から *キャリア網内で完結* したアクセスで超低レイテンシ。AR/VR、自動運転、ゲームストリーミング。

=== Snow ファミリー（エッジ視点）

Snowball Edge Compute Optimized は *現地で計算* もできる。砂漠・洋上・宇宙・戦地などの極端なエッジ環境で。

== メディアサービス群

動画配信・放送のユースケース向け。

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*サービス*], [*用途*]),
  [Elemental MediaConvert], [VOD（ファイルベース）動画変換],
  [Elemental MediaLive], [ライブ動画変換],
  [Elemental MediaPackage], [パッケージング（HLS / DASH / CMAF）+ DRM],
  [Elemental MediaTailor], [動的広告挿入（SSAI）],
  [Elemental MediaStore], [低レイテンシメディアオブジェクトストア（廃止予定、S3 へ移行推奨）],
  [Elemental MediaConnect], [プロフェッショナル放送用 IP トランスポート],
  [Elemental Link], [現地のエンコーダー機器（クラウド連携専用）],
  [Interactive Video Service（IVS）], [低レイテンシ・インタラクティブライブ配信],
  [Nimble Studio], [クラウドベースのコンテンツ制作スタジオ],
)

== MediaConvert（VOD トランスコード）

ファイルベースの動画変換。

=== 入力 / 出力

- 入力：ほぼ全ての主要フォーマット（MP4、MOV、MXF、TS、3GP、AVI、ProRes、MXF、IMF、MKV など）
- 出力：HLS、DASH、CMAF、Smooth Streaming、MP4、MOV、MXF など

=== 機能

- *マルチビットレート ABR*：1ジョブで複数解像度・複数ビットレートを生成
- *DRM*：DASH/HLS で Widevine / FairPlay / PlayReady
- *キャプション・字幕*：抽出・埋め込み・別ファイル出力
- *画像オーバーレイ*：ロゴ、ウォーターマーク
- *CMAF*：HLS と DASH を1ファイルセットでサポート

=== 料金

時間ベース（出力1秒ごと、コーデック・解像度で単価変動）。1時間の HD 動画を ABR 5 段で変換すると \$0.5〜\$2 程度。

== MediaLive（ライブトランスコード）

リアルタイム動画変換。

- 入力：RTMP、HLS、RTP、MediaConnect、ファイル
- 出力：MediaPackage、HLS、UDP/TS、RTMP、SRT、Frame Capture
- *Pipeline*：Standard（2系統冗長）/ Single Pipeline（コスト重視）
- *Resource Pool*：チャネル数の柔軟管理

ライブイベント、24時間放送、ニュース、スポーツ中継などで使用。

== MediaPackage

オリジン・パッケージング層。

- *MediaPackage v2*：CMAF ネイティブ、低レイテンシ HLS（LL-HLS）対応
- *DVR*（タイムシフト）：過去のライブを巻き戻し再生
- *Time-shifted Content*：開始時刻ずらし配信
- *Speke* で DRM 統合

== MediaTailor

動的広告挿入（SSAI: Server-Side Ad Insertion）。

- VAST/VMAP 広告サーバと連携
- 視聴者ごとに *別の広告* を挿入してパーソナライズ
- フリーケンシーキャップ、地域ターゲティング

== IVS（Interactive Video Service）

低レイテンシ（〜3秒）のライブ配信を *マネージドで*。ライブコマース、Q\&A、ゲーム配信、推し活ライブなど。チャット、Stages（多人数同時放送）も統合。

== 配信パイプラインの典型

=== VOD（YouTube ライク）

```
[アップロード] → S3 → MediaConvert → S3（HLS/DASH） → CloudFront → [視聴者]
                                                              ↑
                                                           DRM (Widevine)
```

=== ライブ（Twitch ライク）

```
[配信者 RTMP] → MediaLive → MediaPackage → CloudFront → [視聴者]
                       ↑
                   MediaTailor（広告挿入）
```

=== 低レイテンシライブ

```
[配信者] → IVS → IVS CDN → [視聴者]（LL-HLS、3秒以内）
```

== ゲーム関連

メディアと近いカテゴリで、ゲーム特化サービスもある。

- *GameLift*：ゲームサーバホスティング、マッチメイキング
- *GameLift Anywhere*：自社サーバ・他クラウドのゲームサーバを GameLift で管理
- *GameLift Streams*（旧 Lumberyard ベースの再構築）：クラウドゲーミング基盤

== コスト・運用の注意

- *MediaLive のチャネル時間課金*：使わないライブ中継チャネルは止める。アイドル中も課金される
- *MediaConvert の出力解像度・コーデック*：4K HEVC は高い、必要解像度に絞る
- *CloudFront のデータ転送*：動画は GB 単位の通信になる。地域単価を把握して料金見積
- *DRM ライセンス料*：別途ベンダ契約が発生する場合あり
- *IoT のメッセージ単価*：5KB ブロック課金。大きなペイロードは1メッセージで複数ブロック

== よくあるトラブル

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*症状*], [*対処*]),
  [IoT MQTT 接続できない], [証明書、ポリシー、エンドポイント名（リージョン違い）, 時刻同期],
  [Greengrass コンポーネント反映されない], [デプロイ Status、Recipe バージョン、ログ `/greengrass/v2/logs/`],
  [Device Shadow 反映遅い], [トピック権限、Delta 受信ロジック、Connection 維持],
  [MediaConvert ジョブ失敗], [入力フォーマット、コーデック対応、IAM ロール（S3 アクセス）],
  [MediaLive 配信が止まる], [入力 RTMP の安定性、Pipeline 冗長化、CloudWatch アラーム],
  [HLS が再生できない], [CORS、`m3u8` のパス、CloudFront キャッシュ TTL（短く）, ABR レンジ],
  [DRM 鍵取得失敗], [Speke エンドポイント、ライセンスサーバ疎通、コンテンツ ID マッピング],
  [IVS の遅延が大きい], [LL-HLS プレーヤー、配信ビットレート、視聴端末のバッファ設定],
)
