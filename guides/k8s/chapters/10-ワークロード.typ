= その他のワークロードリソース

第4章でPod、第5章でDeploymentを解説しました。本章ではKubernetesが提供するその他のワークロードリソースを解説します。

== DaemonSet

=== DaemonSetとは

DaemonSetは、クラスタの全ノード（または特定のノード）に1つずつPodを配置するリソースです。ノードが追加されると自動的にPodが配置され、ノードが削除されるとPodも削除されます。

=== 用途

- ログ収集エージェント（Fluentd、Promtail等）
- モニタリングエージェント（Node Exporter等）
- ネットワークプラグイン（Calico、Cilium等）
- ストレージデーモン

=== DaemonSetの定義

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: log-collector
  labels:
    app: log-collector
spec:
  selector:
    matchLabels:
      app: log-collector
  template:
    metadata:
      labels:
        app: log-collector
    spec:
      containers:
        - name: fluentd
          image: fluentd:v1.17
          resources:
            requests:
              cpu: "100m"
              memory: "200Mi"
            limits:
              cpu: "200m"
              memory: "400Mi"
          volumeMounts:
            - name: varlog
              mountPath: /var/log
      volumes:
        - name: varlog
          hostPath:
            path: /var/log
```

```bash
kubectl apply -f log-collector.yaml
```

=== 状態確認

```bash
kubectl get daemonsets
```

```
NAME            DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   AGE
log-collector   3         3         3       3            3           30s
```

- *DESIRED*: 配置すべきノード数
- *CURRENT*: 作成済みのPod数
- *READY*: 準備完了のPod数

=== 特定のノードにのみ配置

`nodeSelector` や `affinity` を使って、特定のノードにのみDaemonSetのPodを配置できます。

```yaml
spec:
  template:
    spec:
      nodeSelector:
        monitoring: "true"
```

```bash
# ノードにラベルを付与
kubectl label nodes worker-1 monitoring=true
```

== StatefulSet

=== StatefulSetとは

StatefulSetは、ステートフル（状態を持つ）なアプリケーション向けのワークロードリソースです。Deploymentとは異なり、各Podに固定のIDとストレージを割り当てます。

=== Deploymentとの違い

#table(
  columns: (1fr, 1.5fr, 1.5fr),
  align: (left, left, left),
  table.header(
    [*観点*], [*Deployment*], [*StatefulSet*],
  ),
  [Pod名], [ランダムなサフィックス（`app-7d4f5b`）], [連番（`app-0`, `app-1`, `app-2`）],
  [起動順序], [同時に起動], [番号順に1つずつ起動],
  [停止順序], [同時に停止], [逆順に1つずつ停止],
  [ストレージ], [Pod間で共有 or 一時的], [各Podに専用のPVC],
  [ネットワーク], [ランダムなIP], [Headless Serviceで固定のDNS名],
)

=== 用途

- データベース（MySQL、PostgreSQL、MongoDB）
- 分散ストレージ（Cassandra、Ceph）
- メッセージキュー（Kafka、RabbitMQ）
- 分散キャッシュ（Redis Cluster）

=== StatefulSetの定義

StatefulSetには Headless Service が必要です。

```yaml
# Headless Service
apiVersion: v1
kind: Service
metadata:
  name: mysql
spec:
  clusterIP: None
  selector:
    app: mysql
  ports:
    - port: 3306
---
# StatefulSet
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mysql
spec:
  serviceName: mysql        # Headless Service名（必須）
  replicas: 3
  selector:
    matchLabels:
      app: mysql
  template:
    metadata:
      labels:
        app: mysql
    spec:
      containers:
        - name: mysql
          image: mysql:8.0
          ports:
            - containerPort: 3306
          env:
            - name: MYSQL_ROOT_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: mysql-secret
                  key: password
          volumeMounts:
            - name: data
              mountPath: /var/lib/mysql
  volumeClaimTemplates:       # 各Podに専用のPVCを作成
    - metadata:
        name: data
      spec:
        accessModes: ["ReadWriteOnce"]
        resources:
          requests:
            storage: 10Gi
