= Tips

== Cloud-Init

Cloud-Init を使用すると、VM のデプロイ時にホスト名、ユーザー、SSH 鍵、
ネットワーク設定を自動的に適用できます。テンプレートと組み合わせることで、
VM のプロビジョニングを完全に自動化できます。

=== 基本設定

```bash
# Cloud-Init ドライブの追加
qm set <vmid> --ide2 local-lvm:cloudinit

# ユーザーと認証
qm set <vmid> --ciuser admin
qm set <vmid> --cipassword <パスワード>
qm set <vmid> --sshkeys ~/.ssh/id_rsa.pub

# ネットワーク
qm set <vmid> --ipconfig0 ip=192.168.1.50/24,gw=192.168.1.1
qm set <vmid> --nameserver 8.8.8.8
qm set <vmid> --searchdomain example.com
```

=== カスタム Cloud-Init 設定

標準のオプションで不足する場合、カスタム YAML を指定できます。

```bash
# カスタム設定ファイルをスニペットストレージに配置
cat > /var/lib/vz/snippets/my-cloud-init.yml << 'EOF'
#cloud-config
packages:
  - nginx
  - git
  - curl
runcmd:
  - systemctl enable --now nginx
write_files:
  - path: /etc/motd
    content: "Welcome to Proxmox VM\n"
EOF

# カスタム設定を VM に適用
qm set <vmid> --cicustom "vendor=local:snippets/my-cloud-init.yml"
```

=== Cloud-Init テンプレートのワークフロー

+ クラウドイメージをダウンロード（Ubuntu、Debian など公式提供）
+ VM を作成しディスクをインポート
+ Cloud-Init ドライブとデフォルト設定を追加
+ テンプレートに変換
+ クローン時に Cloud-Init パラメータを変更してデプロイ

```bash
# Ubuntu クラウドイメージの例
wget https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img

# VM 作成とディスクインポート
qm create 9000 --name ubuntu-template --memory 2048 --cores 2 \
  --net0 virtio,bridge=vmbr0 --scsihw virtio-scsi-single
qm importdisk 9000 noble-server-cloudimg-amd64.img local-lvm
qm set 9000 --scsi0 local-lvm:vm-9000-disk-0
qm set 9000 --ide2 local-lvm:cloudinit
qm set 9000 --boot order=scsi0
qm set 9000 --serial0 socket --vga serial0
qm set 9000 --agent enabled=1

# デフォルト Cloud-Init 設定
qm set 9000 --ciuser admin --sshkeys ~/.ssh/id_rsa.pub
qm set 9000 --ipconfig0 ip=dhcp

# テンプレート化
qm template 9000

# デプロイ（クローンして個別設定を上書き）
qm clone 9000 110 --name web-server --full
qm set 110 --ipconfig0 ip=192.168.1.110/24,gw=192.168.1.1
qm start 110
```

== PCI パススルー

物理デバイス（GPU など）を VM に直接割り当てることができます。

=== IOMMU の有効化

```bash
# /etc/default/grub を編集
# Intel CPU の場合
GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on"

# AMD CPU の場合
GRUB_CMDLINE_LINUX_DEFAULT="quiet amd_iommu=on"

# GRUB 更新
update-grub
reboot
```

=== VFIO モジュールの設定

```bash
# /etc/modules に追加
cat >> /etc/modules << EOF
vfio
vfio_iommu_type1
vfio_pci
vfio_virqfd
EOF

# カーネルモジュールの更新
update-initramfs -u -k all
reboot
```

=== デバイスの割り当て

```bash
# IOMMU グループの確認
find /sys/kernel/iommu_groups/ -type l

# VM にデバイスを追加（Web UI または CLI）
qm set <vmid> --hostpci0 <デバイスID>
```

=== GPU パススルーの注意点

