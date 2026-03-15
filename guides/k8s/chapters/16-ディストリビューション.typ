= Kubernetesディストリビューションとクラスタ構築

== ディストリビューションの全体像

Kubernetesはオープンソースプロジェクトとして公開されていますが、本番環境でクラスタを構築・運用するには様々な選択肢があります。素のKubernetesを自前で構築する方法から、追加機能が統合されたディストリビューション、クラウドのマネージドサービスまで、用途に応じて選択します。

#table(
  columns: (1.2fr, 1.5fr, 1fr, 1.2fr),
  align: (left, left, left, left),
  table.header(
    [*カテゴリ*], [*代表的なツール/サービス*], [*管理負荷*], [*推奨用途*],
  ),
  [クラスタ構築ツール], [kubeadm], [高], [学習・オンプレミス],
  [軽量ディストリビューション], [k3s, MicroK8s], [低〜中], [エッジ・小規模本番],
  [イミュータブルOS型], [Talos Linux], [低], [セキュリティ重視の本番],
  [エンタープライズ], [OpenShift, Rancher], [中], [大規模組織・本番],
  [マネージドサービス], [EKS, GKE, AKS], [低], [クラウド本番],
)

== kubeadm

=== kubeadmとは

kubeadmはKubernetes公式のクラスタ構築ツールです。Kubernetesのコアコンポーネントをベストプラクティスに沿ってブートストラップします。素のKubernetesを構築するための標準的な方法であり、Kubernetesの内部構造を学ぶのにも最適です。

=== 前提条件

- 2台以上のLinuxマシン（物理 or VM）
- 各ノード: 2CPU以上、2GB以上のメモリ
- コンテナランタイム（containerd推奨）
- ネットワーク接続（ノード間で通信可能）
- swap無効

=== コンテナランタイムのインストール

```bash
# containerdのインストール（Ubuntu）
sudo apt-get update
sudo apt-get install -y containerd

# 設定ファイルの生成
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml

# SystemdCgroupを有効にする
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd
```

=== kubeadm、kubelet、kubectlのインストール

```bash
# Kubernetes公式リポジトリの追加（Ubuntu）
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gpg

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | \
  sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /' | \
  sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
```

=== コントロールプレーンの初期化

```bash
# コントロールプレーンノードで実行
sudo kubeadm init --pod-network-cidr=10.244.0.0/16

# kubeconfigの設定
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

=== CNI（ネットワークプラグイン）のインストール

kubeadmで構築したクラスタにはCNIプラグインが必要です。

#table(
  columns: (1fr, 2fr),
  align: (left, left),
  table.header(
    [*CNIプラグイン*], [*特徴*],
  ),
  [Flannel], [シンプルで導入が容易、学習向け],
  [Calico], [NetworkPolicyサポート、本番実績豊富],
  [Cilium], [eBPFベース、高パフォーマンス、Observability機能],
  [Weave Net], [暗号化通信対応、セットアップが簡単],
)

```bash
# Calicoのインストール例
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/calico.yaml

# Flannelのインストール例
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
```

=== ワーカーノードの追加

`kubeadm init` の出力に含まれるコマンドをワーカーノードで実行します。

```bash
# ワーカーノードで実行
sudo kubeadm join <コントロールプレーンIP>:6443 \
  --token <トークン> \
  --discovery-token-ca-cert-hash sha256:<ハッシュ>
```

トークンが期限切れの場合は再生成できます。

```bash
# コントロールプレーンでトークンを再生成
kubeadm token create --print-join-command
```

=== クラスタのアップグレード

```bash
# kubeadmのアップグレード
sudo apt-get update
sudo apt-get install -y kubeadm=1.32.0-1.1

# アップグレードプランの確認
sudo kubeadm upgrade plan

# アップグレードの実行（コントロールプレーン）
sudo kubeadm upgrade apply v1.32.0

