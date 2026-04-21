= 機械学習と生成 AI

AWS の AI/ML スタックは「*既製 API*」「*ML プラットフォーム*」「*基盤モデル / インフラ*」の3層に分かれる。本章はこの順で扱い、最後に RAG・MLOps などの典型構成と費用上の注意をまとめる。

== AWS AI/ML スタックの3層

#table(
  columns: (1fr, 2fr, 1fr),
  align: left,
  table.header([*層*], [*提供形態*], [*主な利用者*]),
  [AI Services], [既製モデルを REST/SDK で呼ぶだけ], [アプリ開発者],
  [ML Services], [SageMaker：訓練・デプロイ・MLOps の総合], [データサイエンティスト],
  [ML Frameworks & Infra], [Trainium / Inferentia / GPU 等の専用チップ・EC2], [研究者・基盤チーム],
)

加えて *Amazon Bedrock*（基盤モデルの統合 API）と *Amazon Q*（生成 AI アシスタント）が独立した重要サービスとして位置づけられる。

== 既製 AI サービス

「ML を学ばずに AI 機能をアプリに足す」用途。API キー1つで使える。

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*サービス*], [*用途*]),
  [Rekognition], [画像・動画認識（顔・物体・テキスト・モデレーション）],
  [Transcribe], [音声 → テキスト（多言語、リアルタイム、医療・通話特化）],
  [Polly], [テキスト → 音声（Neural / 生成系 TTS）],
  [Translate], [機械翻訳（カスタム用語集、リアルタイム）],
  [Comprehend], [テキスト分析（言語・感情・エンティティ・キーフレーズ・PII）],
  [Comprehend Medical], [医療テキスト解析],
  [Textract], [文書 OCR + 表・フォーム抽出],
  [Personalize], [リアルタイムレコメンド],
  [Forecast], [時系列予測（2024/7 新規受付停止、既存は継続利用可。新規は SageMaker Canvas）],
  [Lex], [会話 Bot（Connect とも統合）],
  [Kendra], [エンタープライズ全文検索（SaaS コネクタ多数）],
  [Fraud Detector], [不正検知モデルの学習・推論],
)

すべて *リージョンに制約* がある。東京で利用可能か、データは越境していないかを必ず確認する。

=== 簡単な使用例（Rekognition）

```bash
aws rekognition detect-labels \
  --image '{"S3Object":{"Bucket":"my-images","Name":"sample.jpg"}}' \
  --max-labels 10
```

```python
import boto3
client = boto3.client('rekognition', region_name='ap-northeast-1')
resp = client.detect_text(Image={'S3Object':{'Bucket':'my-images','Name':'menu.jpg'}})
for d in resp['TextDetections']:
    print(d['DetectedText'])
```

== Amazon Bedrock

複数ベンダの *基盤モデル（Foundation Model, FM）* を *統一 API* で呼べるサーバーレス基盤。

=== 利用可能な主要モデル系列

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*ベンダー*], [*モデル系列*]),
  [Anthropic], [Claude Opus 4.7 / Sonnet 4.6 / Haiku 4.5（推奨）。指示追従と長文・コードに強い],
  [Amazon], [Nova（Premier/Pro/Lite/Micro）、Titan（テキスト・画像・埋め込み）],
  [Meta], [Llama 4 系、Llama 3 系。OSS 系の柔軟性],
  [Mistral], [Mistral Large、Mistral Small。欧州系],
  [Cohere], [Command / Embed],
  [Stability AI], [Stable Diffusion（画像生成）],
  [AI21 Labs], [Jamba],
)

*モデル提供状況とリージョンは頻繁に変わる*。コンソールの「Model access」で最新確認。

=== Bedrock の主要機能

==== Knowledge Bases（RAG）

S3 上のドキュメントを取り込み、自動チャンク化 → 埋め込み生成 → ベクトル DB（OpenSearch Serverless / Aurora pgvector / Pinecone / MongoDB Atlas）に格納し、*Retrieve and Generate API* で1コール RAG を実現。

