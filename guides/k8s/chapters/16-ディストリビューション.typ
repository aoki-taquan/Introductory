= Kubernetesディストリビューションとクラスタ構築

== ディストリビューションの全体像

Kubernetesはオープンソースプロジェクトとして公開されていますが、本番環境でクラスタを構築・運用するには様々な選択肢があります。素のKubernetesを自前で構築する方法から、追加機能が統合されたディストリビューション、クラウドのマネージドサービスまで、用途に応じて選択します。

#table(
  columns: (1.2fr, 2fr, 0.8fr, 1.2fr),
  align: (left, left, left, left),
  table.header(
    [*カテゴリ*], [*代表的なツール/サービス*], [*管理負荷*], [*推奨用途*],
  ),
  [公式構築ツール], [kubeadm, Kubespray], [高], [学習・オンプレミス],
  [宣言的プロビジョニング], [Cluster API], [中], [マルチクラスタ管理],
  [軽量ディストリビューション], [k3s, k0s, MicroK8s], [低〜中], [エッジ・小規模本番],
  [イミュータブルOS型], [Talos Linux], [低], [セキュリティ重視の本番],
  [エンタープライズ], [OpenShift, Rancher / RKE2, Tanzu, NKP], [中], [大規模組織・本番],
  [コンテナ最適化OS], [Bottlerocket, Flatcar], [低], [マネージドノード],
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

== Kubespray

=== Kubesprayとは

KubesprayはAnsibleベースのKubernetesクラスタ構築ツールです。kubeadmを内部で使用しながら、Ansibleのプレイブックで複数ノードのセットアップを自動化します。

=== 特徴

- Ansibleで構成管理するため、複数ノードの一括セットアップが容易
- kubeadmを内部で使用（kubeadm の自動化ラッパーとも言える）
- オンプレミス、クラウドVM、ベアメタルに対応
- CNI、コンテナランタイム、アドオンの選択をインベントリで設定可能
- HA構成のクラスタも自動構築できる

=== 基本的な使い方

```bash
# リポジトリのクローン
git clone https://github.com/kubernetes-sigs/kubespray.git
cd kubespray

# 依存関係のインストール
pip install -r requirements.txt

# インベントリの準備
cp -rfp inventory/sample inventory/my-cluster

# ノード情報を設定（IPアドレスを指定）
declare -a IPS=(10.0.0.1 10.0.0.2 10.0.0.3)
CONFIG_FILE=inventory/my-cluster/hosts.yaml \
  python3 contrib/inventory_builder/inventory.py ${IPS[@]}
```

=== インベントリのカスタマイズ

```yaml
# inventory/my-cluster/group_vars/k8s_cluster/k8s-cluster.yml
kube_version: v1.31.0
kube_network_plugin: calico     # CNIの選択
container_manager: containerd   # コンテナランタイム
cluster_name: my-cluster
```

=== クラスタの構築

```bash
# クラスタを構築
ansible-playbook -i inventory/my-cluster/hosts.yaml \
  --become --become-user=root \
  cluster.yml

# ノードの追加
ansible-playbook -i inventory/my-cluster/hosts.yaml \
  --become --become-user=root \
  scale.yml

# クラスタのアップグレード
ansible-playbook -i inventory/my-cluster/hosts.yaml \
  --become --become-user=root \
  upgrade-cluster.yml
```

=== kubeadmとの使い分け

- 数台規模なら kubeadm で手動構築でも問題ない
- 10台以上の大規模構成や繰り返しの構築にはKubesprayが効率的
- Infrastructure as Codeとしてクラスタ構成をGit管理したい場合にも有用

== Cluster API（CAPI）

=== Cluster APIとは

Cluster APIはKubernetesクラスタ自体をKubernetesリソースとして宣言的に管理するプロジェクトです。既存のKubernetesクラスタ（Management Cluster）から、新しいクラスタ（Workload Cluster）のライフサイクルを管理します。

=== コンセプト

```
Management Cluster（管理クラスタ）
  └── Cluster API コントローラー
        ├── Workload Cluster A
        ├── Workload Cluster B
        └── Workload Cluster C
```

