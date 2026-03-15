= API活用

AWXのすべての機能はREST APIを通じて利用可能である。Web UIで行える操作はすべてAPIでも実行できる。

== APIの基本

=== APIエンドポイント

AWXのAPIは以下のベースURLで提供される。

```
https://<AWXホスト>/api/v2/
```

ブラウザでこのURLにアクセスすると、利用可能なエンドポイントの一覧が表示される（APIブラウザ）。

=== 主要エンドポイント

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*エンドポイント*], [*説明*]),
  [`/api/v2/organizations/`], [組織の一覧・作成],
  [`/api/v2/users/`], [ユーザーの一覧・作成],
  [`/api/v2/projects/`], [プロジェクトの一覧・作成],
  [`/api/v2/inventories/`], [インベントリの一覧・作成],
  [`/api/v2/credentials/`], [認証情報の一覧・作成],
  [`/api/v2/job_templates/`], [ジョブテンプレートの一覧・作成],
  [`/api/v2/jobs/`], [ジョブの一覧・詳細],
  [`/api/v2/workflow_job_templates/`], [ワークフローの一覧・作成],
)

== 認証方法

=== パーソナルアクセストークン

APIアクセスには、パーソナルアクセストークン（PAT）の使用が推奨される。

==== トークンの作成（Web UI）

+ 右上のユーザーアイコン > *ユーザー詳細* を選択
+ *トークン* タブを開く
+ *追加* をクリック
+ スコープ（Read / Write）を選択して *保存*
+ 表示されたトークンを安全に保管（再表示不可）

==== トークンの使用

```bash
# Authorizationヘッダーにトークンを指定
curl -H "Authorization: Bearer <トークン>" \
  https://awx.example.com/api/v2/me/
```

=== Basic認証

テスト目的ではBasic認証も使用可能であるが、本番環境ではトークン認証を推奨する。

```bash
curl -u "admin:password" \
  https://awx.example.com/api/v2/me/
```

== APIの使用例

=== ジョブテンプレートの一覧取得

```bash
curl -s -H "Authorization: Bearer $TOKEN" \
  https://awx.example.com/api/v2/job_templates/ | jq '.results[] | {id, name}'
```

=== ジョブの実行

```bash
# ジョブテンプレートID 5 を実行
curl -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  https://awx.example.com/api/v2/job_templates/5/launch/
```

=== 追加変数を指定して実行

```bash
curl -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"extra_vars": {"target_env": "staging", "version": "1.2.3"}}' \
  https://awx.example.com/api/v2/job_templates/5/launch/
```

=== ジョブの状態確認

```bash
# ジョブID 42 の状態を確認
curl -s -H "Authorization: Bearer $TOKEN" \
  https://awx.example.com/api/v2/jobs/42/ | jq '{status, started, finished}'
```

=== ジョブの完了待ち

```bash
# ジョブの完了をポーリングで待機
JOB_ID=42
while true; do
  STATUS=$(curl -s -H "Authorization: Bearer $TOKEN" \
    https://awx.example.com/api/v2/jobs/$JOB_ID/ | jq -r '.status')
  echo "Status: $STATUS"
  case $STATUS in
    successful|failed|error|canceled) break ;;
  esac
  sleep 5
done
```

== awx CLI

`awx` コマンドラインツールを使うと、シェルからAWXを操作できる。

=== インストール

```bash
pip install awxkit
```

=== 設定

```bash
export TOWER_HOST=https://awx.example.com
export TOWER_USERNAME=admin
export TOWER_PASSWORD=password
# またはトークン認証
export TOWER_OAUTH_TOKEN=<トークン>
```

=== 使用例

```bash
# ジョブテンプレートの一覧
awx job_templates list --all

# ジョブの実行
awx job_templates launch 5 --extra_vars '{"env": "prod"}'

# ジョブの状態確認
awx jobs get 42

# インベントリの一覧
awx inventory list

# プロジェクトの同期
awx projects update 3
```

== Ansible CollectionによるAPI操作

`ansible.controller` コレクション（旧 `awx.awx`）を使うと、AnsibleのPlaybookからAWXを操作できる。

```yaml
- name: AWXのリソースを構成
  hosts: localhost
  collections:
    - ansible.controller
  tasks:
    - name: プロジェクトを作成
      project:
        name: "My Project"
        organization: "Default"
        scm_type: git
        scm_url: "https://github.com/org/playbooks.git"
        controller_host: "https://awx.example.com"
        controller_oauthtoken: "{{ awx_token }}"

    - name: ジョブテンプレートを作成
      job_template:
        name: "Deploy App"
        project: "My Project"
        playbook: "deploy.yml"
        inventory: "Production"
        controller_host: "https://awx.example.com"
        controller_oauthtoken: "{{ awx_token }}"
```

この方法を使えば、AWX自体の構成をコード化（Configuration as Code）できる。
