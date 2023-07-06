# Enforce bash as the shell for consistency
SHELL := bash
# Use bash strict mode
.SHELLFLAGS := -eu -o pipefail -c
MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules

.PHONY: book
book:
	bundle exec asciidoctor-pdf -a source-highlighter=rouge book/book.adoc --o from-javascript-to-rust.pdf

.PHONY: book-epub
book-epub:
	bundle exec asciidoctor-epub3 -a source-highlighter=rouge book/book.adoc --o from-javascript-to-rust.epub

.PHONY: deps
deps:
	bundle install