- *Management Cluster*: Cluster APIのコントローラーが動作するクラスタ
- *Workload Cluster*: 実際にアプリケーションを動かすクラスタ
- *Infrastructure Provider*: クラスタが動作するインフラ（AWS, Azure, vSphere, Docker等）
- *Bootstrap Provider*: ノードの初期化方法（kubeadm, Talos, MicroK8s等）
- *Control Plane Provider*: コントロールプレーンの管理方法

=== 対応インフラプロバイダー

#table(
  columns: (1fr, 1fr, 1.5fr),
  align: (left, left, left),
  table.header(
    [*プロバイダー*], [*略称*], [*対応インフラ*],
  ),
  [CAPA], [AWS], [EC2, EKS],
  [CAPZ], [Azure], [Azure VM, AKS],
  [CAPG], [GCP], [GCE, GKE],
  [CAPV], [vSphere], [VMware vSphere],
  [CAPH], [Hetzner], [Hetzner Cloud / ベアメタル],
  [CAPD], [Docker], [ローカルDocker（開発用）],
  [CAPT], [Talos], [Talos Linux],
)

=== clusterctlのインストール

```bash
# macOS
brew install clusterctl

# Linux
curl -L https://github.com/kubernetes-sigs/cluster-api/releases/latest/download/clusterctl-linux-amd64 -o clusterctl
chmod +x clusterctl
sudo mv clusterctl /usr/local/bin/
```

=== Management Clusterの初期化

```bash
# AWSプロバイダーで初期化する例
export AWS_REGION=ap-northeast-1
export AWS_ACCESS_KEY_ID=<アクセスキー>
export AWS_SECRET_ACCESS_KEY=<シークレットキー>

clusterctl init --infrastructure aws
```

=== Workload Clusterの作成

```bash
# クラスタのマニフェストを生成
clusterctl generate cluster my-cluster \
  --infrastructure aws \
  --kubernetes-version v1.31.0 \
  --control-plane-machine-count 3 \
  --worker-machine-count 3 \
  > my-cluster.yaml

# マニフェストを適用してクラスタを作成
kubectl apply -f my-cluster.yaml

# クラスタの状態を確認
kubectl get clusters
clusterctl describe cluster my-cluster

# Workload Clusterのkubeconfigを取得
clusterctl get kubeconfig my-cluster > my-cluster-kubeconfig
```

=== Cluster APIのユースケース

- 複数のKubernetesクラスタを統一的に管理したい
- クラスタの作成・削除・アップグレードを自動化したい
- GitOpsでクラスタのライフサイクルを管理したい
- マルチクラウド・ハイブリッドクラウド環境を構築したい

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

== k0s

=== k0sとは

k0sはMirantis社が開発したゼロフリクション（摩擦ゼロ）を目指す軽量Kubernetesディストリビューションです。k3sと同様に単一バイナリで動作しますが、設計思想に違いがあります。

=== k0sの特徴

- *ゼロ依存*: ホストOSに追加パッケージが不要（コンテナランタイムも内蔵）
- *ゼロフリクション*: 標準的なKubernetes APIを100%維持（独自変更なし）
- *ゼロコスト*: 完全オープンソース（Apache 2.0ライセンス）
- *k0sctl*: SSHベースのクラスタ管理ツールで複数ノードを一括管理
- *自動アップグレード*: Autopilot機能によるクラスタの自動更新

=== k3sとの違い

#table(
  columns: (1fr, 1.5fr, 1.5fr),
  align: (left, left, left),
  table.header(
    [*観点*], [*k3s*], [*k0s*],
  ),
  [開発元], [SUSE / Rancher], [Mirantis],
  [組み込みコンポーネント], [Traefik, ServiceLB, Local Path Provisioner], [最小限（自分で選択）],
  [データストア], [SQLite / etcd / 外部DB], [SQLite / etcd / 外部DB],
  [コントロールプレーン分離], [サーバーもワークロード実行可], [コントローラーはワークロード非実行],
  [クラスタ管理], [CLI], [k0sctl（SSH経由の宣言的管理）],
  [自動アップグレード], [system-upgrade-controller], [Autopilot（組み込み）],
)

=== インストールと起動

