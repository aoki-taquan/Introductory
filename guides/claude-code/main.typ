#import "/templates/book.typ": book

#show: book.with(
  title: "Claude Code 入門",
  author: "aoki-taquan",
)

#include "chapters/01-はじめに.typ"
#include "chapters/02-インストール.typ"
#include "chapters/03-基本操作.typ"
#include "chapters/04-ファイル操作とコード編集.typ"
#include "chapters/05-コマンドと設定.typ"
#include "chapters/06-Git連携.typ"
#include "chapters/07-MCP.typ"
#include "chapters/08-IDE連携.typ"
#include "chapters/09-高度な使い方.typ"
#include "chapters/10-Tips.typ"
