= はじめに

== AWXとは

AWXは、Ansible の自動化機能をWebベースのUIとREST APIで管理・実行できるオープンソースプラットフォームである。Red Hat が提供する商用製品「Ansible Automation Platform（旧 Ansible Tower）」のアップストリームプロジェクトに位置づけられている。

AWXを使うことで、Ansible Playbook の実行をチームで共有し、権限管理やジョブスケジュール、実行履歴の可視化といったエンタープライズ向けの運用管理機能を利用できる。

== AWXの主な特徴

- *Web UI*：ブラウザからPlaybookの実行・管理が可能
- *REST API*：すべての操作をAPIから自動化できる
- *RBAC（ロールベースアクセス制御）*：組織・チーム単位での権限管理
- *ジョブスケジューリング*：定期的なPlaybook実行の自動化
- *実行履歴・監査ログ*：誰が・いつ・何を実行したかを記録
- *認証情報管理*：SSH鍵やクラウドAPIキーを安全に保管
- *SCM連携*：GitリポジトリからPlaybookを自動取得
- *通知機能*：Slack、メール、Webhook等でジョブ結果を通知
- *ワークフロー*：複数のジョブを条件分岐付きで連結実行

== Ansible Towerとの関係

AWXはAnsible Tower（現Ansible Automation Platform Controller）のオープンソース版である。主な違いは以下の通り。

#table(
  columns: (1fr, 1fr, 1fr),
  align: left,
  table.header([*項目*], [*AWX*], [*Ansible Automation Platform*]),
  [ライセンス], [Apache 2.0], [商用サブスクリプション],
  [サポート], [コミュニティ], [Red Hat公式サポート],
  [リリース], [頻繁（開発版）], [安定版リリース],
  [用途], [開発・検証・小規模運用], [本番環境・エンタープライズ],
  [認定コンテンツ], [なし], [あり],
)

== 対象読者

- Ansibleの基本的な使い方を理解している方
- チームでのAnsible運用を効率化したい方
- 自動化の実行管理・権限管理を導入したい方
- AWXをこれから導入・検証したい方

== 前提知識

本ガイドでは以下の知識があることを前提とする。

- Ansibleの基本概念（Playbook、インベントリ、モジュール）
- Linuxの基本操作（コマンドライン操作）
- Dockerの基礎知識（コンテナの起動・停止）
- Kubernetesの基礎知識（AWX Operatorを使う場合）