```bash
# k0sのインストール
curl -sSLf https://get.k0s.sh | sh

# コントローラーとして起動（シングルノード）
sudo k0s install controller --single
sudo k0s start

# kubeconfigの取得
sudo k0s kubeconfig admin > ~/.kube/config
```

=== k0sctlによるマルチノード構成

k0sctlはSSH経由で複数ノードのクラスタを宣言的に管理するツールです。

```bash
# k0sctlのインストール
brew install k0sproject/tap/k0sctl
```

```yaml
# k0sctl.yaml
apiVersion: k0sctl.k0sproject.io/v1beta1
kind: Cluster
metadata:
  name: my-cluster
spec:
  hosts:
    - role: controller
      ssh:
        address: 10.0.0.1
        user: ubuntu
        keyPath: ~/.ssh/id_rsa
    - role: worker
      ssh:
        address: 10.0.0.2
        user: ubuntu
        keyPath: ~/.ssh/id_rsa
    - role: worker
      ssh:
        address: 10.0.0.3
        user: ubuntu
        keyPath: ~/.ssh/id_rsa
  k0s:
    version: "1.31.0+k0s.0"
```

```bash
# クラスタの構築
k0sctl apply --config k0sctl.yaml

# kubeconfigの取得
k0sctl kubeconfig --config k0sctl.yaml > ~/.kube/config

# クラスタのリセット
k0sctl reset --config k0sctl.yaml
```

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
- *セキュアブート対応*: UEFIセキュアブートをサポート
- *ディスク暗号化*: LUKS2によるデータパーティションの暗号化をサポート

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
  features:
    kubernetesTalosAPIAccess:
      enabled: true
      allowedRoles:
        - os:reader
      allowedKubernetesNamespaces:
        - kube-system
cluster:
  clusterName: my-cluster
  controlPlane:
    endpoint: https://10.0.0.10:6443
  network:
    cni:
      name: flannel
  proxy:
    disabled: true   # Cilium等を使う場合はkube-proxyを無効化
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

# 設定変更の適用（差分のみ適用される）
talosctl apply-config --nodes <ノードIP> --file controlplane.yaml

# ダッシュボード（ターミナルUI）
talosctl dashboard --nodes <ノードIP>
```

=== Talos のローカル開発環境

Docker上でTalosクラスタを試すこともできます。

```bash
# Docker上で3ノードクラスタを作成
talosctl cluster create --name my-cluster \
  --controlplanes 1 --workers 2

# 削除
talosctl cluster destroy --name my-cluster
```

=== Talos Factory / Image Factory

Talos Image Factoryを使うと、カスタムのシステム拡張（iscsi、NVIDIA GPUドライバ、ZFSなど）を含むインストールイメージを生成できます。

```bash
# schematiを使ってカスタムイメージを作成
cat <<EOF > extensions.yaml
customization:
  systemExtensions:
    officialExtensions:
      - siderolabs/iscsi-tools
      - siderolabs/util-linux-tools
EOF
```

=== Cluster APIとの連携

Talos は Cluster API のブートストラッププロバイダー（CABPT）とコントロールプレーンプロバイダー（CACPPT）を提供しており、Cluster APIを使ってTalosクラスタを宣言的に管理できます。

== RKE2 / Rancher

=== RKE2とは

RKE2（Rancher Kubernetes Engine 2）はSUSE/Rancher社が開発するセキュリティ重視のKubernetesディストリビューションです。CIS（Center for Internet Security）ベンチマークにデフォルトで準拠しており、米国政府機関でも採用されています。

=== RKE2の特徴

- *CISハードニング*: デフォルトでCIS Kubernetesベンチマークに準拠
- *FIPS 140-2対応*: 暗号化モジュールの政府認証に対応
- *containerd組み込み*: Dockerへの依存なし
- *etcd組み込み*: 外部etcd不要
- *NGINX Ingress Controller*: 組み込み済み（k3sのTraefikとは異なる）
- *Canal CNI*: Flannel + Calicoの組み合わせをデフォルトで使用

=== インストール

```bash
# サーバー（コントロールプレーン）のインストール
curl -sfL https://get.rke2.io | sh -
sudo systemctl enable rke2-server
sudo systemctl start rke2-server