# kubeletのアップグレード
sudo apt-get install -y kubelet=1.32.0-1.1
sudo systemctl daemon-reload
sudo systemctl restart kubelet
```

=== kubeadmの特徴まとめ

- Kubernetes公式のクラスタ構築ツール
- 素のKubernetesを構築でき、カスタマイズの自由度が高い
- CNI、Ingress Controller、監視ツールなどを自分で選択・導入する必要がある
- クラスタの運用・アップグレードは手動で管理する
- CKA（Certified Kubernetes Administrator）試験でも使用される

== k3s（本番環境での使用）

第2章ではk3sをローカル開発ツールとして紹介しましたが、k3sは本番環境でも広く使われています。

=== k3sの本番向け構成

==== 高可用性（HA）クラスタ

k3sはサーバー（コントロールプレーン）を複数台構成にすることで高可用性を実現できます。

```bash
# 1台目のサーバー（埋め込みetcdで初期化）
curl -sfL https://get.k3s.io | sh -s - server \
  --cluster-init \
  --tls-san <ロードバランサーIP>

# 2台目以降のサーバー
curl -sfL https://get.k3s.io | sh -s - server \
  --server https://<1台目のIP>:6443 \
  --token <トークン> \
  --tls-san <ロードバランサーIP>

# ワーカーノードの追加
curl -sfL https://get.k3s.io | sh -s - agent \
  --server https://<ロードバランサーIP>:6443 \
  --token <トークン>
```

==== 外部データベースの使用

大規模環境ではetcdの代わりにMySQL、PostgreSQL、etcdクラスタを使用できます。

```bash
curl -sfL https://get.k3s.io | sh -s - server \
  --datastore-endpoint="postgres://user:pass@db-host:5432/k3s"
```

=== kubeadmとの比較

#table(
  columns: (1fr, 1.5fr, 1.5fr),
  align: (left, left, left),
  table.header(
    [*観点*], [*kubeadm*], [*k3s*],
  ),
  [バイナリサイズ], [大（複数コンポーネント）], [約70MB（単一バイナリ）],
  [セットアップ], [手順が多い], [ワンライナーで完了],
  [コンポーネント], [個別にインストール], [Traefik、CoreDNS等が組み込み],
  [データストア], [etcd], [SQLite / 外部DB / 埋め込みetcd],
  [リソース消費], [高], [低],
  [カスタマイズ性], [高], [中],
  [ARM対応], [限定的], [完全対応],
  [CNCF認定], [対象（バニラK8s）], [認定済み],
)

== Talos Linux

=== Talos Linuxとは

Talos LinuxはKubernetes専用に設計されたイミュータブル（不変）なLinuxディストリビューションです。SSHアクセスやシェルが存在せず、すべての操作をAPIを通じて行います。セキュリティと運用の自動化に特化しています。

=== Talosの特徴

- *イミュータブルOS*: ルートファイルシステムは読み取り専用で、改ざんを防止
- *SSHなし*: シェルアクセスが存在しないため、攻撃面が極めて小さい
- *API駆動*: すべての設定変更をgRPC APIで実施
- *宣言的設定*: YAMLの設定ファイルでOS・Kubernetesの状態を定義
- *自動アップデート*: OSとKubernetesを一体でアップグレード
- *最小構成*: 不要なパッケージやサービスが一切入っていない

=== talosctlのインストール

```bash
# macOS
brew install siderolabs/tap/talosctl

# Linux
curl -sL https://talos.dev/install | sh
```

=== クラスタの構成ファイル生成

```bash
# 設定ファイルの生成
talosctl gen config my-cluster https://<コントロールプレーンIP>:6443

# 以下のファイルが生成される
# controlplane.yaml  - コントロールプレーンの設定
# worker.yaml        - ワーカーノードの設定
# talosconfig        - talosctlの設定
```

=== ノードへの設定適用

```bash
# コントロールプレーンに設定を適用
talosctl apply-config --insecure \
  --nodes <ノードIP> \
  --file controlplane.yaml

