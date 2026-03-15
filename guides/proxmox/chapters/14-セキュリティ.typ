= セキュリティ

== SSL/TLS 証明書

=== デフォルトの自己署名証明書

Proxmox VE はインストール時に自己署名証明書を生成します。
ブラウザの警告を解消するには、正規の証明書を導入します。

=== Let's Encrypt（ACME）

Proxmox VE には ACME クライアントが統合されています。

```bash
# ACME アカウントの登録
pvenode acme account register default admin@example.com

# ドメインの設定
pvenode config set --acme domains=pve.example.com

# 証明書の取得
pvenode acme cert order

# 証明書の自動更新はタイマーで管理される
systemctl status pve-daily-update.timer
```

Web UI では「ノード」→「Certificates」→「ACME」から設定できます。

==== DNS チャレンジ（内部ネットワークの場合）

外部からアクセスできない環境では DNS チャレンジを使用します。

```bash
# DNS プラグインの設定
pvenode acme plugin add dns cloudflare-plugin \
  --type dns --api cf --data "CF_Token=<APIトークン>"

# ドメインの設定（DNS チャレンジ指定）
pvenode config set \
  --acme domains=pve.example.com \
  --acmedomain0 domain=pve.example.com,plugin=cloudflare-plugin
```

=== カスタム証明書の導入

既存の証明書を手動で設定する場合：

```bash
# 証明書ファイルの配置
cp fullchain.pem /etc/pve/nodes/<ノード名>/pveproxy-ssl.pem
cp privkey.pem /etc/pve/nodes/<ノード名>/pveproxy-ssl.key

# pveproxy の再起動
systemctl restart pveproxy
```

== SSH の強化

=== 鍵認証の設定

```bash
# クライアント側で鍵を生成
ssh-keygen -t ed25519 -C "admin@example.com"

# 公開鍵をサーバーに転送
ssh-copy-id -i ~/.ssh/id_ed25519.pub root@<IPアドレス>

# 鍵認証でログインできることを確認してから、以下を実施
```

=== パスワード認証の無効化

```bash
# /etc/ssh/sshd_config を編集
# PasswordAuthentication no
# PermitRootLogin prohibit-password

# 設定の反映
systemctl restart sshd
```

=== SSH ポートの変更（任意）

```bash
# /etc/ssh/sshd_config
# Port 22222

systemctl restart sshd
```

ファイアウォールで新しいポートを許可することを忘れないでください。

== ネットワークセキュリティ

=== 管理ネットワークの分離

管理インターフェース（Web UI、SSH）を専用ネットワークに分離することを推奨します。

```
管理ネットワーク（192.168.1.0/24）─── vmbr0 ─── ホスト管理
VM ネットワーク（10.0.0.0/24）   ─── vmbr1 ─── VM/CT トラフィック
ストレージネットワーク（10.0.1.0/24）─── vmbr2 ─── Ceph/NFS 通信
```

```bash
# /etc/network/interfaces の例
auto vmbr0
iface vmbr0 inet static
    address 192.168.1.100/24
    gateway 192.168.1.1
    bridge-ports eno1
    bridge-stp off
    bridge-fd 0

auto vmbr1
iface vmbr1 inet static
    address 10.0.0.1/24
    bridge-ports eno2
    bridge-stp off
    bridge-fd 0
```

=== ファイアウォールの推奨ルール

Proxmox ホストへのアクセスを制限する基本ルール：

```bash
# /etc/pve/firewall/cluster.fw
[OPTIONS]
enable: 1
policy_in: DROP
policy_out: ACCEPT

[RULES]
# Web UI（管理ネットワークのみ）
IN ACCEPT -source 192.168.1.0/24 -p tcp -dport 8006
# SSH（管理ネットワークのみ）
IN ACCEPT -source 192.168.1.0/24 -p tcp -dport 22
# Corosync（クラスタ通信）
IN ACCEPT -source 192.168.1.0/24 -p udp -dport 5405:5412
# ライブマイグレーション
IN ACCEPT -source 192.168.1.0/24 -p tcp -dport 60000:60050
# VNC コンソール
IN ACCEPT -source 192.168.1.0/24 -p tcp -dport 5900:5999
```

== 二要素認証（2FA）

Web UI のログインに二要素認証を追加できます。

=== TOTP の設定

+ Web UI にログイン
+ 右上のユーザー名 → 「TFA」をクリック
+ 「Add」→ 「TOTP」を選択
+ QR コードを認証アプリ（Google Authenticator など）でスキャン
+ 確認コードを入力して有効化

```bash
# CLI から TOTP を強制する（レルム単位）
pveum realm modify pve --tfa type=totp
```

=== WebAuthn / FIDO2

ハードウェアセキュリティキー（YubiKey など）にも対応しています。

```bash
# WebAuthn の設定（Web UI: Datacenter → Permissions → Realms → TFA）
pveum realm modify pve --webauthn-rp "pve.example.com"
```

== API トークンのセキュリティ

```bash
# トークンには必ず privsep を有効にする
pveum user token add automation@pve ci-token --privsep 1

# トークンに最小限の権限のみ付与
pveum acl modify /vms --users automation@pve --tokens ci-token \
  --roles PVEVMUser

# 不要になったトークンは速やかに削除
pveum user token remove automation@pve ci-token
```

== 監査ログ

Proxmox VE の操作ログは syslog に記録されます。

```bash
# 認証ログの確認
journalctl -u pvedaemon --since "1 hour ago" | grep auth

# タスクログの確認（Web UI の操作履歴）
pvesh get /cluster/tasks --limit 20

# API アクセスログ
journalctl -u pveproxy --since today
```

== セキュリティチェックリスト

- [ ] デフォルトの root パスワードを強固なものに変更
- [ ] 管理者用の個人アカウントを作成し、root の直接利用を避ける
- [ ] SSH 鍵認証を設定し、パスワード認証を無効化
- [ ] SSL 証明書を正規のものに置き換え
- [ ] ファイアウォールで管理ポートへのアクセスを制限
- [ ] 二要素認証を有効化
- [ ] 不要なサービスを停止
- [ ] 定期的にセキュリティアップデートを適用
- [ ] API トークンには最小権限を設定
- [ ] バックアップを暗号化（PBS 使用時）
