#import "/templates/book.typ": book

#show: book.with(
  title: "Claude Code 入門（ChatGPT ユーザー向け）",
  author: "aoki-taquan",
)

#include "chapters/01-chatgptとの違い.typ"
#include "chapters/02-準備.typ"
#include "chapters/03-最初の一歩.typ"
#include "chapters/04-ファイルを触ってもらう.typ"
#include "chapters/05-実践ユースケース.typ"
#include "chapters/06-便利な使い方.typ"
