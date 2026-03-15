= Tips

== Cloud-Init

Cloud-Init を使用すると、VM のデプロイ時にホスト名、ユーザー、SSH 鍵、
ネットワーク設定を自動的に適用できます。

```bash
# Cloud-Init ドライブの追加
qm set <vmid> --ide2 local-lvm:cloudinit

# Cloud-Init 設定
qm set <vmid> --ciuser admin
qm set <vmid> --cipassword <パスワード>
qm set <vmid> --sshkeys ~/.ssh/id_rsa.pub
qm set <vmid> --ipconfig0 ip=192.168.1.50/24,gw=192.168.1.1
qm set <vmid> --nameserver 8.8.8.8
qm set <vmid> --searchdomain example.com
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
cat /var/log/syslog | grep <vmid>
```

==== クラスタの同期問題

```bash
# クラスタファイルシステムの状態
pmxcfs -l

# Corosync の再起動
systemctl restart corosync
systemctl restart pve-cluster
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

== 便利なコマンド集

```bash
# ノードのリソース使用状況
pvesh get /nodes/<ノード名>/status

# 全 VM/CT のリソース情報
pvesh get /cluster/resources --type vm

# タスクログの確認
pvesh get /nodes/<ノード名>/tasks

# 設定ファイルのバックアップ
tar czf /root/pve-config-backup.tar.gz /etc/pve/

# SSL 証明書の更新（Let's Encrypt）
pvenode acme account register default <メール>
pvenode acme cert order
```
