= ファイルシステム

== ディレクトリ構造

Linuxのファイルシステムはルート（`/`）を頂点としたツリー構造になっている。FHS（Filesystem Hierarchy Standard）により、主要なディレクトリの用途が規定されている。

#table(
  columns: (1fr, 3fr),
  [*ディレクトリ*], [*説明*],
  [`/`], [ルートディレクトリ。すべてのファイルの起点],
  [`/bin`], [基本的なコマンド（`ls`、`cp`など）],
  [`/sbin`], [システム管理用コマンド（`fdisk`、`iptables`など）],
  [`/etc`], [システムの設定ファイル],
  [`/home`], [一般ユーザーのホームディレクトリ],
  [`/root`], [rootユーザーのホームディレクトリ],
  [`/var`], [ログ、キャッシュなど可変データ],
  [`/tmp`], [一時ファイル（再起動時に削除される場合がある）],
  [`/usr`], [ユーザー用プログラムやライブラリ],
  [`/opt`], [サードパーティ製ソフトウェア],
  [`/dev`], [デバイスファイル],
  [`/proc`], [カーネル・プロセス情報（仮想ファイルシステム）],
  [`/sys`], [カーネルのデバイス・ドライバ情報],
  [`/mnt`], [一時的なマウントポイント],
  [`/media`], [リムーバブルメディアのマウントポイント],
)

== パスの種類

- *絶対パス*: ルートから始まるフルパス（例: `/home/user/documents/file.txt`）
- *相対パス*: 現在のディレクトリからの相対位置（例: `../documents/file.txt`）

特殊なディレクトリ表記:
- `.` — 現在のディレクトリ
- `..` — 一つ上のディレクトリ
- `~` — ホームディレクトリ

== ファイルの種類

Linuxでは「すべてはファイル」という設計思想がある。`ls -l` の先頭文字でファイルの種類がわかる。

#table(
  columns: (1fr, 2fr, 2fr),
  [*記号*], [*種類*], [*例*],
  [`-`], [通常のファイル], [`/etc/passwd`],
  [`d`], [ディレクトリ], [`/home/user`],
  [`l`], [シンボリックリンク], [`/usr/bin/python3 -> python3.12`],
  [`b`], [ブロックデバイス], [`/dev/sda`],
  [`c`], [キャラクタデバイス], [`/dev/tty`],
  [`p`], [名前付きパイプ], [プロセス間通信用],
  [`s`], [ソケット], [`/var/run/docker.sock`],
)

== リンク

=== ハードリンク

同じiノードを指す別名である。元のファイルと完全に同等で、元ファイルを削除してもデータは残る。

```bash
ln original.txt hardlink.txt
ls -li original.txt hardlink.txt   # iノード番号が同じことを確認
```

=== シンボリックリンク（ソフトリンク）

ファイルのパスを指すショートカットである。別のファイルシステムへのリンクも可能。

```bash
ln -s /path/to/original.txt symlink.txt
ls -l symlink.txt    # -> で参照先が表示される
```

== ディスク管理

=== ディスク使用量の確認

```bash
# ファイルシステムの使用状況
df -h

# ディレクトリごとの使用量
du -sh /var/log
du -sh /home/*

# 大きなファイルの検索
find / -type f -size +100M -exec ls -lh {} \; 2>/dev/null
```

=== マウントとアンマウント

Linuxではストレージデバイスをディレクトリツリーに「マウント」して利用する。

```bash
# デバイスの一覧表示
lsblk

# マウント
sudo mount /dev/sdb1 /mnt/usb

# アンマウント
sudo umount /mnt/usb

# 起動時の自動マウント設定
cat /etc/fstab
```

== ファイルの検索

```bash
# ファイル名で検索
find /home -name "*.txt"
find / -name "nginx.conf" 2>/dev/null

# ファイルの種類で検索
find /var -type d -name "log"     # ディレクトリのみ
find /tmp -type f -mtime -1       # 1日以内に更新されたファイル

# 高速なファイル検索（インデックスベース）
sudo updatedb
locate nginx.conf
```
