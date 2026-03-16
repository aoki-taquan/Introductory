= 基本コマンド

== シェルとターミナル

Linuxではシェル（shell）と呼ばれるコマンドラインインターフェースを通じてシステムを操作する。最も広く使われているシェルはBash（Bourne Again Shell）である。

ターミナル（端末エミュレータ）はシェルにアクセスするためのアプリケーションで、GUIデスクトップ環境では `Ctrl + Alt + T` で起動できることが多い。

== コマンドの基本構文

```
コマンド [オプション] [引数]
```

例えば `ls -la /home` は、`ls` がコマンド、`-la` がオプション、`/home` が引数である。

== ファイル・ディレクトリ操作

=== 現在地の確認と移動

```bash
# 現在のディレクトリを表示
pwd

# ディレクトリの移動
cd /var/log          # 絶対パスで移動
cd ..                # 一つ上のディレクトリへ
cd ~                 # ホームディレクトリへ
cd -                 # 直前のディレクトリへ
```

=== ファイル・ディレクトリの一覧

```bash
# 基本的な一覧表示
ls

# 詳細表示（パーミッション、所有者、サイズ、更新日時）
ls -l

# 隠しファイルを含む全ファイルを表示
ls -la

# 人が読みやすいサイズ表示
ls -lh

# ディレクトリのツリー表示
tree -L 2
```

=== ファイル・ディレクトリの作成・削除

```bash
# ディレクトリの作成
mkdir mydir
mkdir -p parent/child/grandchild   # 親ディレクトリも同時に作成

# ファイルの作成（空ファイル）
touch newfile.txt

# ファイルの削除
rm file.txt
rm -r mydir          # ディレクトリごと削除
rm -ri mydir         # 確認付きで削除

# ディレクトリの削除（空の場合のみ）
rmdir emptydir
```

=== コピー・移動・リネーム

```bash
# ファイルのコピー
cp source.txt dest.txt
cp -r srcdir/ destdir/     # ディレクトリのコピー

# ファイルの移動（リネームも同じコマンド）
mv oldname.txt newname.txt
mv file.txt /tmp/
```

== ファイル内容の確認

```bash
# ファイル全体を表示
cat file.txt

# ページ単位で表示（スクロール可能）
less file.txt

# 先頭・末尾の表示
head -n 20 file.txt       # 先頭20行
tail -n 20 file.txt       # 末尾20行
tail -f /var/log/syslog   # リアルタイムで末尾を追跡
```

== テキスト検索・加工

```bash
# ファイル内の文字列検索
grep "error" /var/log/syslog
grep -r "TODO" ./src/          # ディレクトリ内を再帰検索
grep -i "warning" file.txt     # 大文字小文字を無視
grep -n "pattern" file.txt     # 行番号を表示

# テキストの置換
sed 's/old/new/g' file.txt            # 標準出力に結果を表示
sed -i 's/old/new/g' file.txt         # ファイルを直接編集

# 列の切り出し
cut -d',' -f1,3 data.csv       # CSVの1列目と3列目を抽出

# テキストの並べ替え・重複排除
sort file.txt
sort -u file.txt               # 重複排除して並べ替え
uniq                           # 連続する重複行を削除

# 行数・単語数・バイト数のカウント
wc -l file.txt                 # 行数
wc -w file.txt                 # 単語数
```

== パイプとリダイレクト

Linuxの強力な特徴の一つがパイプ（`|`）とリダイレクトである。

```bash
# パイプ: コマンドの出力を次のコマンドの入力にする
cat access.log | grep "404" | wc -l

# リダイレクト: 出力をファイルに書き込む
echo "Hello" > output.txt      # 上書き
echo "World" >> output.txt     # 追記

# 標準エラー出力のリダイレクト
command 2> error.log           # エラーのみファイルへ
command > all.log 2>&1         # 標準出力とエラー両方をファイルへ

# /dev/null（出力を破棄）
command > /dev/null 2>&1
```

== マニュアルとヘルプ

```bash
# マニュアルページの表示
man ls
man 5 passwd          # セクション5のpasswdを表示

# 簡易ヘルプ
ls --help

# コマンドの場所を確認
which python3
type ls
```
