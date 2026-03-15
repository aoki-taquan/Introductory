#import "/templates/book.typ": book

#show: book.with(
  title: "Containerlab 入門",
  author: "aoki-taquan",
)

#include "chapters/01-はじめに.typ"
#include "chapters/02-インストール.typ"
#include "chapters/03-基本概念.typ"
#include "chapters/04-クイックスタート.typ"
#include "chapters/05-トポロジ定義.typ"
#include "chapters/06-CLIリファレンス.typ"
#include "chapters/07-マルチベンダー環境.typ"
#include "chapters/08-設定管理.typ"
#include "chapters/09-実践的なトポロジ.typ"
#include "chapters/10-CI-CDとの統合.typ"