# ワーカーノードに設定を適用
talosctl apply-config --insecure \
  --nodes <ノードIP> \
  --file worker.yaml
```

=== クラスタのブートストラップ

```bash
# talosctlの設定
export TALOSCONFIG="talosconfig"
talosctl config endpoint <コントロールプレーンIP>
talosctl config node <コントロールプレーンIP>

# クラスタのブートストラップ
talosctl bootstrap

# kubeconfigの取得
talosctl kubeconfig
```

=== 設定のカスタマイズ

Talosの設定はYAMLで宣言的に管理します。

```yaml
# controlplane.yaml（抜粋）
machine:
  type: controlplane
  network:
    hostname: cp-1
    interfaces:
      - interface: eth0
        dhcp: true
  install:
    disk: /dev/sda
    image: ghcr.io/siderolabs/installer:v1.8.0
cluster:
  clusterName: my-cluster
  controlPlane:
    endpoint: https://10.0.0.10:6443
  network:
    cni:
      name: flannel
```

=== クラスタの管理

```bash
# ノードの状態確認
talosctl get members

# サービスの状態確認
talosctl services

# ログの確認
talosctl logs kubelet

# OS のアップグレード
talosctl upgrade --image ghcr.io/siderolabs/installer:v1.9.0

# Kubernetesのアップグレード
talosctl upgrade-k8s --to 1.32.0

# 設定変更の適用
talosctl apply-config --nodes <ノードIP> --file controlplane.yaml
```

=== Talosのローカル開発環境

Docker上でTalosクラスタを試すこともできます。

```bash
# Docker上で3ノードクラスタを作成
talosctl cluster create --name my-cluster \
  --controlplanes 1 --workers 2

# 削除
talosctl cluster destroy --name my-cluster
```

== OpenShift

=== OpenShiftとは

OpenShift はRed Hatが開発・提供するエンタープライズ向けKubernetesプラットフォームです。Kubernetesをベースに、CI/CD、モニタリング、ログ、レジストリ、開発者ポータルなどが統合されています。

=== OpenShiftのエディション

#table(
  columns: (1fr, 2fr, 1fr),
  align: (left, left, left),
  table.header(
    [*エディション*], [*説明*], [*費用*],
  ),
  [OKD], [コミュニティ版（OpenShiftのアップストリーム）], [無料],
  [OpenShift Container Platform], [Red Hatのサブスクリプション付き商用版], [有料],
  [OpenShift Dedicated], [マネージドサービス（AWS / GCP上）], [有料],
  [ROSA], [AWS上のマネージドOpenShift], [有料],
  [ARO], [Azure上のマネージドOpenShift], [有料],
)

=== 標準Kubernetesとの主な違い

#table(
  columns: (1fr, 1.5fr, 1.5fr),
  align: (left, left, left),
  table.header(
    [*機能領域*], [*標準Kubernetes*], [*OpenShift*],
  ),
  [インストール], [kubeadm等で手動構築], [openshift-installで自動構築],
  [Web UI], [Dashboard（別途導入）], [高機能なWeb Console標準搭載],
  [CI/CD], [別途導入が必要], [OpenShift Pipelines（Tekton）統合],
  [イメージレジストリ], [別途導入が必要], [内蔵レジストリ],
  [ルーティング], [Ingress Controller別途導入], [Route/HAProxy標準搭載],
  [セキュリティ], [RBAC + PodSecurityStandards], [SCC（Security Context Constraints）],
  [モニタリング], [別途導入が必要], [Prometheus / Grafana統合済み],
  [ログ], [別途導入が必要], [OpenShift Logging（Loki）統合],
  [GitOps], [別途導入が必要], [OpenShift GitOps（ArgoCD）統合],
  [OS], [任意のLinux], [RHCOS / RHEL（イミュータブルOS）],
)

=== oc コマンド

OpenShiftでは `kubectl` に加えて `oc` コマンドが使用できます。`oc` は `kubectl` の上位互換で、OpenShift固有の機能にもアクセスできます。

```bash
# ログイン
oc login https://api.my-cluster.example.com:6443