# kubeconfigの設定
mkdir -p ~/.kube
sudo cp /etc/rancher/rke2/rke2.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config

# トークンの確認
sudo cat /var/lib/rancher/rke2/server/node-token
```

```bash
# エージェント（ワーカーノード）のインストール
curl -sfL https://get.rke2.io | INSTALL_RKE2_TYPE="agent" sh -

# サーバー情報の設定
sudo mkdir -p /etc/rancher/rke2
cat <<EOF | sudo tee /etc/rancher/rke2/config.yaml
server: https://<サーバーIP>:9345
token: <トークン>
EOF

sudo systemctl enable rke2-agent
sudo systemctl start rke2-agent
```

=== RKE2の設定

```yaml
# /etc/rancher/rke2/config.yaml（サーバー）
write-kubeconfig-mode: "0644"
tls-san:
  - my-cluster.example.com
  - 10.0.0.10
cni: cilium            # CNIの変更（デフォルトはcanal）
disable:
  - rke2-ingress-nginx  # 組み込みIngressを無効化する場合
```

=== Rancher

RancherはKubernetesクラスタを統合管理するためのWeb UIプラットフォームです。RKE2で構築したクラスタだけでなく、EKS、GKE、AKS、k3sなど様々なクラスタを一元管理できます。

```bash
# Helmでインストール
helm repo add rancher-latest https://releases.rancher.com/server-charts/latest
helm repo update

kubectl create namespace cattle-system

helm install rancher rancher-latest/rancher \
  --namespace cattle-system \
  --set hostname=rancher.example.com \
  --set replicas=3
