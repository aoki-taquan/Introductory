#import "/templates/book.typ": book

#show: book.with(
  title: "Proxmox VE 入門",
  author: "aoki-taquan",
)

#include "chapters/01-はじめに.typ"
#include "chapters/02-インストール.typ"
#include "chapters/03-基本操作.typ"
#include "chapters/04-仮想マシン.typ"
#include "chapters/05-コンテナ.typ"
#include "chapters/06-ストレージ.typ"
#include "chapters/07-ネットワーク.typ"
#include "chapters/08-バックアップとリストア.typ"
#include "chapters/09-クラスタ.typ"
#include "chapters/10-Tips.typ"
#include "chapters/11-ユーザー管理と認証.typ"
#include "chapters/12-監視と通知.typ"
#include "chapters/13-アップデートとメンテナンス.typ"
#include "chapters/14-セキュリティ.typ"
