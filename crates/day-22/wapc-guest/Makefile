.PHONY: all deps codegen build clean doc test

all: deps codegen build

deps:

codegen:
	wapc generate codegen.yaml

build:
	cargo build --target wasm32-unknown-unknown --release
	mkdir -p build && cp target/wasm32-unknown-unknown/release/*.wasm build/

# Rust builds accrue disk space over time (specifically the target directory),
# so running `make clean` should be done periodically.
clean:
	cargo clean
	rm -Rf build

doc:

test: build
	cargo test
