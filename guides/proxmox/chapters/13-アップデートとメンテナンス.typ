= アップデートとメンテナンス

== リポジトリの管理

Proxmox VE のパッケージは 3 つのリポジトリから提供されます。

#table(
  columns: (auto, auto, auto),
  inset: 8pt,
  align: left,
  table.header(
    [*リポジトリ*], [*対象*], [*説明*],
  ),
  [Enterprise], [有償サブスクリプション], [安定性最優先。十分にテスト済み],
  [No-Subscription], [検証・ホームラボ], [テスト済みだが Enterprise より早いリリース],
  [Test], [開発者向け], [最新だが不安定な可能性あり。本番禁止],
)

=== リポジトリの確認と設定

```bash
# 現在のリポジトリ設定を確認
cat /etc/apt/sources.list.d/pve-enterprise.list
cat /etc/apt/sources.list.d/pve-no-subscription.list

# Ceph リポジトリ（Ceph 使用時）
cat /etc/apt/sources.list.d/ceph.list
```

Web UI では「ノード」→「Updates」→「Repositories」で確認・編集できます。

== パッケージの更新

=== 通常のセキュリティ更新

```bash
# パッケージリストの更新
apt update

# アップグレード可能なパッケージの確認
apt list --upgradable

# パッケージの更新（依存関係の変更を含む）
apt full-upgrade -y

# 不要パッケージの削除
apt autoremove -y
```

Web UI では「ノード」→「Updates」で GUI から実行できます。

=== 更新前の確認事項

+ 重要な VM/CT のバックアップが最新であること
+ クラスタ環境の場合、全ノードが正常であること
+ カーネル更新がある場合は再起動が必要になる

=== カーネル更新後の再起動

```bash
# 現在のカーネルバージョン
uname -r

# インストール済みカーネルの確認
dpkg -l | grep pve-kernel

# 再起動（VM は自動停止されるため注意）
reboot
```

クラスタ環境では 1 ノードずつ順番に再起動してください。

== メジャーバージョンアップグレード

Proxmox VE のメジャーアップグレード（例：7.x → 8.x）は慎重に行う必要があります。

=== アップグレード前の準備

+ *バックアップ*：全 VM/CT および `/etc/pve/` のバックアップ
+ *互換性チェック*：公式のアップグレードチェッカーを実行
+ *ドキュメント確認*：公式のアップグレードガイドを熟読

```bash
# アップグレードチェッカーの実行（7→8 の例）
pve7to8 --full

# 設定のバックアップ
tar czf /root/pve-config-$(date +%Y%m%d).tar.gz /etc/pve/
```

=== アップグレード手順の概要

+ 現行バージョンを最新に更新
+ チェッカーの全項目をクリア
+ リポジトリを新バージョンに変更
+ `apt update && apt full-upgrade` を実行
+ 再起動
+ 動作確認

注意：メジャーバージョンの飛ばしはできません（7 → 9 は不可、7 → 8 → 9 の順）。

=== クラスタ環境でのアップグレード

クラスタ環境では全ノードを同じバージョンにする必要があります。

+ 全ノードの現行バージョンを最新に更新
+ 1 ノードずつ順番にアップグレード
+ 各ノードのアップグレード後に動作確認
+ 全ノード完了後、クラスタの正常性を確認

```bash
# クラスタの状態確認
pvecm status
pvecm nodes
```

== ノードのメンテナンス

=== 計画メンテナンス

ノードの停止が必要な場合（ハードウェア交換、ファームウェア更新など）の手順：

+ ノード上の VM/CT を他ノードにマイグレーション
+ HA リソースがある場合は HA を一時無効化
+ ノードをシャットダウン
+ メンテナンス実施
+ ノードを起動し、クラスタへの復帰を確認
+ VM/CT を必要に応じて戻す

```bash
# ノード上の全 VM を一括マイグレーション（手動で 1 台ずつ推奨）
# 対象 VM の確認
qm list

# マイグレーション
qm migrate <vmid> <移動先ノード> --online

# HA の一時無効化
ha-manager set vm:<vmid> --state disabled
```

=== ディスク交換（ZFS）

ZFS プールのディスクを交換する手順：

```bash
# 障害ディスクの確認
zpool status

# ディスクの交換（ホットスペアがある場合は自動復旧）
# 新しいディスクを接続後
zpool replace <プール名> <旧デバイス> <新デバイス>

# リシルバー（データ復旧）の進捗確認
zpool status

# 完了後の確認
zpool status
```

=== ディスク追加（ZFS プール拡張）

```bash
# ミラーに新しいミラーペアを追加（ストライプ拡張）
zpool add <プール名> mirror /dev/sdc /dev/sdd

# RAIDZ への拡張（RAIDZ vdev の追加、ZFS 2.2+）
zpool add <プール名> raidz /dev/sde /dev/sdf /dev/sdg
```

注意：既存の vdev 内のディスク数は変更できません。拡張は vdev 単位で行います。

== 自動化

=== Unattended Upgrades

セキュリティアップデートを自動適用する設定：

```bash
apt install unattended-upgrades

# 設定ファイルの編集
cat > /etc/apt/apt.conf.d/50unattended-upgrades << 'EOF'
Unattended-Upgrade::Origins-Pattern {
  "origin=Proxmox,codename=${distro_codename},label=Proxmox Debian Repository";
  "origin=Debian,codename=${distro_codename}-security,label=Debian-Security";
};
Unattended-Upgrade::Mail "admin@example.com";
Unattended-Upgrade::Automatic-Reboot "false";
EOF

# 有効化
dpkg-reconfigure -plow unattended-upgrades
```

カーネルの自動更新は `Automatic-Reboot` を `false` にして、
再起動は手動で計画的に行うことを推奨します。