```python
import boto3
br = boto3.client('bedrock-agent-runtime')
resp = br.retrieve_and_generate(
    input={'text': '弊社の有給休暇規定を教えて'},
    retrieveAndGenerateConfiguration={
        'type': 'KNOWLEDGE_BASE',
        'knowledgeBaseConfiguration': {
            'knowledgeBaseId': 'KB123456',
            # 新世代 Claude は cross-region inference profile 経由が必須のリージョンが多い
            'modelArn': 'arn:aws:bedrock:ap-northeast-1:123456789012:inference-profile/apac.anthropic.claude-sonnet-4-6-v1:0',
        }
    }
)
print(resp['output']['text'])
```

==== Agents

*ツール呼び出し*（Action Group）と *Knowledge Base* を組み合わせて、ReAct 風のエージェントを宣言的に作る。Lambda がツール実装、OpenAPI スキーマでツールを定義。

==== Guardrails

入出力に対して *安全性フィルタ* を適用。トピック禁止、PII マスキング、有害コンテンツ検出、プロンプトインジェクション対策。

==== Model Evaluation

複数モデル・複数プロンプトの自動評価。ヒューマン評価（自社ワーカー / AWS マネージドワーカー）と自動メトリクスの両方をサポート。

==== Prompt Management と Flows

プロンプトのバージョン管理（Prompt Management）と、複数モデル・複数プロンプト・複数ツールを *視覚的に組み合わせる* Flows。

==== Custom Model Import / Provisioned Throughput

- *Custom Model Import*：自社で用意したモデル（Llama 互換、Mistral 互換等）を Bedrock の API で呼べるようにインポート
- *Provisioned Throughput*：モデル容量を時間予約してスループットを保証。大量バッチ推論や SLA が必要な本番で

=== Bedrock の料金モデル

- *On-Demand*：トークン単位課金。少量・スパイク向け
- *Provisioned Throughput*：時間単位、モデル単位
- *バッチ推論*：On-Demand の50%程度

=== モデル選択の実践指針

- *軽量・高速・安価*：Claude Haiku、Nova Micro/Lite、Llama 系の小型
- *バランス*：Claude Sonnet、Nova Pro、Mistral Large
- *最高品質*：Claude Opus、Nova Premier
- *画像生成*：Stable Diffusion、Nova Canvas、Titan Image Generator
- *埋め込み*：Titan Embed、Cohere Embed

迷ったら *Claude Sonnet 系* がコストと品質のバランスが良い。

== Amazon Q

生成 AI を *エンドユーザー向けアシスタント* として提供する一連のサービス。

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*プロダクト*], [*用途*]),
  [Amazon Q Developer], [開発者向け。IDE、コンソール、CLI 連携。コード生成・診断・テスト生成・トランスフォーム],
  [Amazon Q Business], [社内ナレッジ統合チャット。100以上の SaaS コネクタ、RAG],
  [Amazon Q in QuickSight], [BI への自然言語問い合わせ・可視化生成],
  [Amazon Q in Connect], [コンタクトセンターのリアルタイムアシスト],
  [Amazon Q Apps], [社内向けノーコード生成 AI アプリ],
)

エンタープライズで「とにかく社内データに RAG したい」という需要には Bedrock を自前で組むより Q Business が早い。

== SageMaker

ML プラットフォーム。訓練・デプロイ・MLOps を統合。

