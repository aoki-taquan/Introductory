= 運用Tips

AWXを安定して運用するためのヒントやトラブルシューティングをまとめる。

== バックアップとリストア

=== AWX Operator環境

AWX Operatorでは、`AWXBackup` リソースを作成することでバックアップを取得できる。

```yaml
# awx-backup.yaml
apiVersion: awx.ansible.com/v1beta1
kind: AWXBackup
metadata:
  name: awx-backup-20260315
  namespace: awx
spec:
  deployment_name: awx-demo
  backup_pvc_namespace: awx
```

```bash
# バックアップの実行
kubectl apply -f awx-backup.yaml

# バックアップ状態の確認
kubectl get awxbackup -n awx
```

=== リストア

```yaml
# awx-restore.yaml
apiVersion: awx.ansible.com/v1beta1
kind: AWXRestore
metadata:
  name: awx-restore
  namespace: awx
spec:
  deployment_name: awx-demo
  backup_name: awx-backup-20260315
```

```bash
kubectl apply -f awx-restore.yaml
```

== アップグレード

=== AWX Operatorのアップグレード

+ `kustomization.yaml` のバージョンタグを更新
+ `kubectl apply -k .` で適用
+ Podが再作成されるのを確認

```bash
# kustomization.yamlのバージョンを更新後
kubectl apply -k .

# Podの再起動を監視
kubectl get pods -n awx -w
```

アップグレード前には必ずバックアップを取得すること。

== パフォーマンスチューニング

=== ジョブの同時実行数

AWXの設定で、同時に実行できるジョブの最大数を調整できる。

- *設定 > ジョブ > 最大同時ジョブ数*：ノードあたりの同時実行数
- フォーク数の合計がサーバーリソースを超えないよう注意

=== データベースの最適化

長期間運用すると、ジョブの実行履歴やイベントデータが蓄積される。定期的なクリーンアップが必要である。

```bash
# 古いジョブデータの削除（AWX管理コマンド）
awx-manage cleanup_jobs --days=90

# 古いアクティビティストリームの削除
awx-manage cleanup_activitystream --days=180
```

*設定 > ジョブ* の「ジョブ実行データの保持日数」でも自動クリーンアップを設定できる。

=== リソース割り当て

Kubernetes環境では、AWXのPodに十分なリソースを割り当てる。

```yaml
# AWXインスタンスのリソース設定例
apiVersion: awx.ansible.com/v1beta1
kind: AWX
metadata:
  name: awx-demo
  namespace: awx
spec:
  web_resource_requirements:
    requests:
      cpu: "500m"
      memory: "1Gi"
    limits:
      cpu: "2000m"
      memory: "4Gi"
  task_resource_requirements:
    requests:
      cpu: "500m"
      memory: "1Gi"
    limits:
      cpu: "2000m"
      memory: "4Gi"
```

== 通知テンプレート

ジョブの結果を外部サービスに通知する設定である。

=== 通知タイプ

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*タイプ*], [*説明*]),
  [Email], [メール通知],
  [Slack], [Slackチャンネルへの通知],
  [Webhook], [任意のURLへHTTPリクエスト],
  [PagerDuty], [PagerDutyへのインシデント通知],
  [Grafana], [Grafanaのアノテーション],
  [IRC], [IRCチャンネルへの通知],
  [Mattermost], [Mattermostへの通知],
  [Rocket.Chat], [Rocket.Chatへの通知],
)

=== Slack通知の設定例

+ *管理 > 通知テンプレート* から *追加* をクリック
+ タイプに *Slack* を選択
+ *Webhook URL*：Slack Incoming WebhookのURL
+ *チャンネル*：通知先チャンネル（例：`#ansible-alerts`）
+ *通知をテスト* で送信テスト

=== 通知の関連付け

通知テンプレートをジョブテンプレートやワークフローに関連付ける。

+ ジョブテンプレートの *通知* タブを開く
+ 通知テンプレートを選択
+ トリガー条件を設定（開始時 / 成功時 / 失敗時）

== トラブルシューティング

=== よくある問題と対処

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*問題*], [*対処*]),
  [プロジェクト同期が失敗する], [SCM URLと認証情報を確認。ネットワーク疎通をテスト],
  [ジョブが`Pending`のまま], [実行ノードの状態を確認。同時実行数の上限を確認],
  [認証情報エラー], [認証情報の内容を再確認。SSH鍵のフォーマットを確認],
  [インベントリ同期エラー], [クラウド認証情報の権限を確認。IAMポリシーを見直し],
  [Web UIが遅い], [データベースのクリーンアップ。リソース割り当ての見直し],
  [Podが再起動を繰り返す], [リソース不足の可能性。`kubectl describe pod` でイベントを確認],
)

=== ログの確認

```bash
# AWX Operator環境でのログ確認
kubectl logs -f deployment/awx-demo-web -n awx -c awx-web
kubectl logs -f deployment/awx-demo-task -n awx -c awx-task

# Receptor（実行ノード）のログ
kubectl logs -f deployment/awx-demo-task -n awx -c awx-receptor
```

=== デバッグ用API

```bash
# システムの状態確認
curl -H "Authorization: Bearer $TOKEN" \
  https://awx.example.com/api/v2/ping/

# 実行ノードの状態
curl -H "Authorization: Bearer $TOKEN" \
  https://awx.example.com/api/v2/instances/
```

== セキュリティのベストプラクティス

- *HTTPS の有効化*：本番環境では必ずTLS/SSLを設定する
- *デフォルトパスワードの変更*：初期管理者パスワードを速やかに変更
- *外部認証の利用*：LDAP/SAMLでの認証を推奨
- *定期的なトークンローテーション*：APIトークンを定期的に更新
- *認証情報の最小権限化*：マシン認証情報にはsudo制限付きのユーザーを使用
- *監査ログの監視*：不審な操作がないか定期的に確認
