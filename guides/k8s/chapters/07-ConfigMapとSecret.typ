= ConfigMapとSecret

== 設定管理の必要性

アプリケーションの設定をコンテナイメージに直接埋め込むと、環境ごとにイメージを作り直す必要があります。KubernetesではConfigMapとSecretを使って設定をコンテナから分離し、柔軟に管理できます。

== ConfigMap

ConfigMapは、機密性のない設定データをキー・バリューのペアで保存するリソースです。

=== ConfigMapの作成

==== マニフェストで作成

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  APP_ENV: "production"
  APP_DEBUG: "false"
  APP_LOG_LEVEL: "info"
```

```bash
kubectl apply -f app-config.yaml
```

==== コマンドで作成

```bash
# リテラル値から作成
kubectl create configmap app-config \
  --from-literal=APP_ENV=production \
  --from-literal=APP_DEBUG=false

# ファイルから作成
kubectl create configmap nginx-config --from-file=nginx.conf

# ディレクトリから作成
kubectl create configmap configs --from-file=./config-dir/
```

=== ConfigMapの確認

```bash
kubectl get configmaps
kubectl describe configmap app-config
```

=== ConfigMapの利用方法

==== 環境変数として利用

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-pod
spec:
  containers:
    - name: app
      image: my-app:1.0
      envFrom:
        - configMapRef:
            name: app-config
```

`envFrom` を使うと、ConfigMapの全エントリが環境変数として設定されます。

特定のキーだけを使う場合は以下のように記述します。

```yaml
env:
  - name: APP_ENVIRONMENT
    valueFrom:
      configMapKeyRef:
        name: app-config
        key: APP_ENV
```

==== ボリュームとしてマウント

設定ファイルをそのままマウントしたい場合に使用します。

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-pod
spec:
  containers:
    - name: app
      image: nginx:1.27
      volumeMounts:
        - name: config-volume
          mountPath: /etc/nginx/conf.d
  volumes:
    - name: config-volume
      configMap:
        name: nginx-config
```

== Secret

Secretは、パスワード、APIキー、証明書などの機密情報を保存するリソースです。Base64でエンコードされて保存されます。

=== Secretの種類

#table(
  columns: (1fr, 2fr),
  align: (left, left),
  table.header(
    [*種類*], [*用途*],
  ),
  [Opaque], [任意のデータ（デフォルト）],
  [kubernetes.io/dockerconfigjson], [Dockerレジストリの認証情報],
  [kubernetes.io/tls], [TLS証明書と秘密鍵],
  [kubernetes.io/basic-auth], [Basic認証の資格情報],
)

=== Secretの作成

==== マニフェストで作成

値はBase64でエンコードする必要があります。

```bash
echo -n 'mypassword' | base64
# bXlwYXNzd29yZA==
```

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-secret
type: Opaque
data:
  DB_PASSWORD: bXlwYXNzd29yZA==
  API_KEY: c2VjcmV0LWtleQ==
```

`stringData` フィールドを使うとBase64エンコードなしで記述できます。

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-secret
type: Opaque
stringData:
  DB_PASSWORD: "mypassword"
  API_KEY: "secret-key"
```

==== コマンドで作成

```bash
kubectl create secret generic app-secret \
  --from-literal=DB_PASSWORD=mypassword \
  --from-literal=API_KEY=secret-key
```

=== Secretの利用方法

==== 環境変数として利用

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-pod
spec:
  containers:
    - name: app
      image: my-app:1.0
      env:
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: app-secret
              key: DB_PASSWORD
```

==== ボリュームとしてマウント

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-pod
spec:
  containers:
    - name: app
      image: my-app:1.0
      volumeMounts:
        - name: secret-volume
          mountPath: /etc/secrets
          readOnly: true
  volumes:
    - name: secret-volume
      secret:
        secretName: app-secret
```

== Secretの注意点

- SecretのBase64エンコードは暗号化ではありません。誰でもデコードできます
- Secretをマニフェストに含める場合、Gitリポジトリにコミットしないよう注意してください
- 本番環境ではExternal SecretsやSealed Secretsなどのツールの導入を検討してください
- etcdの暗号化を有効にすることで、保存時のセキュリティを強化できます