=== コンポーネント早見表

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*機能*], [*用途*]),
  [Studio], [ML 開発の統合 IDE（JupyterLab + Code Editor）],
  [Notebooks], [マネージド Jupyter（Studio Notebooks 推奨）],
  [Training Jobs], [マネージド学習。分散・Spot・分散ハイパラ],
  [Hyperparameter Tuning], [自動ハイパーパラメータ探索],
  [Inference], [リアルタイム / Serverless / 非同期 / バッチ変換],
  [Endpoints], [マルチモデル、マルチコンテナ、シャドウ、Auto Scaling],
  [Pipelines], [MLOps の DAG（前処理→訓練→評価→登録→デプロイ）],
  [Model Registry], [モデルバージョン管理・承認フロー],
  [Feature Store], [オンライン／オフライン特徴量ストア],
  [Ground Truth], [データラベリング（人手・マネージドワーカー）],
  [Clarify], [バイアス検出・モデル説明可能性（SHAP）],
  [Model Monitor], [本番モデルのデータドリフト・モデルドリフト監視],
  [Canvas], [ノーコード ML（タブラ、時系列、画像）],
  [JumpStart], [事前学習モデル・ソリューションテンプレート],
  [HyperPod], [大規模分散学習向けのレジリエントなクラスタ],
  [Unified Studio], [SageMaker・Bedrock・Glue・EMR・Redshift を1つの UI に統合],
)

=== 最小ワークフロー

```python
import sagemaker
from sagemaker.sklearn.estimator import SKLearn

sess = sagemaker.Session()
role = sagemaker.get_execution_role()

est = SKLearn(
    entry_point='train.py',
    role=role,
    instance_type='ml.m5.large',
    framework_version='1.2-1',
    hyperparameters={'max_depth': 5, 'n_estimators': 100},
)
est.fit({'train': 's3://my-bucket/train.csv', 'val': 's3://my-bucket/val.csv'})

predictor = est.deploy(initial_instance_count=1, instance_type='ml.m5.large')
print(predictor.predict([[1.0, 2.0, 3.0]]))

# 後片付け（重要：エンドポイントは時間課金）
predictor.delete_endpoint()
```

=== 推論方式の使い分け

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*方式*], [*向く用途*]),
  [Real-time Endpoint], [低レイテンシ、定常トラフィック],
  [Serverless Inference], [スパイク・低頻度・ピーク不定],
  [Asynchronous Inference], [大きな入力・長い処理時間（最大1時間）],
  [Batch Transform], [大量データを一度に推論],
)

=== Pipelines + Model Registry

```python
from sagemaker.workflow.pipeline import Pipeline
from sagemaker.workflow.steps import ProcessingStep, TrainingStep
from sagemaker.workflow.step_collections import RegisterModel

pre = ProcessingStep(name='Preprocess', ...)
train = TrainingStep(name='Train', ...)
register = RegisterModel(name='Register', model_package_group_name='my-model', ...)

pipeline = Pipeline(name='ml-pipeline', steps=[pre, train, register])
pipeline.upsert(role_arn=role)
pipeline.start()
```

CodePipeline からこの SageMaker Pipeline を起動して、CI/CD と統合する。

=== Feature Store

オンライン（低レイテンシ KV）とオフライン（S3 + Glue Catalog）の二段構造。訓練と推論で *同じ特徴量* を保証することがゴール（訓練／推論スキューの防止）。

=== JumpStart

数百の事前学習モデル・ソリューションテンプレートをワンクリックでデプロイ。LLM のホスティング、画像分類、表形式分類、時系列、レコメンドなど。最近は *ファインチューニング機能* も統合され、Bedrock のカスタムモデルとの線引きが微妙になっている（JumpStart は SageMaker エンドポイントが自分のもの、Bedrock はマネージド API）。

=== HyperPod

大規模 LLM の分散訓練向け。ノード障害時の自動復旧、SLURM ベース、Trainium 統合。最先端モデルの研究開発で使われる。

== Trainium / Inferentia

AWS 独自の ML 専用チップ。

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*チップ*], [*用途*]),
  [Trainium 1（Trn1）], [大規模学習。GPU 比 50%安],
  [Trainium 2（Trn2）], [Trn1 の4倍性能。最大数万ノード分散],
  [Inferentia 1（Inf1）], [推論。低コスト],
  [Inferentia 2（Inf2）], [大規模 LLM 推論。Inf1 の数十倍性能],
)

