= インストール

== システム要件

AWXを動作させるための推奨スペックは以下の通りである。

#table(
  columns: (1fr, 1fr),
  align: left,
  table.header([*項目*], [*推奨値*]),
  [CPU], [4コア以上],
  [メモリ], [8GB以上],
  [ディスク], [40GB以上],
  [OS], [Ubuntu 22.04 / RHEL 9 / Rocky Linux 9 等],
  [Docker], [24.0以上（Docker Compose利用時）],
  [Kubernetes], [1.27以上（AWX Operator利用時）],
)

== インストール方法の選択

AWXのインストール方法は主に2つある。

#table(
  columns: (1fr, 1fr, 1fr),
  align: left,
  table.header([*方法*], [*特徴*], [*推奨ケース*]),
  [AWX Operator（Kubernetes）], [公式推奨。本番向き], [本番環境・チーム利用],
  [Docker Compose], [手軽に構築可能], [開発・検証・個人利用],
)

現在、AWXプロジェクトは *AWX Operator（Kubernetes）を公式推奨* としている。Docker Compose版は開発・検証向けに提供されている。

== AWX Operator（Kubernetes）でのインストール

=== 前提条件

- Kubernetes クラスタ（minikube、k3s、EKS等）が稼働していること
- `kubectl` がインストール・設定済みであること

=== Minikubeでの準備

検証環境としてMinikubeを使う場合の手順を示す。

```bash
# Minikubeのインストール（Ubuntu）
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# クラスタの起動
minikube start --cpus=4 --memory=8g --addons=ingress
```

=== AWX Operatorのデプロイ

```bash
# kustomize用のディレクトリを作成
mkdir -p awx-operator && cd awx-operator

# kustomization.yamlを作成
cat <<EOF > kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - github.com/ansible/awx-operator/config/default?ref=2.19.1
images:
  - name: quay.io/ansible/awx-operator
    newTag: 2.19.1
namespace: awx
EOF

# namespaceの作成とOperatorのデプロイ
kubectl create namespace awx
kubectl apply -k .
```

=== AWXインスタンスの作成

```yaml
# awx-instance.yaml
apiVersion: awx.ansible.com/v1beta1
kind: AWX
metadata:
  name: awx-demo
  namespace: awx
spec:
  service_type: NodePort
  nodeport_port: 30080
```

```bash
# kustomization.yamlにAWXインスタンスを追加
cat <<EOF >> kustomization.yaml
  - awx-instance.yaml
EOF

# デプロイ
kubectl apply -k .

# Podの状態を確認（全てRunningになるまで待機）
kubectl get pods -n awx -w
```

=== 管理者パスワードの取得

```bash
# 管理者パスワードの取得
kubectl get secret awx-demo-admin-password -n awx \
  -o jsonpath='{.data.password}' | base64 --decode; echo
```

ブラウザで `http://<ノードIP>:30080` にアクセスし、ユーザー名 `admin` と取得したパスワードでログインする。

== Docker Composeでのインストール

=== 前提条件

- Docker と Docker Compose がインストール済みであること
- Git がインストール済みであること

=== 手順

```bash
# AWXリポジトリのクローン
git clone -b x.y.z https://github.com/ansible/awx.git
cd awx

# Docker Compose用の設定
cd tools/docker-compose

# 環境変数の設定
cp .env.example .env

# コンテナの起動
docker compose up -d

# ログの確認
docker compose logs -f
```

=== 初期ユーザーの作成

```bash
# 管理者ユーザーの作成
docker compose exec awx-web awx-manage createsuperuser \
  --username admin --email admin@example.com
```

ブラウザで `http://localhost:8043` にアクセスしてログインする。

== インストール後の確認

インストールが完了したら、以下を確認する。

+ Web UIにログインできること
+ ダッシュボードが正常に表示されること
+ *設定 > システム* でライセンス情報やバージョンが確認できること
+ *設定 > ジョブ* でジョブ関連の設定が表示されること
