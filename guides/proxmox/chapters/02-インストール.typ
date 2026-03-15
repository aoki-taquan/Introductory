= インストール

== システム要件

Proxmox VE を動作させるためのハードウェア要件は以下の通りです。

=== 最小要件

- *CPU*：64bit（Intel EMT64 または AMD64）、Intel VT/AMD-V 対応
- *メモリ*：2 GB 以上（推奨 4 GB 以上、ゲスト OS 分は別途必要）
- *ストレージ*：32 GB 以上（推奨 SSD）
- *ネットワーク*：1 つ以上の NIC

=== 推奨要件

- *CPU*：マルチコア（4 コア以上）、VT-d/AMD-Vi 対応（PCI パススルー用）
- *メモリ*：16 GB 以上（ECC メモリ推奨）
- *ストレージ*：OS 用 SSD + データ用ストレージ（ZFS 利用時は ECC メモリ推奨）
- *ネットワーク*：2 つ以上の NIC（管理用とVM用で分離）

== ISO イメージのダウンロード

Proxmox VE の ISO イメージは公式サイトからダウンロードします。

+ ブラウザで `https://www.proxmox.com/en/downloads` にアクセス
+ 「Proxmox VE ISO Installer」の最新版をダウンロード
+ ダウンロード後、チェックサムを検証

```bash
# SHA256 チェックサムの検証
sha256sum proxmox-ve_8.x-x.iso
```

== インストールメディアの作成

=== USB メモリへの書き込み

```bash
# Linux の場合
dd bs=1M conv=fdatasync if=proxmox-ve_8.x-x.iso of=/dev/sdX

# macOS の場合
sudo dd if=proxmox-ve_8.x-x.iso of=/dev/rdiskN bs=1m
```

Windows の場合は Rufus や Etcher などのツールを使用してください。

== インストール手順

=== BIOS/UEFI の設定

インストール前に以下の設定を確認・変更してください：

+ *Intel VT-x / AMD-V*：有効化（仮想化支援）
+ *Intel VT-d / AMD-Vi*：有効化（PCI パススルー用、任意）
+ *ブート順序*：USB を最優先に設定

=== インストーラーの起動

+ USB メモリからブート
+ 「Install Proxmox VE (Graphical)」を選択
+ EULA に同意

=== ディスクの設定

ターゲットディスクを選択します。「Options」ボタンで詳細設定が可能です：

- *ext4*：一般的なファイルシステム（シンプル）
- *xfs*：高パフォーマンス
- *ZFS（RAID0/1/10/RAIDZ）*：データ保護・スナップショット機能（推奨）

ZFS を選択する場合は複数ディスクの構成を設定できます。

=== ネットワークの設定

以下を入力します：

- *Management Interface*：管理用 NIC を選択
- *Hostname (FQDN)*：`pve.local` など
- *IP Address*：固定 IP を設定（例：`192.168.1.100/24`）
- *Gateway*：デフォルトゲートウェイ
- *DNS Server*：DNS サーバーのアドレス

=== パスワードとメールの設定

- *Password*：root ユーザーのパスワード
- *E-mail*：管理者のメールアドレス（通知用）

=== インストールの完了

設定を確認して「Install」をクリックすると、インストールが開始されます。
完了後、再起動するとコンソールに Web UI の URL が表示されます。

== 初期設定

=== Web UI へのアクセス

ブラウザで以下の URL にアクセスします：

```
https://<IPアドレス>:8006
```

自己署名証明書のため、ブラウザの警告が表示されますが続行してください。
ログイン情報は以下の通りです：

- *ユーザー名*：`root`
- *レルム*：`Linux PAM standard authentication`
- *パスワード*：インストール時に設定したパスワード

=== サブスクリプションの無効化（任意）

無償で利用する場合、エンタープライズリポジトリを無効化し、
no-subscription リポジトリを有効化します。

```bash
# エンタープライズリポジトリを無効化
mv /etc/apt/sources.list.d/pve-enterprise.list \
   /etc/apt/sources.list.d/pve-enterprise.list.bak

# no-subscription リポジトリを追加
echo "deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription" \
  > /etc/apt/sources.list.d/pve-no-subscription.list

# パッケージの更新
apt update && apt full-upgrade -y
```

=== タイムゾーンと NTP の確認

```bash
# タイムゾーンの確認・設定
timedatectl set-timezone Asia/Tokyo

# NTP の確認（chrony が標準）
systemctl status chronyd
```
