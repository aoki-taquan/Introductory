= 仮想マシン

== 仮想マシンの作成

=== Web UI から作成

+ 右上の「Create VM」ボタンをクリック
+ 各タブで設定を行う：

*General*
- *Node*：VM を配置するノード
- *VM ID*：一意の番号（デフォルトで自動採番）
- *Name*：VM の名前

*OS*
- *ISO image*：インストールに使用する ISO を選択
- *Guest OS Type*：Linux / Windows / Other

*System*
- *Machine*：q35（推奨）または i440fx
- *BIOS*：OVMF（UEFI）または SeaBIOS
- *SCSI Controller*：VirtIO SCSI single（推奨）
- *Qemu Agent*：有効化推奨

*Disks*
- *Bus/Device*：VirtIO Block または SCSI
- *Storage*：ディスクの保存先
- *Disk size*：ディスクサイズ（GiB）
- *Discard*：SSD 使用時はチェック（TRIM サポート）

*CPU*
- *Cores*：割り当てるコア数
- *Type*：host（最高性能、ライブマイグレーション時は同一 CPU が必要）または x86-64-v2-AES（異なる CPU 間でのマイグレーション互換性重視）

*Memory*
- *Memory (MiB)*：割り当てるメモリ量
- *Ballooning Device*：動的メモリ管理（有効化推奨）

*Network*
- *Bridge*：`vmbr0`（デフォルト）
- *Model*：VirtIO（推奨）
- *VLAN Tag*：必要に応じて設定

=== コマンドラインから作成

```bash
# 基本的な VM 作成
qm create 100 \
  --name my-vm \
  --memory 4096 \
  --cores 2 \
  --scsihw virtio-scsi-single \
  --scsi0 local-lvm:32 \
  --ide2 local:iso/debian-12.iso,media=cdrom \
  --net0 virtio,bridge=vmbr0 \
  --boot order=ide2

# VM の起動
qm start 100
```

== VirtIO ドライバー

=== VirtIO とは

VirtIO は KVM 環境に最適化された準仮想化ドライバーです。
ハードウェアをエミュレーションする代わりに、ゲストとホストが効率的に通信するため、
ディスク I/O やネットワーク性能が大幅に向上します。

VM 作成時のディスクバスの選択：
- *VirtIO SCSI*：推奨。SCSI コマンドに対応し、ホットプラグや TRIM をサポート
- *VirtIO Block*：シンプルだがホットプラグ非対応。レガシー用途向け
- *IDE / SATA*：VirtIO ドライバーがない場合の互換モード（低性能）

=== Linux ゲスト

Linux カーネルには VirtIO ドライバーが標準で含まれているため、
追加のインストールは不要です。

=== Windows ゲスト

Windows には VirtIO ドライバーが含まれていないため、別途インストールが必要です。
インストールしない場合、VirtIO デバイスが認識されません。

+ VirtIO ISO をダウンロード（`https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso`）
+ VM に第二の CD ドライブとして VirtIO ISO をマウント
+ Windows インストール時にドライバーを読み込み、またはインストール後に実行

```bash
# VirtIO ISO を第二ドライブに追加
qm set 100 --ide2 local:iso/virtio-win.iso,media=cdrom
```

== QEMU Guest Agent

QEMU Guest Agent を導入すると、ホストからゲスト OS を適切に管理できます。

=== 有効化と導入

```bash
# VM 側で Guest Agent を有効化
qm set <vmid> --agent enabled=1

# Linux ゲストへのインストール
apt install qemu-guest-agent    # Debian/Ubuntu
dnf install qemu-guest-agent    # RHEL/Fedora

systemctl enable --now qemu-guest-agent
```

Guest Agent を有効化すると以下が可能になります：

- IP アドレスの正確な表示
- ファイルシステムの静止（freeze/thaw）によるバックアップの整合性向上
- ゲスト OS の適切なシャットダウン

== スナップショット

スナップショットは VM の状態を保存し、後から復元できる機能です。

```bash
# スナップショットの作成
qm snapshot <vmid> <スナップショット名> --description "説明"

# スナップショット一覧
qm listsnapshot <vmid>

# スナップショットへのロールバック
qm rollback <vmid> <スナップショット名>

# スナップショットの削除
qm delsnapshot <vmid> <スナップショット名>
```

== クローン

既存の VM を複製する方法は 2 種類あります。

=== フルクローン

ディスクを完全にコピーします。元の VM とは独立した VM が作成されます。

```bash
qm clone <元vmid> <新vmid> --name <名前> --full
```

=== リンクドクローン

ベースイメージを共有し、差分のみ保存します。ディスク使用量を節約できます。

```bash
# 先にテンプレートに変換
qm template <vmid>

# リンクドクローンの作成
qm clone <元vmid> <新vmid> --name <名前>
```

== テンプレート

頻繁に同じ構成の VM を作成する場合、テンプレート化が便利です。

+ VM を通常通り作成・設定
+ OS のインストールと初期設定を完了
+ `cloud-init` パッケージをインストール（任意）
+ VM をシャットダウン
+ テンプレートに変換

```bash
qm template <vmid>
```

テンプレートからは「Clone」で新しい VM を作成できます。
