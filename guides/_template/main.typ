#import "/templates/book.typ": book

#show: book.with(
  title: "タイトル",
  author: "著者名",
)

#include "chapters/01-はじめに.typ"
