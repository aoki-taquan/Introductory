#import "/templates/book.typ": book

#show: book.with(
  title: "NetBox 入門",
  author: "aoki-taquan",
)

#include "chapters/01-はじめに.typ"
#include "chapters/02-インストール.typ"
#include "chapters/03-基本操作.typ"
#include "chapters/04-DCIM.typ"
#include "chapters/05-IPAM.typ"
#include "chapters/06-仮想化管理.typ"
#include "chapters/07-回路と接続管理.typ"
#include "chapters/08-カスタマイズ.typ"
#include "chapters/09-APIと自動化.typ"
#include "chapters/10-運用管理.typ"
