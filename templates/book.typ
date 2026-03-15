// templates/book.typ
// 入門書共通テンプレート

#let book(
  title: "",
  author: "",
  date: datetime.today(),
  body,
) = {
  // ドキュメント設定
  set document(title: title, author: author)

  // ページ設定（A4）
  set page(
    paper: "a4",
    margin: (top: 2.5cm, bottom: 2.5cm, left: 2cm, right: 2cm),
    numbering: "1",
    header: context {
      if counter(page).get().first() > 1 {
        align(right, text(size: 9pt, fill: gray)[#title])
      }
    },
  )

  // フォント設定（日本語対応）
  set text(
    font: ("Noto Serif CJK JP", "DejaVu Serif"),
    size: 11pt,
    lang: "ja",
  )

  // 見出し設定
  set heading(numbering: "1.1")

  show heading.where(level: 1): it => {
    pagebreak(weak: true)
    text(size: 20pt, weight: "bold", font: ("Noto Sans CJK JP", "DejaVu Sans"))[
      #it
    ]
    v(1em)
  }

  show heading.where(level: 2): it => {
    v(0.8em)
    text(size: 15pt, weight: "bold", font: ("Noto Sans CJK JP", "DejaVu Sans"))[
      #it
    ]
    v(0.5em)
  }

  show heading.where(level: 3): it => {
    v(0.5em)
    text(size: 12pt, weight: "bold")[#it]
    v(0.3em)
  }

  // コードブロック設定
  show raw.where(block: true): it => {
    block(
      fill: luma(245),
      inset: 10pt,
      radius: 4pt,
      width: 100%,
      it,
    )
  }

  // インラインコード
  show raw.where(block: false): box.with(
    fill: luma(240),
    inset: (x: 3pt, y: 0pt),
    outset: (y: 3pt),
    radius: 2pt,
  )

  // 段落設定
  set par(leading: 0.8em, first-line-indent: 1em, justify: true)

  // 表紙ページ
  page(numbering: none)[
    #v(30%)
    #align(center)[
      #text(size: 28pt, weight: "bold", font: ("Noto Sans CJK JP", "DejaVu Sans"))[#title]
      #v(2em)
      #text(size: 14pt)[#author]
      #v(1em)
      #text(size: 12pt, fill: gray)[#date.display("[year]年[month]月[day]日")]
    ]
  ]

  // 目次
  outline(title: "目次", depth: 3)

  // 本文
  body
}
