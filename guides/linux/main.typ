#import "/templates/book.typ": book

#show: book.with(
  title: "Linux 入門",
  author: "aoki-taquan",
)

#include "chapters/01-はじめに.typ"
#include "chapters/02-インストール.typ"
#include "chapters/03-基本コマンド.typ"
#include "chapters/04-ファイルシステム.typ"
#include "chapters/05-ユーザーとパーミッション.typ"
#include "chapters/06-パッケージ管理.typ"
#include "chapters/07-プロセス管理.typ"
#include "chapters/08-ネットワーク.typ"
#include "chapters/09-シェルスクリプト.typ"
#include "chapters/10-サービス管理.typ"
