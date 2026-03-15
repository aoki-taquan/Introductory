= 環境構築

== ローカル開発環境の選択肢

Kubernetesをローカル環境で試すためのツールがいくつかあります。

#table(
  columns: (1fr, 1.5fr, 0.7fr, 1fr),
  align: (left, left, left, left),
  table.header(
    [*ツール*], [*特徴*], [*リソース消費*], [*推奨用途*],
  ),
  [Minikube], [最も一般的、豊富なアドオン], [中], [学習・開発],
  [kind], [Docker上でマルチノード構成が可能], [小], [CI/CD・テスト],
  [k3d], [k3sをDocker上で実行、高速起動], [小], [軽量開発・CI],
  [k3s], [軽量K8sディストリビューション], [極小], [エッジ・IoT・本番],
  [MicroK8s], [Snap経由で簡単インストール], [小], [Ubuntu環境],
  [Docker Desktop], [GUI付き、ワンクリック有効化], [大], [初心者向け],
)

== kubectlのインストール

kubectlはKubernetesクラスタを操作するためのコマンドラインツールです。どのローカル環境ツールを使う場合でも必要です。

=== macOS

```bash
brew install kubectl
```

=== Linux

```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install kubectl /usr/local/bin/kubectl
rm kubectl
```

=== Windows

```powershell
winget install Kubernetes.kubectl
```

=== インストール確認

```bash
kubectl version --client
```

== Minikube

Minikubeは最も広く使われているローカルKubernetes環境です。豊富なアドオン（dashboard、metrics-server、ingressなど）を簡単に有効化できます。

=== インストール

```bash
# macOS
brew install minikube

# Linux
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube
rm minikube-linux-amd64

# Windows
winget install Kubernetes.minikube
```

=== クラスタの起動

```bash
minikube start
```

リソースをカスタマイズする場合は以下のように指定します。

```bash
minikube start --cpus=4 --memory=8192 --driver=docker
```

=== クラスタの状態確認

```bash
minikube status
```

以下のような出力が表示されれば正常です。

```
minikube
type: Control Plane
host: Running
kubelet: Running
apiserver: Running
kubeconfig: Configured
```

=== 管理コマンド

#table(
  columns: (1fr, 2fr),
  align: (left, left),
  table.header(
    [*コマンド*], [*説明*],
  ),
  [`minikube start`], [クラスタを起動する],
  [`minikube stop`], [クラスタを停止する（データは保持）],
  [`minikube delete`], [クラスタを削除する],
  [`minikube dashboard`], [Web UIダッシュボードを開く],
  [`minikube ssh`], [Minikubeノードにssh接続する],
  [`minikube tunnel`], [LoadBalancerサービスにアクセス可能にする],
  [`minikube addons list`], [利用可能なアドオンを一覧表示する],
  [`minikube addons enable <名前>`], [アドオンを有効にする],
)

=== ダッシュボード

```bash
minikube dashboard
```

ダッシュボードではクラスタの状態をGUIで確認・管理できます。

== kind（Kubernetes IN Docker）

kindはDockerコンテナをノードとして使用するツールです。マルチノードクラスタの構築が容易で、CI/CD環境に適しています。

=== インストール

```bash
# macOS / Linux
brew install kind

# Go がインストール済みの場合
go install sigs.k8s.io/kind@latest
```

=== クラスタの作成

```bash
# シンプルなクラスタ作成
kind create cluster

# 名前を指定して作成
kind create cluster --name my-cluster
```

=== マルチノードクラスタ

設定ファイルを使ってマルチノード構成を作成できます。

```yaml
# kind-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
  - role: worker
  - role: worker
```

```bash
kind create cluster --config kind-config.yaml
```

=== ローカルイメージの読み込み

kindではローカルにビルドしたDockerイメージを直接クラスタに読み込めます。

```bash
docker build -t my-app:latest .
kind load docker-image my-app:latest
```

=== 管理コマンド

```bash
# クラスタ一覧
kind get clusters

# クラスタの削除
kind delete cluster --name my-cluster

# kubeconfigのエクスポート
kind get kubeconfig --name my-cluster
```

== k3d（k3s in Docker）

k3dはRancher社が開発した軽量Kubernetesディストリビューションk3sをDocker上で実行するツールです。起動が非常に高速で、ローカルレジストリとの連携も簡単です。

=== インストール

```bash
# macOS / Linux
brew install k3d

# インストールスクリプト
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
```

=== クラスタの作成

```bash
# シンプルなクラスタ作成
k3d cluster create my-cluster

# ポートマッピング付きで作成
k3d cluster create my-cluster -p "8080:80@loadbalancer"

# マルチノード
k3d cluster create my-cluster --servers 1 --agents 3
```

