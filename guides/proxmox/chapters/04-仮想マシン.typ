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

== リソース配分のガイドライン

=== CPU

- *コア数*：ゲスト OS の用途に合わせて割り当てる。物理コア数を超える割り当て（オーバーコミット）も可能だが、性能低下に注意
- *CPU ピンニング*：リアルタイム性が求められるワークロードでは `affinity` で特定コアに固定
- *NUMA*：マルチソケットサーバーでは NUMA を有効化すると、メモリアクセスの局所性が向上

```bash
# CPU アフィニティの設定（コア 0-3 に固定）
qm set <vmid> --affinity 0-3

# NUMA の有効化
qm set <vmid> --numa 1
```

=== メモリ

- *固定割り当て*：データベースや Java アプリなど、安定したメモリが必要な場合
- *Ballooning*：メモリの動的管理。未使用メモリをホストに返還する。Web サーバーなど負荷が変動するワークロード向き
- *オーバーコミット*：Ballooning を使えば物理メモリ以上の割り当てが可能だが、スワップ発生時に大幅な性能低下

```bash
# Ballooning の最小メモリを設定
qm set <vmid> --balloon 1024    # 最小 1GB まで縮小可能
```

=== 用途別の目安

#table(
  columns: (auto, auto, auto, auto),
  inset: 8pt,
  align: left,
  table.header(
    [*用途*], [*CPU*], [*メモリ*], [*ディスク*],
  ),
  [軽量 Web サーバー], [1-2 コア], [1-2 GB], [10-20 GB],
  [アプリケーションサーバー], [2-4 コア], [4-8 GB], [30-50 GB],
  [データベースサーバー], [4-8 コア], [8-32 GB], [50-200 GB（SSD 推奨）],
  [デスクトップ（Linux）], [2-4 コア], [4-8 GB], [30-50 GB],
  [デスクトップ（Windows）], [4+ コア], [8+ GB], [60+ GB（SSD 推奨）],
)

== スナップショット

スナップショットは VM の状態を保存し、後から復元できる機能です。
設定変更やアップデート前の保険として便利ですが、長期間の保持には向きません。

=== 注意点

- スナップショットは差分データを蓄積するため、長期間保持するとストレージを圧迫する
- スナップショットが多いほど I/O 性能が低下する可能性がある
- バックアップの代替にはならない（同一ストレージに依存するため）
- RAM を含むスナップショット（VM 稼働中）はメモリ分のサイズが加算される

```bash
# スナップショットの作成
qm snapshot <vmid> <スナップショット名> --description "説明"

# スナップショット一覧
qm listsnapshot <vmid>

# スナップショットへのロールバック
qm rollback <vmid> <スナップショット名>

# スナップショットの削除（不要になったら早めに削除）
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

== Windows VM のベストプラクティス

Windows をゲスト OS として使用する場合の推奨設定：

+ *Machine*：q35（最新のチップセットエミュレーション）
+ *BIOS*：OVMF（UEFI）— Secure Boot も対応
+ *SCSI Controller*：VirtIO SCSI single
+ *Disk*：VirtIO SCSI（VirtIO ドライバー ISO を CD に追加してからインストール）
+ *Network*：VirtIO
+ *Display*：VirtIO-GPU（3D アクセラレーション不要の場合）
+ *Qemu Agent*：有効化（ゲスト内で `virtio-win-guest-tools.exe` をインストール）

=== Windows インストール手順

+ VM を作成し、OS の ISO と VirtIO ドライバー ISO の 2 つを CD ドライブにマウント
+ インストーラーでディスクが表示されない場合、「ドライバーの読み込み」→ VirtIO ISO の `vioscsi` フォルダーを選択
+ インストール完了後、VirtIO ISO 内の `virtio-win-guest-tools.exe` を実行して全ドライバーと Guest Agent を一括インストール