# プロジェクト（Namespaceに相当）の作成
oc new-project my-project

# アプリケーションのデプロイ（ソースから自動ビルド）
oc new-app https://github.com/your-org/your-app.git

# ビルドの確認
oc get builds

# Routeの作成（外部公開）
oc expose service my-app

# Routeの確認
oc get routes
```

=== Route

OpenShiftにはIngress の代わりにRouteというリソースがあります（Ingressも使用可能）。

```yaml
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: my-app
spec:
  host: my-app.apps.my-cluster.example.com
  to:
    kind: Service
    name: my-app
  port:
    targetPort: 8080
  tls:
    termination: edge
```

=== Security Context Constraints（SCC）

OpenShiftはデフォルトでPodのセキュリティを厳しく制限しています。

```bash
# 利用可能なSCCを確認
oc get scc

# SCCの詳細を表示
oc describe scc restricted-v2
```

主なSCC:

- *restricted-v2*: デフォルト。root実行不可、特権コンテナ不可
- *anyuid*: 任意のUIDでの実行を許可
- *privileged*: すべての制限を解除（管理用途のみ）

=== ローカル開発環境（OKD / CRC）

OpenShiftをローカルで試すには、CodeReady Containers（CRC）を使用します。

```bash
# CRCのインストール（Red Hatアカウントが必要）
crc setup
crc start

# ocコマンドの設定
eval $(crc oc-env)
oc login -u developer -p developer https://api.crc.testing:6443
```

== マネージドKubernetesサービス

クラウドプロバイダーが提供するマネージドKubernetesサービスでは、コントロールプレーンの運用をプロバイダーが担当します。

#table(
  columns: (1fr, 1fr, 2fr),
  align: (left, left, left),
  table.header(
    [*サービス*], [*プロバイダー*], [*特徴*],
  ),
  [EKS], [AWS], [IAM統合、Fargateによるサーバーレスノード],
  [GKE], [Google Cloud], [Autopilotモード、高度なネットワーキング],
  [AKS], [Azure], [Azure AD統合、Azure Arc対応],
)

マネージドサービスはコントロールプレーンの運用が不要で、ノードのスケーリングやアップグレードも簡単です。本番環境ではマネージドサービスの利用が広く推奨されています。

=== CLI ツール

各マネージドサービスにはクラスタ管理用のCLIがあります。

```bash
# EKS（AWS）
eksctl create cluster --name my-cluster --region ap-northeast-1
aws eks update-kubeconfig --name my-cluster --region ap-northeast-1

# GKE（Google Cloud）
gcloud container clusters create my-cluster --zone asia-northeast1-a
gcloud container clusters get-credentials my-cluster --zone asia-northeast1-a

# AKS（Azure）
az aks create --resource-group myRG --name my-cluster
az aks get-credentials --resource-group myRG --name my-cluster
```

== ディストリビューションの選び方

#table(
  columns: (1fr, 2.5fr),
  align: (left, left),
  table.header(
    [*要件*], [*推奨*],
  ),
  [Kubernetesの内部を学びたい], [kubeadm（構築プロセスを理解できる）],
  [小規模・エッジ・IoT], [k3s（軽量、ARM対応、簡単セットアップ）],
  [セキュリティ最優先], [Talos Linux（イミュータブルOS、SSH不要）],
  [エンタープライズ・大規模組織], [OpenShift（統合ツール群、サポート付き）],
  [クラウドで手軽に本番運用], [EKS / GKE / AKS（マネージドで運用負荷が低い）],
  [クラウド非依存の本番環境], [kubeadm + Calico/Cilium または Talos],
)
