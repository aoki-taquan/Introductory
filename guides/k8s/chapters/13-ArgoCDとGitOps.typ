= ArgoCDとGitOps

== GitOpsとは

GitOpsは、Gitリポジトリをインフラとアプリケーションの信頼できる唯一の情報源（Single Source of Truth）として扱う運用手法です。Kubernetesクラスタの望ましい状態をGitで管理し、Gitへの変更が自動的にクラスタに反映されます。

=== GitOpsの原則

- *宣言的設定*: システムの望ましい状態を宣言的に記述する
- *Gitで管理*: すべての設定変更はGitを通じて行う
- *自動同期*: Gitの状態とクラスタの状態を自動的に一致させる
- *自動修復*: クラスタの状態がGitと異なる場合、自動的に修正する

=== 従来のCI/CDとGitOpsの違い

#table(
  columns: (1fr, 1.5fr, 1.5fr),
  align: (left, left, left),
  table.header(
    [*観点*], [*従来のCI/CD（Push型）*], [*GitOps（Pull型）*],
  ),
  [デプロイ方式], [CIパイプラインがクラスタにpush], [クラスタ側がGitからpull],
  [認証情報], [CI側にクラスタの認証情報が必要], [クラスタ内で完結],
  [状態管理], [デプロイ時点のみ把握], [継続的にGitと同期],
  [ドリフト検知], [手動で確認], [自動で検知・修正],
  [監査], [CIのログに依存], [Gitの履歴で完全に追跡可能],
)

== 主なGitOpsツール

#table(
  columns: (1fr, 2fr, 1fr),
  align: (left, left, left),
  table.header(
    [*ツール*], [*特徴*], [*開発元*],
  ),
  [Argo CD], [Web UI付き、豊富な機能、CNCFの卒業プロジェクト], [Intuit / CNCF],
  [Flux], [軽量、GitOps Toolkit ベース、CNCFの卒業プロジェクト], [Weaveworks / CNCF],
)

本章ではデファクトスタンダードとなっているArgo CDを中心に解説します。

== Argo CDとは

Argo CDは、Kubernetes用の宣言的なGitOps型継続的デリバリー（CD）ツールです。Gitリポジトリに格納されたマニフェストをKubernetesクラスタに自動的にデプロイします。

=== Argo CDの主な特徴

- *Web UI*: アプリケーションの状態をビジュアルに確認できる
- *マルチクラスタ対応*: 複数のクラスタを一元管理できる
- *SSO連携*: OIDC、OAuth2、LDAP、SAMLに対応
- *RBAC*: きめ細かいアクセス制御
- *Webhook対応*: GitHubなどからのWebhookで即座に同期できる
- *Helm / Kustomize対応*: 各種マニフェスト管理ツールと統合

== Argo CDのインストール

=== kubectlでインストール

```bash
# Namespaceの作成
kubectl create namespace argocd

# Argo CDのインストール
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Podが起動するまで待機
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s
```

=== Helmでインストール

```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm install argocd argo/argo-cd -n argocd --create-namespace
```

== Argo CD CLIのインストール

```bash
# macOS
brew install argocd

# Linux
curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x argocd
sudo mv argocd /usr/local/bin/
```

== Web UIへのアクセス

```bash
# ポートフォワーディング
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

ブラウザで `https://localhost:8080` にアクセスします。

=== 初期パスワードの取得

```bash
# 初期パスワードを取得
argocd admin initial-password -n argocd
```

ユーザー名は `admin` です。ログイン後はパスワードを変更してください。

```bash
# CLIでログイン
argocd login localhost:8080

# パスワード変更
argocd account update-password
```

== Applicationの作成

Argo CDでは「Application」リソースでGitリポジトリとクラスタの対応を定義します。

=== CLIで作成

```bash
argocd app create my-app \
  --repo https://github.com/your-org/your-repo.git \
  --path manifests \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace default \
  --sync-policy automated
```

