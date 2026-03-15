= ユーザー管理と認証

== 認証レルム

Proxmox VE では、ユーザーの認証方式を「レルム」で管理します。

- *Linux PAM*：ホスト OS の Linux ユーザーで認証。`root@pam` が標準の管理者
- *Proxmox VE Authentication*：Proxmox 独自のユーザーデータベース。OS ユーザー不要
- *LDAP*：LDAP サーバーと連携
- *Active Directory*：Microsoft AD と連携
- *OpenID Connect*：OAuth2/OIDC プロバイダーと連携

=== レルムの追加（LDAP の例）

```bash
# LDAP レルムの追加
pveum realm add my-ldap --type ldap \
  --base-dn "dc=example,dc=com" \
  --user-attr "uid" \
  --server1 ldap.example.com \
  --port 389

# Active Directory レルムの追加
pveum realm add my-ad --type ad \
  --domain example.com \
  --server1 ad.example.com \
  --default 0
```

Web UI では「Datacenter」→「Permissions」→「Realms」から設定できます。

== ユーザーの管理

=== ユーザーの作成

```bash
# Proxmox VE レルムでユーザーを作成
pveum user add operator@pve --password <パスワード> \
  --firstname "太郎" --lastname "山田" \
  --email taro@example.com

# ユーザー一覧の確認
pveum user list
```

=== ユーザーの変更・削除

```bash
# ユーザー情報の変更
pveum user modify operator@pve --email new@example.com

# ユーザーの無効化（削除せず）
pveum user modify operator@pve --enable 0

# ユーザーの削除
pveum user delete operator@pve
```

== グループ

グループを使うと、複数ユーザーにまとめて権限を付与できます。

```bash
# グループの作成
pveum group add admins --comment "管理者グループ"
pveum group add operators --comment "運用者グループ"

# ユーザーをグループに追加
pveum user modify operator@pve --groups operators

# グループ一覧
pveum group list
```

== ロールと権限

=== 組み込みロール

Proxmox VE にはあらかじめ定義されたロールがあります。

#table(
  columns: (auto, auto),
  inset: 8pt,
  align: left,
  table.header(
    [*ロール*], [*説明*],
  ),
  [`Administrator`], [全権限],
  [`PVEAdmin`], [システム設定以外の管理権限],
  [`PVEVMAdmin`], [VM の完全管理],
  [`PVEVMUser`], [VM の利用（起動・停止・コンソール）],
  [`PVEDatastoreAdmin`], [ストレージの管理],
  [`PVEDatastoreUser`], [ストレージの利用（ISO アップロードなど）],
  [`PVEAuditor`], [読み取り専用],
  [`NoAccess`], [アクセス拒否],
)

=== 権限の付与

権限は「パス（対象）」「ユーザーまたはグループ」「ロール」の組み合わせで設定します。

```bash
# グループにデータセンター全体の管理権限を付与
pveum acl modify / --groups admins --roles Administrator

# ユーザーに特定 VM のみの操作権限を付与
pveum acl modify /vms/100 --users operator@pve --roles PVEVMUser

# 特定ストレージへのアクセス権を付与
pveum acl modify /storage/local --groups operators --roles PVEDatastoreUser

# 権限一覧の確認
pveum acl list
```

=== 権限パスの構造

権限パスは階層構造になっており、上位の権限は下位に継承されます。

- `/` — データセンター全体
- `/nodes/<ノード名>` — 特定ノード
- `/vms/<vmid>` — 特定 VM/CT
- `/storage/<ストレージ名>` — 特定ストレージ
- `/pool/<プール名>` — リソースプール

=== カスタムロールの作成

組み込みロールで不足する場合、カスタムロールを作成できます。

```bash
# VM の起動・停止のみ可能なロール
pveum role add VMOperator --privs "VM.PowerMgmt VM.Console VM.Audit"

# 権限一覧の確認
pveum role list
```

== API トークン

API トークンはスクリプトや外部ツールからの認証に使用します。
パスワード認証と異なり、トークンごとに権限を制限できます。

```bash
# API トークンの作成
pveum user token add root@pam automation --privsep 1

# トークン情報の確認
pveum user token list root@pam
```

- `--privsep 1`：トークンに別途権限を設定（ユーザーの権限を継承しない）
- `--privsep 0`：ユーザーと同じ権限を継承

作成時に表示されるトークン値は一度しか表示されないため、安全に保管してください。

== リソースプール

VM/CT やストレージをグループ化し、まとめて権限管理できます。

```bash
# プールの作成
pveum pool add development --comment "開発環境"

# VM をプールに追加
qm set 100 --pool development

# コンテナをプールに追加
pct set 200 --pool development

# プールに対して権限を設定
pveum acl modify /pool/development --groups operators --roles PVEVMAdmin
```

== ベストプラクティス

- *root ユーザーを日常的に使わない*：管理者も個人アカウントを作成する
- *グループベースで権限管理*：個別ユーザーへの直接権限付与は避ける
- *最小権限の原則*：必要最低限のロールのみ付与する
- *API トークンは privsep を有効に*：トークンの権限を制限する
- *定期的な棚卸し*：不要なユーザーやトークンは削除する
