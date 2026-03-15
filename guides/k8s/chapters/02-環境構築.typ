= 環境構築

== ローカル開発環境の選択肢

Kubernetesをローカル環境で試すためのツールがいくつかあります。

#table(
  columns: (1fr, 1fr, 1fr, 1fr),
  align: (left, left, left, left),
  table.header(
    [*ツール*], [*特徴*], [*リソース消費*], [*推奨用途*],
  ),
  [Minikube], [最も一般的、豊富な機能], [中], [学習・開発],
  [kind], [Docker上で動作、軽量], [小], [CI/CD・テスト],
  [Docker Desktop], [GUI付き、簡単セットアップ], [大], [初心者向け],
  [k3d], [k3s をDocker上で実行], [小], [軽量環境],
)

本ガイドでは、最も広く使われているMinikubeを使用します。

== Minikubeのインストール

=== macOS

Homebrewを使ってインストールします。

```bash
brew install minikube
```

=== Linux

バイナリを直接ダウンロードしてインストールします。

```bash
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube
rm minikube-linux-amd64
```

=== Windows

WinGetを使ってインストールします。

```powershell
winget install Kubernetes.minikube
```

== kubectlのインストール

kubectlはKubernetesクラスタを操作するためのコマンドラインツールです。

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

== Minikubeクラスタの起動

=== クラスタの起動

```bash
minikube start
```

デフォルトではDockerドライバを使用してシングルノードのKubernetesクラスタが作成されます。

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

=== クラスタ情報の確認

```bash
kubectl cluster-info
```

== kubectlの基本操作

=== ノードの確認

```bash
kubectl get nodes
```

```
NAME       STATUS   ROLES           AGE   VERSION
minikube   Ready    control-plane   1m    v1.31.0
```

=== 全リソースの確認

```bash
kubectl get all
```

=== 名前空間の確認

```bash
kubectl get namespaces
```

== Minikubeの管理コマンド

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
)

== Minikubeダッシュボード

KubernetesにはWebベースのダッシュボードがあります。以下のコマンドで起動できます。

```bash
minikube dashboard
```

ダッシュボードではクラスタの状態をGUIで確認・管理できます。学習中はCLI（kubectl）とダッシュボードを併用すると理解が深まります。
