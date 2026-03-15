# CLAUDE.md

## リポジトリ概要
Typstで書かれた日本語の入門書コレクション。

## セットアップ
```bash
make setup       # Typst + 日本語フォントをインストール
source ~/.bashrc  # PATHを反映
```

## ビルド
```bash
make all                # 全ガイドをコンパイル
make <名前>入門.pdf     # 個別ガイドをコンパイル（例: make claude-code入門.pdf）
make list               # ガイド一覧
```

## 構造
- `guides/<名前>/main.typ` — ガイドのエントリーポイント
- `guides/<名前>/chapters/` — 章ごとの `.typ` ファイル（番号プレフィックス: `01-`, `02-`, ...）
- `guides/<名前>/figures/` — 画像・図（必要に応じて）
- `<名前>入門.pdf` — コンパイル済みPDF（ルート直下に出力、コミット対象）
- `templates/book.typ` — 全ガイド共通テンプレート
- `guides/_template/` — 新規ガイドのひな形

## 新しいガイドの追加手順
1. `guides/_template/` をコピーして `guides/<名前>/` を作成
2. `main.typ` の `title` と `author` を変更
3. `chapters/` に章ファイルを追加し `main.typ` で `#include`
4. `make all` でビルド
5. PDF もコミットすること

## 規約
- テンプレートのインポート: `#import "/templates/book.typ": book`
- `--root .` でコンパイルするためインポートパスは `/` から始める
- 画像参照は相対パスで: `image("figures/example.png")`
- `.typ` を変更したら `make all` してPDFも一緒にコミット
