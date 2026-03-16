= ユーザーとパーミッション

== ユーザーとグループ

Linuxはマルチユーザーシステムであり、各ユーザーには固有のUID（User ID）が割り当てられる。ユーザーは一つ以上のグループに所属する。

```bash
# 現在のユーザー情報を確認
id
whoami

# ユーザー一覧（/etc/passwdを確認）
cat /etc/passwd

# グループ一覧
cat /etc/group
```

=== ユーザーの管理

```bash
# ユーザーの作成
sudo useradd -m -s /bin/bash newuser    # ホームディレクトリ付き
sudo passwd newuser                      # パスワードの設定

# ユーザーの削除
sudo userdel -r olduser                  # ホームディレクトリも削除

# ユーザー情報の変更
sudo usermod -aG docker newuser          # グループへの追加
sudo usermod -s /bin/zsh newuser         # シェルの変更
```

=== グループの管理

```bash
# グループの作成
sudo groupadd developers

# グループへのユーザー追加
sudo gpasswd -a user1 developers

# グループからのユーザー削除
sudo gpasswd -d user1 developers
```

== パーミッション

Linuxのファイルパーミッションは、所有者（owner）、グループ（group）、その他（others）の3つのカテゴリに対して、読み取り（r）、書き込み（w）、実行（x）の権限を設定する。

```
-rwxr-xr-- 1 user group 4096 Mar 16 10:00 script.sh
│└┬┘└┬┘└┬┘
│ │   │   └── その他: 読み取りのみ（r--）
│ │   └────── グループ: 読み取り+実行（r-x）
│ └────────── 所有者: 全権限（rwx）
└──────────── ファイルタイプ（-: 通常ファイル）
```

=== 数値表記

パーミッションは数値でも表現できる。

#table(
  columns: (1fr, 1fr, 1fr),
  [*権限*], [*記号*], [*数値*],
  [読み取り], [`r`], [4],
  [書き込み], [`w`], [2],
  [実行], [`x`], [1],
  [なし], [`-`], [0],
)

例えば `rwxr-xr--` は `754` となる（7=4+2+1、5=4+0+1、4=4+0+0）。

=== パーミッションの変更

```bash
# 記号モード
chmod u+x script.sh         # 所有者に実行権限を追加
chmod g-w file.txt           # グループから書き込み権限を削除
chmod o=r file.txt           # その他を読み取りのみに設定
chmod a+r file.txt           # 全員に読み取り権限を追加

# 数値モード
chmod 755 script.sh          # rwxr-xr-x
chmod 644 file.txt           # rw-r--r--
chmod 600 secret.key         # rw-------

# 再帰的に変更
chmod -R 755 /var/www/html
```

=== 所有者の変更

```bash
# 所有者の変更
sudo chown user file.txt
sudo chown user:group file.txt      # 所有者とグループを同時に変更
sudo chown -R user:group /var/www   # 再帰的に変更
```

== sudo

`sudo`（superuser do）は、一般ユーザーがroot権限でコマンドを実行するための仕組みである。

```bash
# root権限でコマンドを実行
sudo apt update

# rootユーザーとしてシェルを起動
sudo -i

# 別のユーザーとしてコマンドを実行
sudo -u postgres psql
```

sudoを利用できるユーザーは `/etc/sudoers` で管理される。編集には `visudo` コマンドを使用する。

```bash
# sudoersの編集（構文チェック付き）
sudo visudo

# 例: userにsudo権限を付与（sudoersの記述）
# user ALL=(ALL:ALL) ALL
```

== 特殊なパーミッション

#table(
  columns: (1fr, 1fr, 2fr),
  [*名前*], [*数値*], [*説明*],
  [SUID], [4000], [実行時にファイル所有者の権限で動作する（例: `passwd`コマンド）],
  [SGID], [2000], [実行時にグループの権限で動作する。ディレクトリに設定すると新規ファイルが親のグループを継承],
  [Sticky bit], [1000], [ディレクトリに設定すると、ファイルの所有者のみが削除可能（例: `/tmp`）],
)

```bash
# SUIDの設定
sudo chmod u+s /usr/local/bin/myapp
# または
sudo chmod 4755 /usr/local/bin/myapp

# Sticky bitの設定
sudo chmod +t /shared
# または
sudo chmod 1777 /shared
```
