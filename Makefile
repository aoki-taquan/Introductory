# Makefile - 入門書ビルドシステム

TYPST := typst
TYPST_FLAGS := --root .

# _template を除く全ガイドのディレクトリを自動検出
GUIDE_DIRS := $(filter-out guides/_template, $(patsubst %/main.typ,%,$(wildcard guides/*/main.typ)))
# PDF名はディレクトリ名に合わせる（例: guides/claude-code/claude-code.pdf）
PDFS := $(foreach d,$(GUIDE_DIRS),$(d)/$(notdir $(d)).pdf)

.PHONY: all clean list setup help

## すべてのガイドをビルド
all: $(PDFS)

## 個別ガイドのビルドルールを動的に生成
define GUIDE_RULE
$(1)/$(notdir $(1)).pdf: $(1)/main.typ $(wildcard $(1)/chapters/*.typ) templates/book.typ
	$$(TYPST) compile $$(TYPST_FLAGS) $$< $$@
	@echo "Built $$@"
endef
$(foreach d,$(GUIDE_DIRS),$(eval $(call GUIDE_RULE,$(d))))

## Typst + 日本語フォントのセットアップ
setup:
	@if command -v $(TYPST) >/dev/null 2>&1; then \
		echo "typst is already installed: $$($(TYPST) --version)"; \
	else \
		echo "Installing Typst..."; \
		ARCH=$$(uname -m); \
		case "$$ARCH" in \
			x86_64)  TARGET="x86_64-unknown-linux-musl" ;; \
			aarch64) TARGET="aarch64-unknown-linux-musl" ;; \
			*)       echo "Unsupported architecture: $$ARCH"; exit 1 ;; \
		esac; \
		TYPST_VERSION=$$(curl -fsSL "https://api.github.com/repos/typst/typst/releases/latest" | grep '"tag_name"' | head -1 | sed 's/.*"v\(.*\)".*/\1/'); \
		TMP=$$(mktemp -d); \
		curl -fsSL "https://github.com/typst/typst/releases/download/v$${TYPST_VERSION}/typst-$${TARGET}.tar.xz" | tar -xJ -C "$$TMP"; \
		mkdir -p "$$HOME/.local/bin"; \
		cp "$$TMP/typst-$${TARGET}/typst" "$$HOME/.local/bin/typst"; \
		chmod +x "$$HOME/.local/bin/typst"; \
		rm -rf "$$TMP"; \
		if ! echo "$$PATH" | tr ':' '\n' | grep -qx "$$HOME/.local/bin"; then \
			echo 'export PATH="$$HOME/.local/bin:$$PATH"' >> "$$HOME/.bashrc"; \
			echo "Added ~/.local/bin to PATH in .bashrc"; \
		fi; \
		export PATH="$$HOME/.local/bin:$$PATH"; \
		echo "Typst installed: $$(typst --version)"; \
	fi
	@if command -v apt-get >/dev/null 2>&1; then \
		echo "Installing Japanese fonts (Noto CJK)..."; \
		apt-get update -qq && apt-get install -y -qq fonts-noto-cjk 2>/dev/null || \
			echo "Warning: Could not install fonts-noto-cjk"; \
	fi
	@echo "Setup complete."

## PDFを削除
clean:
	rm -f $(PDFS)
	@echo "Cleaned all PDFs."

## ガイド一覧を表示
list:
	@echo "=== ガイド一覧 ==="
	@for d in $(GUIDE_DIRS); do \
		name=$$(basename $$d); \
		pdf="$$d/$$name.pdf"; \
		if [ -f "$$pdf" ]; then \
			echo "  [PDF] $$name  ($$pdf)"; \
		else \
			echo "  [---] $$name"; \
		fi; \
	done
	@if [ -z "$(GUIDE_DIRS)" ]; then \
		echo "  (ガイドなし。guides/ 以下にディレクトリを追加してください)"; \
	fi

## ヘルプ
help:
	@echo "使い方:"
	@echo "  make setup                          Typst + 日本語フォントをインストール"
	@echo "  make all                            すべてのガイドをビルド"
	@echo "  make guides/<名前>/<名前>.pdf       特定ガイドをビルド"
	@echo "  make clean                          PDFを削除"
	@echo "  make list                           ガイド一覧を表示"
	@echo "  make help                           このヘルプを表示"
