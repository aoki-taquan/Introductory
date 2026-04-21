#import "/templates/book.typ": book

#show: book.with(
  title: "AWS 入門",
  author: "aoki-taquan",
)

#include "chapters/01-はじめに.typ"
#include "chapters/02-アカウント開設と初期設定.typ"
#include "chapters/03-IAM.typ"
#include "chapters/04-VPC.typ"
#include "chapters/05-EC2.typ"
#include "chapters/06-S3.typ"
#include "chapters/07-データベース.typ"
#include "chapters/08-コンテナとサーバーレス.typ"
#include "chapters/09-運用と監視.typ"
#include "chapters/10-セキュリティとコスト管理.typ"
#include "chapters/11-IaCと運用Tips.typ"
