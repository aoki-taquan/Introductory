= シェルスクリプト

== シェルスクリプトとは

シェルスクリプトは、シェルコマンドをファイルにまとめて自動実行するプログラムである。繰り返し行う作業や複雑な手順を自動化するために活用される。

```bash
#!/bin/bash
# ファイル名: hello.sh
echo "Hello, World!"
```

```bash
# 実行権限の付与と実行
chmod +x hello.sh
./hello.sh
```

1行目の `#!/bin/bash` はシバン（shebang）と呼ばれ、スクリプトを実行するインタプリタを指定する。

== 変数

```bash
#!/bin/bash

# 変数の定義（=の前後にスペースを入れない）
name="Linux"
version=6

# 変数の参照
echo "OS: $name"
echo "Kernel: ${version}.x"

# コマンドの実行結果を変数に格納
current_date=$(date '+%Y-%m-%d')
file_count=$(ls -1 | wc -l)

echo "日付: $current_date"
echo "ファイル数: $file_count"
```

=== 特殊変数

#table(
  columns: (1fr, 3fr),
  [*変数*], [*説明*],
  [`$0`], [スクリプト名],
  [`$1` 〜 `$9`], [引数（1番目〜9番目）],
  [`$#`], [引数の数],
  [`$@`], [すべての引数（個別に展開）],
  [`$?`], [直前のコマンドの終了ステータス],
  [`$$`], [現在のプロセスID],
)

== 条件分岐

=== if文

```bash
#!/bin/bash

if [ -f "/etc/nginx/nginx.conf" ]; then
    echo "Nginxの設定ファイルが存在します"
elif [ -f "/etc/apache2/apache2.conf" ]; then
    echo "Apacheの設定ファイルが存在します"
else
    echo "Webサーバーの設定ファイルが見つかりません"
fi
```

=== 条件式

#table(
  columns: (1fr, 1fr, 2fr),
  [*カテゴリ*], [*条件式*], [*説明*],
  [ファイル], [`-f file`], [通常ファイルが存在する],
  [ファイル], [`-d dir`], [ディレクトリが存在する],
  [ファイル], [`-e path`], [パスが存在する],
  [ファイル], [`-r file`], [読み取り可能],
  [ファイル], [`-w file`], [書き込み可能],
  [ファイル], [`-x file`], [実行可能],
  [文字列], [`-z str`], [文字列が空],
  [文字列], [`-n str`], [文字列が空でない],
  [文字列], [`str1 = str2`], [文字列が等しい],
  [数値], [`n1 -eq n2`], [等しい],
  [数値], [`n1 -ne n2`], [等しくない],
  [数値], [`n1 -gt n2`], [より大きい],
  [数値], [`n1 -lt n2`], [より小さい],
)

=== case文

```bash
#!/bin/bash

case "$1" in
    start)
        echo "サービスを開始します"
        ;;
    stop)
        echo "サービスを停止します"
        ;;
    restart)
        echo "サービスを再起動します"
        ;;
    *)
        echo "Usage: $0 {start|stop|restart}"
        exit 1
        ;;
esac
```

== ループ

=== forループ

```bash
#!/bin/bash

# リストの繰り返し
for fruit in apple banana orange; do
    echo "果物: $fruit"
done

# 数値の範囲
for i in {1..5}; do
    echo "番号: $i"
done

# ファイルの繰り返し
for file in /var/log/*.log; do
    echo "ログファイル: $file"
done
```

=== whileループ

```bash
#!/bin/bash

count=1
while [ $count -le 5 ]; do
    echo "カウント: $count"
    count=$((count + 1))
done

# ファイルを1行ずつ読み込む
while IFS= read -r line; do
    echo "行: $line"
done < /etc/hosts
```

== 関数

```bash
#!/bin/bash

# 関数の定義
check_service() {
    local service_name=$1
    if systemctl is-active --quiet "$service_name"; then
        echo "$service_name は稼働中です"
        return 0
    else
        echo "$service_name は停止しています"
        return 1
    fi
}

# 関数の呼び出し
check_service nginx
check_service mysql
```

== 実践的なスクリプト例

=== バックアップスクリプト

```bash
#!/bin/bash
set -euo pipefail

BACKUP_DIR="/backup"
SOURCE_DIR="/var/www"
DATE=$(date '+%Y%m%d_%H%M%S')
ARCHIVE="${BACKUP_DIR}/www_${DATE}.tar.gz"

# バックアップディレクトリの作成
mkdir -p "$BACKUP_DIR"

# アーカイブの作成
tar czf "$ARCHIVE" -C "$(dirname "$SOURCE_DIR")" "$(basename "$SOURCE_DIR")"

echo "バックアップ完了: $ARCHIVE"

# 7日以上前のバックアップを削除
find "$BACKUP_DIR" -name "www_*.tar.gz" -mtime +7 -delete
echo "古いバックアップを削除しました"
```

=== ヘルスチェックスクリプト

```bash
#!/bin/bash
set -euo pipefail

SERVICES=("nginx" "mysql" "redis-server")
ALERT_EMAIL="admin@example.com"

for service in "${SERVICES[@]}"; do
    if ! systemctl is-active --quiet "$service"; then
        echo "[ALERT] $service が停止しています" | \
            mail -s "サービス停止: $service" "$ALERT_EMAIL"
        systemctl restart "$service"
        echo "$service を再起動しました"
    fi
done
```

スクリプトの先頭に `set -euo pipefail` を記述することで、エラー発生時にスクリプトを即座に停止させることができる。これは堅牢なスクリプトを書く上での基本的な慣習である。