```

Rancherの主な機能:

- *マルチクラスタ管理*: 複数のK8sクラスタをWebUIで一元管理
- *ユーザー管理*: LDAP、AD、GitHub、OIDC連携
- *アプリケーションカタログ*: Helmチャートの管理とデプロイ
- *クラスタプロビジョニング*: RKE2/k3sクラスタの作成をGUIで実行
- *監視・アラート*: Prometheus/Grafanaの統合管理

=== k3s / RKE2 / kubeadm の比較

#table(
  columns: (1fr, 1fr, 1fr, 1fr),
  align: (left, left, left, left),
  table.header(
    [*観点*], [*kubeadm*], [*k3s*], [*RKE2*],
  ),
  [開発元], [Kubernetes公式], [SUSE / Rancher], [SUSE / Rancher],
  [想定用途], [汎用], [エッジ・軽量], [セキュリティ重視の本番],
  [CISハードニング], [手動], [手動], [デフォルト準拠],
  [FIPS対応], [なし], [なし], [あり],
  [リソース消費], [高], [低], [中],
  [組み込みIngress], [なし], [Traefik], [NGINX],
  [データストア], [etcd], [SQLite/etcd/外部DB], [etcd],
  [管理UI], [なし], [なし], [Rancher連携],
)

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
  [サービスメッシュ], [別途導入が必要], [OpenShift Service Mesh（Istio）統合],
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

== VMware Tanzu Kubernetes Grid

=== Tanzuとは

VMware Tanzu Kubernetes Grid（TKG）はBroadcom（旧VMware）が提供するエンタープライズ向けKubernetesプラットフォームです。vSphere環境との統合が強力で、VMwareの既存インフラを活用したKubernetes運用ができます。

=== Tanzuの主な製品

#table(
  columns: (1.2fr, 2.5fr),
  align: (left, left),
  table.header(
    [*製品*], [*説明*],
  ),
  [TKG（Tanzu Kubernetes Grid）], [マルチクラスタ管理、vSphere/AWS/Azure対応],
  [TKGs（vSphere with Tanzu）], [vSphereに統合されたKubernetes（Supervisor Cluster）],
  [TCE（Tanzu Community Edition）], [コミュニティ版（現在はアーカイブ）],
)

=== 特徴

- vSphere環境でVMと同じ管理フレームワークでKubernetesを運用
- Cluster APIを内部で使用しクラスタをプロビジョニング
- NSX-Tとの連携による高度なネットワーキング
- Harbor（コンテナレジストリ）との統合

== Nutanix Kubernetes Platform（NKP）

=== NKPとは

NKP（Nutanix Kubernetes Platform、旧 NKE / Nutanix Karbon）はNutanix社が提供するエンタープライズ向けKubernetesプラットフォームです。NutanixのHCI（ハイパーコンバージドインフラストラクチャ）上でKubernetesクラスタを統合管理できます。

=== NKPの変遷

#table(
  columns: (1fr, 1fr, 2fr),
  align: (left, left, left),
  table.header(
    [*名称*], [*時期*], [*説明*],
  ),
  [Karbon], [初期], [Nutanix上のK8sクラスタ管理機能],
  [NKE（Nutanix Kubernetes Engine）], [中期], [Karbonの後継、機能拡充],
  [NKP（Nutanix Kubernetes Platform）], [現在], [D2iQ Kubernetes Platform（DKP）の技術を統合],
)

=== NKPの特徴

- *Nutanix HCI統合*: Nutanixの統合管理プラットフォーム（Prism）からK8sクラスタを管理
- *D2iQ技術の統合*: 2023年のD2iQ買収によりDKP（旧Konvoy）の技術を取り込み
- *Cluster API ベース*: クラスタのライフサイクルをCluster APIで宣言的に管理
- *マルチクラスタ管理*: Nutanix上だけでなくAWS、Azure等のクラスタも一元管理
- *統合プラットフォーム*: 監視（Prometheus/Grafana）、ログ（Loki）、Ingress、GitOps等がバンドル
- *エアギャップ対応*: インターネット接続がない閉域環境でのデプロイをサポート

=== Tanzuとの比較

#table(
  columns: (1fr, 1.5fr, 1.5fr),
  align: (left, left, left),
  table.header(
    [*観点*], [*Tanzu (TKG)*], [*NKP*],
  ),
  [基盤], [VMware vSphere], [Nutanix AHV / HCI],
  [クラスタ管理], [Cluster API], [Cluster API（DKP由来）],
  [管理UI], [vCenter統合], [Prism Central統合],
  [ネットワーク], [NSX-T連携], [Nutanix Flow / AHV統合],
  [ストレージ], [vSAN連携], [Nutanix Volumes / Files CSI],
  [マルチクラウド], [vSphere / AWS / Azure], [Nutanix / AWS / Azure],
  [エアギャップ], [対応], [対応（DKP由来の強み）],
)

=== NKPの管理

NKPはPrism Central（Nutanixの管理UI）またはCLI（nkp コマンド）で操作します。

```bash
# NKPクラスタの作成（CLIの場合）
nkp create cluster nutanix \
  --cluster-name my-cluster \
  --control-plane-endpoint-host 10.0.0.100 \
  --control-plane-prism-element-cluster <PE名> \
  --control-plane-subnets <サブネット名> \
  --control-plane-replicas 3 \
  --worker-replicas 5

# kubeconfigの取得
nkp get kubeconfig -c my-cluster > my-cluster.kubeconfig
```

=== ユースケース

- Nutanix HCIを既に導入している企業でのK8s運用
- VMwareからの移行先としてNutanix + NKPを選択するケース
- エアギャップ（閉域網）環境でのK8s運用が必要な場合

== コンテナ最適化OS

Kubernetesノード用に最適化された軽量OSが存在します。汎用Linuxディストリビューション（Ubuntu、RHEL等）の代わりに使用することで、セキュリティの向上と運用の簡素化が実現できます。

=== Bottlerocket

BottlerocketはAWSが開発したコンテナ実行専用のLinuxディストリビューションです。

- *AWS製*: EKS、ECS との統合が最適化されている
- *イミュータブル*: ルートファイルシステムは読み取り専用
- *API駆動*: 設定変更はAPIまたはuser-data経由
- *A/Bアップデート*: パーティションの切り替えによる安全なOSアップデート
- *最小構成*: パッケージマネージャー、シェルアクセスなし（管理用コンテナ経由で可能）

```bash
# EKSでBottlerocketノードグループを作成
eksctl create nodegroup \
  --cluster my-cluster \
  --node-ami-family Bottlerocket \
  --name bottlerocket-ng
