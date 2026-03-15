#import "/templates/book.typ": book

#show: book.with(
  title: "AWX 入門",
  author: "aoki-taquan",
)

#include "chapters/01-はじめに.typ"
#include "chapters/02-インストール.typ"
#include "chapters/03-基本概念.typ"
#include "chapters/04-初期設定.typ"
#include "chapters/05-プロジェクトとインベントリ.typ"
#include "chapters/06-テンプレートとジョブ.typ"
#include "chapters/07-ワークフロー.typ"
#include "chapters/08-認証とアクセス制御.typ"
#include "chapters/09-API活用.typ"
#include "chapters/10-運用Tips.typ"