利用には *AWS Neuron SDK*（PyTorch / TensorFlow / JAX 互換のコンパイラ）が必要。コスト重視の本番推論で導入する。

== ベクトル検索の選択肢

RAG で必須となるベクトル DB は AWS でもいくつか選べる。

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*選択肢*], [*特徴*]),
  [OpenSearch Service KNN], [既存ログ基盤と統合、フィルタ豊富],
  [OpenSearch Serverless（Vector Engine）], [Bedrock Knowledge Bases の標準],
  [Aurora PostgreSQL pgvector], [既存 RDBMS と一体管理、SQL JOIN 可],
  [DocumentDB ベクトル], [MongoDB 互換],
  [Neptune Analytics], [グラフ + ベクトル],
  [Kendra], [全文検索エンジン側で意味検索],
  [外部（Pinecone / Weaviate / MongoDB Atlas）], [PrivateLink 経由で利用可],
)

迷ったら *Bedrock Knowledge Bases + OpenSearch Serverless* が最短。RDBMS 中心なら pgvector。

== 典型的な構成

=== RAG（Retrieval-Augmented Generation）

```
[文書 S3] → Knowledge Base 取り込み → 埋め込み生成 → OpenSearch Serverless
[User] → API Gateway → Lambda → Bedrock RetrieveAndGenerate → Claude
                                                         ← 回答 + 引用
```

=== バッチ推論パイプライン

```
[新規データ S3] → EventBridge → SageMaker Batch Transform → 推論結果 S3
                                                       → SNS / Slack 通知
```

=== リアルタイム推論

```
[Client] → API Gateway → Lambda → SageMaker Real-time Endpoint → Result
                                ↓
                              Feature Store オンライン取得
```

=== MLOps（CI/CD）

```
[Git push] → CodePipeline →  ・コードビルド
                            ・ユニットテスト
                            ・SageMaker Pipelines（前処理→訓練→評価）
                            ・Model Registry に登録
                            ・人手承認
                            ・Endpoint デプロイ（カナリア）
```

=== カスタム LLM

- *軽い適応*：Bedrock の Provisioned + プロンプトエンジニアリング
- *中程度*：Bedrock Custom Model Import or SageMaker JumpStart の LoRA
- *重め*：SageMaker HyperPod + Trainium で Continued Pre-training

== コストとリスクのよくある罠

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*罠*], [*対策*]),
  [SageMaker Notebook の停止忘れ], [Lifecycle Configuration で自動シャットダウン、IDLE 検知],
  [Real-time Endpoint の放置], [使い終わったら必ず `delete_endpoint`、CloudWatch アラーム],
  [Bedrock のトークン爆発], [Guardrails、最大トークン制限、入力プロンプトの圧縮],
  [Bedrock の Provisioned 過剰], [On-Demand で性能と頻度を測ってから判断],
  [データ流出], [VPC エンドポイント、Bedrock 入出力ログ、Guardrails の PII マスキング],
  [モデルドリフト], [Model Monitor、定期評価バッチ],
  [プロンプトインジェクション], [Guardrails、システムプロンプトのサニタイズ、出力パース時の検証],
)

== 学び始めの推奨パス

+ *既製 AI* を1つ呼んでみる（Rekognition で画像認識、Translate で翻訳）
+ *Bedrock* で Claude を呼ぶ最小コード（boto3 で `invoke_model`）
+ Bedrock Knowledge Base で *社内ドキュメント RAG* を1本作る
+ SageMaker JumpStart で事前学習モデルを *エンドポイント化*
+ 必要に応じて SageMaker Pipelines で *MLOps* に踏み込む

最初から SageMaker フルスタックを組まなくてよい。多くのケースで *Bedrock + 既製 API + RAG* で要件が満たせる。