```

=== Flatcar Container Linux

Flatcar Container LinuxはCoreOS Container Linux（現在はRed Hat傘下）の後継として、Kinvolkが開発を引き継いだコンテナ最適化OSです。

- *CoreOSの後継*: Container Linuxの互換性を維持
- *自動アップデート*: Nebraska アップデートサーバーによるA/Bアップデート
- *Ignition*: 初回起動時の宣言的設定（cloud-initの代替）
- *クラウド非依存*: AWS、GCP、Azure、ベアメタルすべてに対応
- *sysext*: systemd-sysextによるカスタムソフトウェアの追加

```yaml
# Ignition設定の例（Butane形式で記述してIgnitionに変換）
variant: flatcar
version: 1.0.0
storage:
  files:
    - path: /etc/hostname
      contents:
        inline: worker-1
systemd:
  units:
    - name: containerd.service
      enabled: true
```

=== コンテナ最適化OSの比較

#table(
  columns: (1fr, 1fr, 1fr, 1fr),
  align: (left, left, left, left),
  table.header(
    [*観点*], [*Talos Linux*], [*Bottlerocket*], [*Flatcar*],
  ),
  [開発元], [Sidero Labs], [AWS], [Kinvolk / Microsoft],
  [用途], [K8sノードOS + 構築], [K8sノードOS], [K8sノードOS],
  [K8s構築機能], [あり（OS自体がK8sを管理）], [なし（EKS等と併用）], [なし（kubeadm等と併用）],
  [SSH], [なし], [管理コンテナ経由], [あり],
  [クラウド対応], [全般], [AWS中心], [全般],
  [設定方式], [YAML（talosctl）], [TOML（API）], [Ignition],
)

== マネージドKubernetesサービス

クラウドプロバイダーが提供するマネージドKubernetesサービスでは、コントロールプレーンの運用をプロバイダーが担当します。

#table(
  columns: (1fr, 1fr, 2fr),
  align: (left, left, left),
  table.header(
    [*サービス*], [*プロバイダー*], [*特徴*],
  ),
  [EKS], [AWS], [IAM統合、Fargateによるサーバーレスノード、Bottlerocket対応],
  [GKE], [Google Cloud], [Autopilotモード、高度なネットワーキング、Kubernetesの本家],
  [AKS], [Azure], [Azure AD統合、Azure Arc対応、Windowsノード対応],
  [LKE], [Linode / Akamai], [シンプルで低コスト、小〜中規模向け],
  [DOKS], [DigitalOcean], [シンプルなUI、小規模プロジェクト向け],
  [OKE], [Oracle Cloud], [Always Free枠あり、Oracle DB統合],
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
  columns: (1.2fr, 2.5fr),
  align: (left, left),
  table.header(
    [*要件*], [*推奨*],
  ),
  [Kubernetesの内部を学びたい], [kubeadm（構築プロセスを理解できる）],
  [大規模オンプレミスの自動構築], [Kubespray（Ansibleで自動化）],
  [クラスタ自体をK8sで管理したい], [Cluster API（宣言的なマルチクラスタ管理）],
  [小規模・エッジ・IoT], [k3s（軽量、ARM対応、簡単セットアップ）],
  [標準準拠の軽量K8s], [k0s（ゼロ依存、標準API 100%維持）],
  [セキュリティ最優先], [Talos Linux（イミュータブルOS、SSH不要）],
  [政府・金融機関向け], [RKE2（CISデフォルト準拠、FIPS対応）],
  [エンタープライズ（Red Hat統合）], [OpenShift（統合ツール群、サポート付き）],
  [エンタープライズ（VMware統合）], [Tanzu（vSphere連携、NSX-T統合）],
  [エンタープライズ（Nutanix統合）], [NKP（Prism連携、エアギャップ対応）],
  [マルチクラスタのWeb管理], [Rancher（あらゆるK8sクラスタを一元管理）],
  [クラウドで手軽に本番運用], [EKS / GKE / AKS（マネージドで運用負荷が低い）],
  [クラウド非依存の本番環境], [Talos + Cilium または RKE2],
)
