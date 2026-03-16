#import "/templates/book.typ": book

#show: book.with(
  title: "vibe-local 入門",
  author: "aoki-taquan",
)

#include "chapters/01-はじめに.typ"
#include "chapters/02-インストール.typ"
#include "chapters/03-基本操作.typ"
#include "chapters/04-組み込みツール.typ"
#include "chapters/05-高度な機能.typ"
#include "chapters/06-モデルと設定.typ"
#include "chapters/07-Tips.typ"
