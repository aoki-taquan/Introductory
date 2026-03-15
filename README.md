# 入門書コレクション

技術トピックの入門書を [Typst](https://typst.app/) で執筆・管理するリポジトリです。

## セットアップ

```bash
make setup        # Typst + 日本語フォントをインストール
source ~/.bashrc  # PATHを反映
```

## ビルド

```bash
make all                         # 全ガイドをPDFにコンパイル
make guides/<名前>/main.pdf      # 個別ガイドをビルド
make list                        # ガイド一覧
```

## ガイド一覧

| ガイド | 説明 |
|--------|------|
| （準備中） | — |

## 新しいガイドの追加

1. `guides/_template/` をコピーして `guides/<名前>/` を作成
2. `main.typ` の `title` と `author` を編集
3. `chapters/` に章ファイルを追加
4. `make guides/<名前>/main.pdf` でビルド
5. PDFもコミット

```
guides/<名前>/
├── main.typ          # エントリポイント
├── main.pdf          # コンパイル済みPDF
├── chapters/         # 章ファイル
│   ├── 01-はじめに.typ
│   └── 02-基本.typ
└── figures/          # 図・画像（必要に応じて）
```