```

=== 固定のDNS名

StatefulSetの各Podには以下の形式でDNSが割り当てられます。

```
<Pod名>.<Service名>.<Namespace>.svc.cluster.local
```

例:
- `mysql-0.mysql.default.svc.cluster.local`
- `mysql-1.mysql.default.svc.cluster.local`
- `mysql-2.mysql.default.svc.cluster.local`

=== 状態確認

```bash
kubectl get statefulsets
kubectl get pods -l app=mysql
```

```
NAME      READY   AGE
mysql-0   1/1     60s
mysql-1   1/1     45s
mysql-2   1/1     30s
```

Pod名に連番が付与されていることが確認できます。

=== スケーリング

```bash
kubectl scale statefulset mysql --replicas=5
```

スケールアップ時は番号順（`mysql-3`, `mysql-4`）に作成され、スケールダウン時は逆順（`mysql-4`, `mysql-3`）に削除されます。

=== 注意点

- StatefulSetを削除してもPVCは自動的に削除されません（データ保護のため）
- PVCを削除する場合は手動で行う必要があります

```bash
kubectl delete statefulset mysql
kubectl delete pvc -l app=mysql   # PVCも削除する場合
```

== Job

=== Jobとは

Jobは、1回限りのタスク（バッチ処理）を実行するリソースです。タスクが正常に完了するとPodは終了し、再起動されません。失敗した場合は設定に応じてリトライされます。

=== 用途

- データベースのマイグレーション
- バッチデータ処理
- レポート生成
- 一時的なメンテナンスタスク

=== Jobの定義

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: data-migration
spec:
  template:
    spec:
      containers:
        - name: migration
          image: my-app:1.0
          command: ["python", "migrate.py"]
      restartPolicy: Never    # Job では Never または OnFailure
  backoffLimit: 3             # 失敗時のリトライ回数
  activeDeadlineSeconds: 600  # タイムアウト（秒）
```

```bash
kubectl apply -f data-migration.yaml
```

=== 状態確認

```bash
kubectl get jobs
```

```
NAME              COMPLETIONS   DURATION   AGE
data-migration    1/1           15s        30s
```

- *COMPLETIONS*: 完了数 / 必要数
- *DURATION*: 実行にかかった時間

=== 並列実行

複数のPodを並列に実行して処理を高速化できます。

```yaml
spec:
  completions: 10      # 合計10回完了させる
  parallelism: 3       # 同時に3つのPodを実行
  template:
    spec:
      containers:
        - name: worker
          image: my-worker:1.0
      restartPolicy: Never
```

=== 完了したJobの確認

```bash
# Jobのログを確認
kubectl logs job/data-migration

# 完了したJobの削除
kubectl delete job data-migration
```

=== TTL（自動削除）

完了したJobを自動的に削除するには `ttlSecondsAfterFinished` を設定します。

```yaml
spec:
  ttlSecondsAfterFinished: 3600   # 完了後1時間で自動削除
```

== CronJob

=== CronJobとは

CronJobは、スケジュールに従って定期的にJobを実行するリソースです。Linux の cron と同様の記法でスケジュールを指定します。

=== 用途

- 定期的なバックアップ
- レポートの自動生成
- データのクリーンアップ
- ヘルスチェック

=== CronJobの定義

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: daily-backup
spec:
  schedule: "0 2 * * *"        # 毎日2:00に実行
  jobTemplate:
    spec:
      template:
        spec:
          containers:
            - name: backup
              image: my-backup:1.0
              command: ["sh", "-c", "pg_dump mydb > /backup/dump.sql"]
          restartPolicy: OnFailure
  successfulJobsHistoryLimit: 3   # 成功したJobの保持数
  failedJobsHistoryLimit: 1       # 失敗したJobの保持数
  concurrencyPolicy: Forbid       # 前のJobが終わるまで次を実行しない
```

=== スケジュール記法

```
┌───────────── 分 (0 - 59)
│ ┌───────────── 時 (0 - 23)
│ │ ┌───────────── 日 (1 - 31)
│ │ │ ┌───────────── 月 (1 - 12)
│ │ │ │ ┌───────────── 曜日 (0 - 6、0=日曜)
│ │ │ │ │
* * * * *
```

#table(
  columns: (1fr, 2fr),
  align: (left, left),
  table.header(
    [*スケジュール*], [*説明*],
  ),
  [`*/5 * * * *`], [5分ごと],
  [`0 * * * *`], [毎時0分],
  [`0 2 * * *`], [毎日2:00],
  [`0 0 * * 0`], [毎週日曜0:00],
  [`0 0 1 * *`], [毎月1日0:00],
)

=== concurrencyPolicy

#table(
  columns: (1fr, 2fr),
  align: (left, left),
  table.header(
    [*ポリシー*], [*説明*],
  ),
  [Allow], [並行実行を許可する（デフォルト）],
  [Forbid], [前のJobが実行中なら新しいJobをスキップする],
  [Replace], [前のJobを中断して新しいJobを実行する],
)

=== 状態確認

```bash
# CronJobの確認
kubectl get cronjobs

# CronJobから生成されたJobの確認
kubectl get jobs --sort-by=.metadata.creationTimestamp

# 手動でJobをトリガー
kubectl create job --from=cronjob/daily-backup manual-backup
```
