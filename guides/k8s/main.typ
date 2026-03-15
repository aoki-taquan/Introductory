#import "/templates/book.typ": book

#show: book.with(
  title: "Kubernetes 入門",
  author: "aoki-taquan",
)

#include "chapters/01-はじめに.typ"
#include "chapters/02-環境構築.typ"
#include "chapters/03-基本概念.typ"
#include "chapters/04-Pod.typ"
#include "chapters/05-Deployment.typ"
#include "chapters/06-Service.typ"
#include "chapters/07-ConfigMapとSecret.typ"
#include "chapters/08-ストレージ.typ"
#include "chapters/09-Namespace.typ"
#include "chapters/10-Ingress.typ"
#include "chapters/11-Helm.typ"
#include "chapters/12-Kustomize.typ"
#include "chapters/13-ArgoCDとGitOps.typ"
#include "chapters/14-モニタリング.typ"
#include "chapters/15-実践運用.typ"