- IOMMU グループ内の全デバイスをまとめてパススルーする必要がある場合がある
- NVIDIA GPU はデフォルトで仮想環境を検知してドライバーが動作しないことがある。`--hostpci0` に `,x-vga=1` を追加
- ホスト側で使用中の GPU はパススルーできない。ホストはオンボードグラフィックスまたは別 GPU を使用する
- ACS（Access Control Services）対応のマザーボードが望ましい

== REST API の活用

Proxmox VE は完全な REST API を提供しており、自動化に活用できます。

```bash
# API トークンの作成（Web UI: Datacenter → Permissions → API Tokens）

# curl での API アクセス例
curl -k -H "Authorization: PVEAPIToken=user@pam!token-name=<トークン値>" \
  https://<IP>:8006/api2/json/nodes

# VM 一覧の取得
curl -k -H "Authorization: PVEAPIToken=user@pam!token-name=<トークン値>" \
  https://<IP>:8006/api2/json/nodes/<ノード>/qemu

# VM の起動
curl -k -X POST \
  -H "Authorization: PVEAPIToken=user@pam!token-name=<トークン値>" \
  https://<IP>:8006/api2/json/nodes/<ノード>/qemu/<vmid>/status/start
```

== Terraform との連携

Terraform の Proxmox プロバイダーを使用して、インフラをコードで管理できます。

```hcl
terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.38.0"
    }
  }
}

provider "proxmox" {
  endpoint  = "https://192.168.1.100:8006/"
  api_token = "user@pam!terraform=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  insecure  = true
}

resource "proxmox_virtual_environment_vm" "example" {
  name      = "terraform-vm"
  node_name = "pve"

  clone {
    vm_id = 9000  # テンプレート VM の ID
  }

  cpu {
    cores = 2
  }

  memory {
    dedicated = 2048
  }

  disk {
    size         = 32
    datastore_id = "local-lvm"
    interface    = "scsi0"
  }

  network_device {
    model  = "virtio"
    bridge = "vmbr0"
  }
}
```

== タグとバルク操作

=== タグ

VM/CT にタグを付けて分類・検索を効率化できます。

```bash
# タグの設定
qm set <vmid> --tags "production,web"
pct set <ctid> --tags "development,db"
```

Web UI のリソースツリーでタグによるフィルタリングが可能です。

=== バルク操作

```bash
# 特定タグの VM を一括で取得
pvesh get /cluster/resources --type vm | grep "production"

# 全 VM のバックアップ（スケジュールジョブ推奨）
vzdump --all --storage backup-storage --compress zstd --mode snapshot
```

== トラブルシューティング

=== よくある問題と対処法

==== Web UI にアクセスできない

```bash
# pveproxy サービスの確認
systemctl status pveproxy

# 再起動
systemctl restart pveproxy

# ファイアウォールの確認
iptables -L -n | grep 8006
```

==== VM が起動しない

```bash
# VM の設定確認
qm config <vmid>

# ログの確認
journalctl -u pve-qemu-server -f

# タスクログで詳細を確認
pvesh get /nodes/<ノード名>/tasks --limit 5 --errors 1
```

==== ストレージの問題

```bash
# ZFS プールの状態
zpool status

# LVM の状態
lvs
pvs

# ストレージの再スキャン
pvesm scan <ストレージ種類> <サーバー>
```

==== ロックされた VM/CT

操作中に異常終了した場合、VM がロックされることがあります。

```bash
# ロックの確認
qm config <vmid> | grep lock

# ロックの解除
qm unlock <vmid>
```

== 便利なコマンド集

```bash
# ノードのリソース使用状況
pvesh get /nodes/<ノード名>/status

# 全 VM/CT のリソース情報
pvesh get /cluster/resources --type vm

# タスクログの確認
pvesh get /nodes/<ノード名>/tasks

# 設定ファイルのバックアップ
tar czf /root/pve-config-$(date +%Y%m%d).tar.gz /etc/pve/

# VM/CT の一覧（全ノード）
pvesh get /cluster/resources --type vm --output-format table

# 特定ノードの VM 一覧
qm list
pct list
```
