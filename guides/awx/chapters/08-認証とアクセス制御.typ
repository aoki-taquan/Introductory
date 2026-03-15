= 認証とアクセス制御

AWXは、エンタープライズ環境向けの細かなアクセス制御機能を備えている。

== RBAC（ロールベースアクセス制御）

AWXのRBACは、オブジェクトごとにロール（権限）を割り当てる仕組みである。

=== ロールの種類

各オブジェクトには以下のようなロールが定義されている。

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*ロール*], [*権限*]),
  [Admin（管理者）], [オブジェクトの読み取り・編集・削除・権限付与が可能],
  [Use（使用）], [ジョブテンプレート等でオブジェクトを参照可能],
  [Update（更新）], [プロジェクトやインベントリの同期を実行可能],
  [Execute（実行）], [ジョブテンプレートの実行が可能],
  [Read（読み取り）], [オブジェクトの閲覧が可能],
  [Approve（承認）], [ワークフローの承認ノードを承認可能],
)

=== 権限の付与

権限はユーザーまたはチームに対して付与できる。

+ 対象オブジェクト（プロジェクト、インベントリ等）の詳細画面を開く
+ *アクセス* タブを選択
+ *追加* をクリック
+ ユーザーまたはチームを選択
+ ロールを選択して *保存*

=== 権限設計のベストプラクティス

- *チーム単位で権限を付与*：個別ユーザーではなくチームに権限を設定し、メンバーの追加・削除で権限管理を行う
- *最小権限の原則*：必要最低限の権限のみ付与する
- *組織でリソースを分離*：部署やプロジェクト単位で組織を分け、リソースの可視性を制御する

== 認証情報タイプ

=== カスタム認証情報タイプ

AWXには標準の認証情報タイプが用意されているが、独自のタイプを作成することも可能である。

+ *管理 > 認証情報タイプ* を選択
+ *追加* をクリック
+ 以下を定義

*入力設定*（JSON形式）：認証情報の入力フィールドを定義

```json
{
  "fields": [
    {
      "id": "api_token",
      "type": "string",
      "label": "API Token",
      "secret": true
    },
    {
      "id": "api_url",
      "type": "string",
      "label": "API URL"
    }
  ],
  "required": ["api_token", "api_url"]
}
```

*インジェクター設定*（JSON形式）：Playbookに値を渡す方法を定義

```json
{
  "extra_vars": {
    "custom_api_token": "{{ api_token }}",
    "custom_api_url": "{{ api_url }}"
  }
}
```

== 外部認証の設定

=== LDAP認証

Active DirectoryやOpenLDAPと連携する設定である。

+ *設定 > 認証 > LDAP* を選択
+ 以下の主要項目を設定

#table(
  columns: (1fr, 2fr),
  align: left,
  table.header([*項目*], [*設定値の例*]),
  [LDAPサーバーURI], [`ldaps://ldap.example.com:636`],
  [バインドDN], [`cn=awx-bind,ou=service,dc=example,dc=com`],
  [バインドパスワード], [バインドユーザーのパスワード],
  [ユーザー検索], [`ou=users,dc=example,dc=com` / `SCOPE_SUBTREE` / `(sAMAccountName=%(user)s)`],
  [グループ検索], [`ou=groups,dc=example,dc=com` / `SCOPE_SUBTREE` / `(objectClass=group)`],
  [ユーザーフラグ(管理者)], [管理者にマッピングするLDAPグループ],
)

=== SAML認証

SAML 2.0に対応したIdP（Okta、Azure AD等）と連携できる。

+ *設定 > 認証 > SAML* を選択
+ 以下の主要項目を設定
  - *エンティティID*：AWXのSAMLエンティティID
  - *アサーションコンシューマーサービスURL*：AWXのACS URL
  - *IdPメタデータURL*：IdPのメタデータURL
  - *組織マッピング*：SAML属性とAWX組織のマッピング
  - *チームマッピング*：SAML属性とAWXチームのマッピング

=== GitHub / Google認証

OAuth2ベースのソーシャル認証も設定可能である。

+ *設定 > 認証 > GitHub*（または Google）を選択
+ OAuth アプリケーションのClient IDとClient Secretを設定
+ 組織マッピングを設定

== 実行環境（Execution Environment）

実行環境は、Playbook実行に必要なAnsibleバージョン・コレクション・Pythonライブラリをパッケージ化したコンテナイメージである。

=== デフォルト実行環境

AWXにはデフォルトの実行環境が含まれている。カスタムコレクションやPythonパッケージが必要な場合は、独自の実行環境を作成する。

=== カスタム実行環境の作成

`ansible-builder` ツールを使用して作成する。

```bash
# ansible-builderのインストール
pip install ansible-builder

# 実行環境の定義ファイル
cat <<EOF > execution-environment.yml
version: 3
dependencies:
  galaxy:
    collections:
      - amazon.aws
      - community.general
  python:
    - boto3
    - botocore
  system:
    - gcc
EOF

# ビルド
ansible-builder build --tag my-custom-ee:latest
```

作成したイメージをコンテナレジストリにプッシュし、AWXの *管理 > 実行環境* から登録する。