=== マニフェストで作成

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/your-repo.git
    targetRevision: main
    path: manifests
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true         # Gitから削除されたリソースをクラスタからも削除
      selfHeal: true      # クラスタの手動変更を自動的に元に戻す
    syncOptions:
      - CreateNamespace=true
```

=== Helm Chartをソースにする場合

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: nginx
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://charts.bitnami.com/bitnami
    chart: nginx
    targetRevision: 15.0.0
    helm:
      values: |
        replicaCount: 3
        service:
          type: ClusterIP
  destination:
    server: https://kubernetes.default.svc
    namespace: web
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

=== Kustomizeをソースにする場合

```yaml
spec:
  source:
    repoURL: https://github.com/your-org/your-repo.git
    targetRevision: main
    path: overlays/production
    # Kustomize は自動的に検出される
```

== 同期（Sync）

=== 同期の状態

#table(
  columns: (1fr, 2fr),
  align: (left, left),
  table.header(
    [*状態*], [*説明*],
  ),
  [Synced], [Gitとクラスタの状態が一致している],
  [OutOfSync], [Gitとクラスタの状態が異なっている],
  [Unknown], [状態を判定できない],
)

=== 手動同期

```bash
# CLIで同期
argocd app sync my-app

# ドライラン（実際には適用しない）
argocd app sync my-app --dry-run
```

=== 自動同期の設定

```yaml
syncPolicy:
  automated:
    prune: true       # 不要なリソースを自動削除
    selfHeal: true    # 手動変更を自動修正
    allowEmpty: false  # すべてのリソースが削除される同期を防止
```

== Applicationの管理

```bash
# アプリケーション一覧
argocd app list

# アプリケーションの詳細
argocd app get my-app

# 同期差分の確認
argocd app diff my-app

# アプリケーションの削除
argocd app delete my-app

# ロールバック
argocd app rollback my-app <リビジョン番号>

# アプリケーションの履歴
argocd app history my-app
```

== ApplicationSetによる複数環境管理

ApplicationSetを使うと、1つのテンプレートから複数のApplicationを自動生成できます。

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: my-app-set
  namespace: argocd
spec:
  generators:
    - list:
        elements:
          - env: development
            namespace: dev
            revision: develop
          - env: staging
            namespace: staging
            revision: staging
          - env: production
            namespace: production
            revision: main
  template:
    metadata:
      name: "my-app-{{env}}"
    spec:
      project: default
      source:
        repoURL: https://github.com/your-org/your-repo.git
        targetRevision: "{{revision}}"
        path: overlays/{{env}}
      destination:
        server: https://kubernetes.default.svc
        namespace: "{{namespace}}"
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
```

== GitOpsのベストプラクティス

- *アプリケーションコードとマニフェストのリポジトリを分離する*: CIの変更がCDに意図せず影響するのを防ぐ
- *ブランチ戦略を明確にする*: 環境ごとのブランチまたはディレクトリ構造を統一する
- *Secretは暗号化して管理する*: Sealed SecretsやSOPS、External Secretsを使用する
- *PRベースのデプロイフローを導入する*: マニフェストの変更はPRレビューを通じて行う
- *通知を設定する*: Slackなどに同期結果を通知する

== Flux（補足）

FluxもCNCF卒業プロジェクトのGitOpsツールです。Argo CDとの主な違いは以下の通りです。

- Web UIが組み込まれていない（別途Weave GitOps UIなどを使用）
- GitOps Toolkitによるモジュラーアーキテクチャ
- Kustomize Controllerが組み込みで、Kustomizeとの親和性が高い
- Helm Controllerにより、HelmリリースもGitOps管理できる

```bash
# Fluxのインストール
flux install

# GitリポジトリとFluxの接続
flux create source git my-repo \
  --url=https://github.com/your-org/your-repo \
  --branch=main

# Kustomizationの作成
flux create kustomization my-app \
  --source=my-repo \
  --path="./overlays/production" \
  --prune=true
```
