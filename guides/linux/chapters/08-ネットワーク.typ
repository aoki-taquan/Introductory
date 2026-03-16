= ネットワーク

== ネットワークの基本確認

```bash
# IPアドレスの確認
ip addr show
ip a                        # 省略形

# ルーティングテーブルの確認
ip route show

# DNSの確認
cat /etc/resolv.conf
resolvectl status           # systemd-resolved環境

# ネットワークインターフェースの状態
ip link show
```

== 接続テスト

```bash
# 疎通確認
ping -c 4 8.8.8.8
ping -c 4 google.com

# 経路の確認
traceroute google.com
tracepath google.com

# ポートへの接続テスト
nc -zv example.com 443
curl -I https://example.com

# DNS名前解決
nslookup example.com
dig example.com
host example.com
```

== ネットワーク設定

=== Netplanによる設定（Ubuntu）

Ubuntu 18.04以降ではNetplanがネットワーク設定の標準となっている。

```yaml
# /etc/netplan/01-config.yaml
network:
  version: 2
  ethernets:
    eth0:
      dhcp4: true
    eth1:
      addresses:
        - 192.168.1.100/24
      routes:
        - to: default
          via: 192.168.1.1
      nameservers:
        addresses:
          - 8.8.8.8
          - 8.8.4.4
```

```bash
# 設定の適用
sudo netplan apply

# 設定のテスト（問題があれば自動ロールバック）
sudo netplan try
```

=== NetworkManagerによる設定

```bash
# 接続の一覧
nmcli connection show

# 静的IPの設定
nmcli connection modify eth0 ipv4.addresses 192.168.1.100/24
nmcli connection modify eth0 ipv4.gateway 192.168.1.1
nmcli connection modify eth0 ipv4.dns "8.8.8.8 8.8.4.4"
nmcli connection modify eth0 ipv4.method manual
nmcli connection up eth0
```

== ポートとソケット

```bash
# 使用中のポートを確認
ss -tulnp

# 特定のポートを使用しているプロセスを確認
ss -tlnp | grep :80

# 旧来のコマンド（非推奨だが広く使われる）
netstat -tulnp
```

`ss` コマンドのオプション:
#table(
  columns: (1fr, 2fr),
  [*オプション*], [*説明*],
  [`-t`], [TCPソケットを表示],
  [`-u`], [UDPソケットを表示],
  [`-l`], [リスニング中のソケットのみ],
  [`-n`], [名前解決せず数値で表示],
  [`-p`], [ソケットを使用しているプロセスを表示],
)

== ファイアウォール

=== ufw（Ubuntu）

ufw（Uncomplicated Firewall）はiptablesのフロントエンドで、簡単にファイアウォールを設定できる。

```bash
# ufwの有効化
sudo ufw enable

# 状態の確認
sudo ufw status verbose

# ルールの追加
sudo ufw allow 22/tcp              # SSHを許可
sudo ufw allow 80,443/tcp          # HTTP/HTTPSを許可
sudo ufw allow from 192.168.1.0/24 # 特定のネットワークを許可
sudo ufw deny 3306                 # MySQLポートを拒否

# ルールの削除
sudo ufw delete allow 80/tcp
```

=== firewalld（RHEL / Rocky Linux）

```bash
# 状態の確認
sudo firewall-cmd --state

# 許可サービスの確認
sudo firewall-cmd --list-all

# サービスの許可（恒久的）
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --reload

# ポートの許可
sudo firewall-cmd --permanent --add-port=8080/tcp
sudo firewall-cmd --reload
```

== データ転送

```bash
# ファイルのダウンロード
curl -O https://example.com/file.tar.gz
wget https://example.com/file.tar.gz

# リモートサーバーとのファイル転送（SCP）
scp file.txt user@remote:/tmp/
scp user@remote:/tmp/file.txt ./

# ディレクトリごと転送（rsync）
rsync -avz /local/dir/ user@remote:/remote/dir/
rsync -avz --delete /local/dir/ user@remote:/remote/dir/
```

== SSH

SSH（Secure Shell）はリモートサーバーへの暗号化された接続を提供する。

```bash
# リモートサーバーへの接続
ssh user@192.168.1.100
ssh -p 2222 user@example.com        # ポート指定

# SSH鍵の生成
ssh-keygen -t ed25519 -C "user@example.com"

# 公開鍵をリモートサーバーに登録
ssh-copy-id user@remote

# SSH設定ファイル（~/.ssh/config）
# Host myserver
#     HostName 192.168.1.100
#     User admin
#     Port 2222
#     IdentityFile ~/.ssh/id_ed25519
```

上記の設定を行うと `ssh myserver` で接続できるようになる。