=== ローカルレジストリとの連携

k3dではローカルレジストリを簡単に構築できます。

```bash
# レジストリ付きクラスタを作成
k3d cluster create my-cluster --registry-create my-registry:5000

# イメージをプッシュ
docker tag my-app:latest localhost:5000/my-app:latest
docker push localhost:5000/my-app:latest
```

=== 管理コマンド

```bash
# クラスタ一覧
k3d cluster list

# クラスタの停止・再開
k3d cluster stop my-cluster
k3d cluster start my-cluster

# クラスタの削除
k3d cluster delete my-cluster
```

== k3s

k3sはRancher社が開発した軽量Kubernetesディストリビューションです。バイナリ1つで動作し、ARM対応でエッジコンピューティングやIoT環境にも適しています。本番環境でも利用されています。

=== インストール

```bash
# サーバー（コントロールプレーン）のインストール
curl -sfL https://get.k3s.io | sh -

# ワーカーノードの追加
curl -sfL https://get.k3s.io | K3S_URL=https://<サーバーIP>:6443 \
  K3S_TOKEN=<トークン> sh -
```

サーバーのトークンは以下で確認できます。

```bash
sudo cat /var/lib/rancher/k3s/server/node-token
```

=== k3sの特徴

- バイナリサイズが約70MBと軽量
- SQLite、MySQL、PostgreSQL、etcdをデータストアとして選択可能
- Traefik（Ingress Controller）とServiceLB（旧Klipper）が組み込み済み
- containerdを内蔵（Dockerは不要）
- CNCFの認定Kubernetesディストリビューション

=== kubectlの使用

k3sではkubectlが組み込まれています。

```bash
# k3s経由でkubectlを使用
sudo k3s kubectl get nodes

# 通常のkubectlを使用する場合はkubeconfigをコピー
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config
kubectl get nodes
```

== MicroK8s

MicroK8sはCanonical社が開発したSnapパッケージで配布されるKubernetesディストリビューションです。Ubuntu環境で特に便利です。

=== インストール

```bash
# Ubuntu / Snap対応Linux
sudo snap install microk8s --classic

# ユーザーをmicrok8sグループに追加
sudo usermod -a -G microk8s $USER
newgrp microk8s
```

=== アドオンの有効化

MicroK8sはアドオン方式で機能を追加します。

```bash
# よく使うアドオンを一括有効化
microk8s enable dns dashboard storage ingress

# アドオンの一覧
microk8s status
```

=== 管理コマンド

```bash
# 状態確認
microk8s status

# 起動・停止
microk8s start
microk8s stop

# kubectl（microk8s経由）
microk8s kubectl get nodes

# 通常のkubectlを使う場合
microk8s config > ~/.kube/config
```

== Docker Desktop

Docker DesktopにはKubernetesが組み込まれており、設定画面からワンクリックで有効化できます。

=== 有効化の手順

+ Docker Desktopを起動する
+ Settings（設定）を開く
+ 「Kubernetes」タブを選択する
+ 「Enable Kubernetes」にチェックを入れる
+ 「Apply & Restart」をクリックする

=== コンテキストの切り替え

Docker Desktopと他のKubernetes環境を併用する場合、コンテキストを切り替えます。

```bash
# 利用可能なコンテキストを一覧表示
kubectl config get-contexts

# Docker Desktop のコンテキストに切り替え
kubectl config use-context docker-desktop
```

== ツールの選び方

#table(
  columns: (1fr, 2.5fr),
  align: (left, left),
  table.header(
    [*用途*], [*推奨ツール*],
  ),
  [Kubernetesの学習], [Minikube（豊富なアドオンとドキュメント）],
  [CI/CDでのテスト], [kind または k3d（軽量で高速起動）],
  [マルチノード検証], [kind または k3d（設定ファイルで柔軟に構成）],
  [エッジ / IoT], [k3s（超軽量、ARM対応）],
  [Ubuntu環境での開発], [MicroK8s（Snap で簡単管理）],
  [GUI重視・初心者], [Docker Desktop（ワンクリック有効化）],
  [本番に近い環境のテスト], [k3s または kubeadm],
)

== kubectlの基本操作

どのツールを選んでも、kubectlの操作は共通です。

=== ノードの確認

```bash
kubectl get nodes
```

=== 全リソースの確認

```bash
kubectl get all
```

=== 名前空間の確認

```bash
kubectl get namespaces
```

=== コンテキストの管理

複数のクラスタを使い分ける場合、kubectlのコンテキストを切り替えます。

```bash
# コンテキスト一覧
kubectl config get-contexts

# コンテキスト切り替え
kubectl config use-context <コンテキスト名>

# 現在のコンテキストを確認
kubectl config current-context
```
