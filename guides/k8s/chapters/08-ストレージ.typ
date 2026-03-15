= ストレージ

== コンテナのストレージの課題

コンテナのファイルシステムは一時的なものです。コンテナが再起動されるとデータは失われます。データベースやファイルアップロードなど、永続的なデータ保存が必要な場合はKubernetesのストレージ機能を使用します。

== Volume

Volumeは、Pod内のコンテナ間でデータを共有したり、一時的なデータを保存するための仕組みです。PodのライフサイクルにVolume連動します。

=== emptyDir

Pod が作成されると空のディレクトリが作成され、Pod が削除されると消えます。同一Pod内のコンテナ間でデータを共有するために使用します。

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: shared-data-pod
spec:
  containers:
    - name: writer
      image: busybox:1.36
      command: ["sh", "-c", "echo 'Hello' > /data/message.txt && sleep 3600"]
      volumeMounts:
        - name: shared-data
          mountPath: /data
    - name: reader
      image: busybox:1.36
      command: ["sh", "-c", "cat /data/message.txt && sleep 3600"]
      volumeMounts:
        - name: shared-data
          mountPath: /data
  volumes:
    - name: shared-data
      emptyDir: {}
```

=== hostPath

ノードのファイルシステム上のパスをPodにマウントします。開発・テスト用途で使用しますが、本番環境での使用は推奨されません。

```yaml
volumes:
  - name: host-data
    hostPath:
      path: /data
      type: DirectoryOrCreate
```

== PersistentVolume（PV）と PersistentVolumeClaim（PVC）

永続的なストレージを使用するには、PersistentVolume（PV）と PersistentVolumeClaim（PVC）を使用します。

- *PV*: クラスタ管理者がプロビジョニングするストレージリソース
- *PVC*: ユーザーがストレージを要求するためのリソース

=== PVの作成

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: my-pv
spec:
  capacity:
    storage: 5Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  hostPath:
    path: /mnt/data
```

=== アクセスモード

#table(
  columns: (1fr, 1fr, 2fr),
  align: (left, left, left),
  table.header(
    [*モード*], [*略称*], [*説明*],
  ),
  [ReadWriteOnce], [RWO], [単一ノードからの読み書き],
  [ReadOnlyMany], [ROX], [複数ノードからの読み取り専用],
  [ReadWriteMany], [RWX], [複数ノードからの読み書き],
)

=== 再利用ポリシー

#table(
  columns: (1fr, 2fr),
  align: (left, left),
  table.header(
    [*ポリシー*], [*説明*],
  ),
  [Retain], [PVCが削除されてもPVとデータを保持する],
  [Delete], [PVCが削除されるとPVとデータも削除する],
  [Recycle], [データを削除してPVを再利用する（非推奨）],
)

=== PVCの作成

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 3Gi
```

PVCを作成すると、条件に合うPVが自動的にバインドされます。

=== PVCをPodで使用

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pvc-pod
spec:
  containers:
    - name: app
      image: nginx:1.27
      volumeMounts:
        - name: persistent-storage
          mountPath: /usr/share/nginx/html
  volumes:
    - name: persistent-storage
      persistentVolumeClaim:
        claimName: my-pvc
```

== StorageClass

StorageClassを使うと、PVCが作成されたときに動的にPVをプロビジョニングできます（動的プロビジョニング）。

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-storage
provisioner: k8s.io/minikube-hostpath
parameters:
  type: pd-ssd
reclaimPolicy: Delete
```

PVCでStorageClassを指定します。

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: dynamic-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: fast-storage
  resources:
    requests:
      storage: 10Gi
```

== ストレージの確認

```bash
# PVの確認
kubectl get pv

# PVCの確認
kubectl get pvc

# StorageClassの確認
kubectl get storageclass
```
