= Service

== Serviceとは

Serviceは、Podへの安定したネットワークアクセスを提供するリソースです。Podは起動するたびにIPアドレスが変わりますが、Serviceを使うことで固定のエンドポイントを通じてPodにアクセスできます。

Serviceはラベルセレクタを使って対象のPodを動的に選択し、トラフィックをロードバランシングします。

== Serviceの種類

#table(
  columns: (1fr, 2fr, 1fr),
  align: (left, left, left),
  table.header(
    [*種類*], [*説明*], [*用途*],
  ),
  [ClusterIP], [クラスタ内部のみでアクセス可能な仮想IPを割り当てる], [内部通信],
  [NodePort], [各ノードのポートを通じて外部からアクセス可能にする], [開発・テスト],
  [LoadBalancer], [外部ロードバランサーを使って公開する], [本番環境],
  [ExternalName], [外部のDNS名にマッピングする], [外部サービス連携],
)

== ClusterIP Service

クラスタ内部でのみアクセスできるServiceです。デフォルトのService種類です。

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  type: ClusterIP
  selector:
    app: nginx
  ports:
    - protocol: TCP
      port: 80          # Serviceのポート
      targetPort: 80    # Podのポート
```

```bash
kubectl apply -f nginx-service.yaml
```

=== 確認

```bash
kubectl get services
```

```
NAME            TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)   AGE
nginx-service   ClusterIP   10.96.42.123   <none>        80/TCP    30s
```

=== クラスタ内からのアクセス

クラスタ内のPodからServiceにアクセスするには、Service名をホスト名として使用します。

```bash
# 一時的なPodからcurlでアクセス
kubectl run curl-test --image=curlimages/curl --rm -it -- curl http://nginx-service
```

== NodePort Service

各ノードの指定されたポートを通じて外部からアクセスできるServiceです。

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-nodeport
spec:
  type: NodePort
  selector:
    app: nginx
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
      nodePort: 30080    # ノードのポート（30000-32767）
```

NodePortは30000〜32767の範囲で指定できます。省略するとランダムに割り当てられます。

=== Minikubeでのアクセス

```bash
minikube service nginx-nodeport --url
```

== LoadBalancer Service

クラウド環境（AWS、GCP、Azureなど）で外部ロードバランサーを自動的にプロビジョニングするServiceです。

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-loadbalancer
spec:
  type: LoadBalancer
  selector:
    app: nginx
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
```

Minikubeで使用する場合は、別のターミナルで `minikube tunnel` を実行する必要があります。

```bash
# 別のターミナルで実行
minikube tunnel
```

== DNS によるサービスディスカバリ

Kubernetesクラスタ内ではDNSが自動的に設定されます。以下の形式でServiceにアクセスできます。

```
<Service名>.<Namespace>.svc.cluster.local
```

同じNamespace内であればService名だけでアクセスできます。

```bash
# 同じNamespace内
curl http://nginx-service

# 別のNamespaceのServiceにアクセス
curl http://nginx-service.default.svc.cluster.local
```

== 複数ポートの公開

1つのServiceで複数のポートを公開できます。

```yaml
apiVersion: v1
kind: Service
metadata:
  name: multi-port-service
spec:
  selector:
    app: my-app
  ports:
    - name: http
      protocol: TCP
      port: 80
      targetPort: 8080
    - name: https
      protocol: TCP
      port: 443
      targetPort: 8443
```

複数ポートを定義する場合は、各ポートに `name` を指定する必要があります。

== Headless Service

ClusterIPを割り当てず、DNSでPodのIPアドレスを直接返すServiceです。StatefulSetと組み合わせて使用されます。

```yaml
apiVersion: v1
kind: Service
metadata:
  name: headless-service
spec:
  clusterIP: None
  selector:
    app: my-app
  ports:
    - port: 80
      targetPort: 80
```

== Serviceの確認と削除

```bash
# Serviceの一覧
kubectl get services

# Serviceの詳細（エンドポイント情報を含む）
kubectl describe service nginx-service

# エンドポイントの確認
kubectl get endpoints nginx-service

# 削除
kubectl delete service nginx-service
```
