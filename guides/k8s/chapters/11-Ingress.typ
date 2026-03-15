= Ingress

== Ingressとは

Ingressは、クラスタ外部からのHTTP/HTTPSトラフィックをクラスタ内のServiceにルーティングするリソースです。Serviceの `NodePort` や `LoadBalancer` と異なり、URLパスベースやホスト名ベースのルーティング、TLS終端などの高度な機能を提供します。

== Ingress Controller

Ingressリソースを定義しただけではルーティングは機能しません。実際にトラフィックを処理するIngress Controllerが必要です。

=== 主なIngress Controller

#table(
  columns: (1fr, 2fr, 1fr),
  align: (left, left, left),
  table.header(
    [*名前*], [*特徴*], [*開発元*],
  ),
  [NGINX Ingress Controller], [最も広く使われている、安定した実績], [Kubernetes公式],
  [Traefik], [自動設定、Let's Encrypt対応、k3sに組み込み], [Traefik Labs],
  [HAProxy Ingress], [高パフォーマンス、詳細な設定が可能], [HAProxy],
  [Istio Gateway], [サービスメッシュと統合したルーティング], [Istio],
  [Contour], [Envoyベース、HTTPProxyカスタムリソース], [VMware],
  [AWS ALB Ingress Controller], [AWS Application Load Balancerと統合], [AWS],
)

=== NGINX Ingress Controllerのインストール

Minikubeの場合はアドオンで簡単に有効化できます。

```bash
minikube addons enable ingress
```

Helmを使ってインストールする場合は以下の通りです。

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install ingress-nginx ingress-nginx/ingress-nginx
```

== 基本的なIngressの定義

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-ingress
spec:
  ingressClassName: nginx
  rules:
    - host: myapp.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-service
                port:
                  number: 80
```

```bash
kubectl apply -f my-ingress.yaml
```

== パスベースのルーティング

1つのホスト名で複数のServiceにルーティングできます。

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: path-based-ingress
spec:
  ingressClassName: nginx
  rules:
    - host: myapp.example.com
      http:
        paths:
          - path: /api
            pathType: Prefix
            backend:
              service:
                name: api-service
                port:
                  number: 8080
          - path: /
            pathType: Prefix
            backend:
              service:
                name: frontend-service
                port:
                  number: 80
```

=== pathType

#table(
  columns: (1fr, 2fr),
  align: (left, left),
  table.header(
    [*pathType*], [*説明*],
  ),
  [Prefix], [URLパスのプレフィックスでマッチする（`/api` は `/api/users` にもマッチ）],
  [Exact], [URLパスが完全に一致する場合のみマッチする],
  [ImplementationSpecific], [Ingress Controllerの実装に依存する],
)

== ホスト名ベースのルーティング

異なるホスト名で異なるServiceにルーティングできます。

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: host-based-ingress
spec:
  ingressClassName: nginx
  rules:
    - host: app.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: app-service
                port:
                  number: 80
    - host: api.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: api-service
                port:
                  number: 8080
```

== TLS終端

IngressでTLS（HTTPS）を終端できます。

=== TLS用Secretの作成

```bash
kubectl create secret tls my-tls-secret \
  --cert=tls.crt \
  --key=tls.key
```

=== Ingressの設定

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: tls-ingress
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - myapp.example.com
      secretName: my-tls-secret
  rules:
    - host: myapp.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-service
                port:
                  number: 80
```

== cert-managerによる自動TLS証明書管理

cert-managerを使うと、Let's Encryptなどの認証局から自動的にTLS証明書を取得・更新できます。

=== cert-managerのインストール

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/latest/download/cert-manager.yaml
```

=== ClusterIssuerの作成

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod-key
    solvers:
      - http01:
          ingress:
            class: nginx
```

=== Ingressでのアノテーション

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: auto-tls-ingress
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - myapp.example.com
      secretName: myapp-tls
  rules:
    - host: myapp.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-service
                port:
                  number: 80
```

== NGINX Ingressのアノテーション

NGINX Ingress Controllerでは、アノテーションを使って細かい設定ができます。

```yaml
metadata:
  annotations:
    # リダイレクト
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    # リクエストサイズ制限
    nginx.ingress.kubernetes.io/proxy-body-size: "10m"
    # タイムアウト設定
    nginx.ingress.kubernetes.io/proxy-read-timeout: "60"
    # CORS設定
    nginx.ingress.kubernetes.io/enable-cors: "true"
    # レート制限
    nginx.ingress.kubernetes.io/limit-rps: "10"
```

== Ingressの確認

```bash
# Ingressの一覧
kubectl get ingress

# 詳細情報
kubectl describe ingress my-ingress

# Ingress Controllerのログ
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx
```
