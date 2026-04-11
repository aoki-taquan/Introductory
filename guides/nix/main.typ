#import "/templates/book.typ": book

#show: book.with(
  title: "Nix 入門",
  author: "aoki-taquan",
)

#include "chapters/01-はじめに.typ"
#include "chapters/02-インストール.typ"
#include "chapters/03-基本概念.typ"
#include "chapters/04-パッケージ管理.typ"
#include "chapters/05-Nix言語基礎.typ"
#include "chapters/06-開発環境構築.typ"
#include "chapters/07-Nixファイルの書き方.typ"
#include "chapters/08-Flakes.typ"
#include "chapters/09-NixOS基礎.typ"
#include "chapters/10-Tipsとベストプラクティス.typ"
