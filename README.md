# From JavaScript to Rust ebook

This repository houses an ebook-ified version of the 24+ post series started on [vino.dev](https://vino.dev/blog/node-to-rust-day-1-rustup/).

## How to build

The ebook is built using [asciidoctor](https://docs.asciidoctor.org/) and requires ruby >2.3.

Install the ruby dependencies via `make deps`

```console
$ make deps
```

Build a PDF via the command `make book`

```console
$ make book
```

## Running code and projects

All code are housed in the `src/` directory.

### Day 4

- `cargo run -p day-4-hello-world`
- `cargo run -p day-4-strings-wtf-1` - intentionally does not compile.
- `cargo run -p day-4-strings-wtf-2` - intentionally does not compile.

### Day 5

#### Reassigning

- JS: `node javascript/day-5/let-vs-const/reassigning.js`
- Rust: `cargo run -p day-5-let-vs-const --bin reassigning`
- `cargo run -p day-5-let-vs-const --bin reassigning-wrong-type` - intentionally does not compile

#### Borrowing

- `cargo run -p day-5-borrowing --bin borrow`
- `cargo run -p day-5-borrowing --bin mutable-borrow` - intentionally does not compile

### Day 6

- `cargo run -p day-6-loads-of-strs --bin 200-unique-prints`
- `cargo run -p day-6-loads-of-strs --bin 200-prints`
- `cargo run -p day-6-loads-of-strs --bin 200-empty-prints`
- `cargo run -p day-6-loads-of-strs --bin one-print`

### Day 7

#### Syntax

- `cargo run -p day-7-syntax`

### Day 8

#### Maps

- `ts-node javascript/day-8/src/maps.ts`
- `cargo run -p day-8-maps`

#### Structs

- `ts-node javascript/day-8/src/structs.ts`
- `cargo run -p day-8-structs`

### Day 9

### Day 10

### Day 11

#### Modules

- `cargo run -p day-11-modules --bin nested-submodules`
- `cargo run -p day-11-traffic-light`

### Day 12

- `cargo run -p day-12-impl-tostring`
- `cargo run -p day-12-impl-asref-str`

### Day 13

- `cargo run -p day-13-option`
- `cargo run -p day-13-result`
- `cargo run -p day-13-question-mark`

### Day 14

#### From/Into

- `cargo run -p day-14-from-into`

#### Errors

These examples require setting an environment variable. How to do that in your environment might look different.

- `MARKDOWN=README.md cargo run -p day-14-boxed-errors`
- `MARKDOWN=README.md cargo run -p day-14-custom-error-type`
- `MARKDOWN=README.md cargo run -p day-14-thiserror`
- `MARKDOWN=README.md cargo run -p day-14-error-chain`
- `MARKDOWN=README.md cargo run -p day-14-snafu`

### Day 16

#### Closures

- `cargo run -p day-15-closures`

### Day 16

#### Type differences

- `cargo run -p day-16-type-differences --bin impl-owned`
- `cargo run -p day-16-type-differences --bin impl-borrowed`

#### `'static`

- `cargo run -p day-16-static` - intentionally does not compile
- `cargo run -p day-16-static-bounds` - intentionally does not compile

#### Lifetime elision

- `cargo run -p day-16-elision`

#### Unsafe pointers

- `cargo run -p day-16-unsafe-pointers`

### Day 17

#### Arrays

- `cargo run -p day-17-arrays`
- `ts-node javascript/day-17/src/arrays.ts`

#### Iterators

- `cargo run -p day-17-iterators`
- `ts-node javascript/day-17/src/iterators.ts`

#### Names example

- `cargo run -p day-17-names`

### Day 18

- `cargo run -p day-18-async --bin send-sync`
- `cargo run -p day-18-async --bin simple`
- `cargo run -p day-18-async --bin lazy`
- `cargo run -p day-18-async --bin fs`
- `cargo run -p day-18-async --bin async-blocks`

### Day 19

First you must cd into `crates/day-19/project`

- `cargo test`
- `cargo run -p cli`

### Day 20

First you must cd into `crates/day-20/project`

- `RUST_LOG=cli=debug cargo run -p cli`

### Day 21

#### waPC runner

First you must cd into `crates/day-21/project`

- `cargo run -p cli -- crates/my-lib/tests/test.wasm hello "Potter"`

#### waPC guest (hello)

First you must cd into `crates/day-21/wapc-guest`

- Build with `make`

### Day 22

#### Serde

- `cargo run -p day-22-serde`

#### waPC runner

First you must cd into `crates/day-22/project`

- `cargo run -p cli -- crates/my-lib/tests/test.wasm hello hello.json`
- `cargo run -p cli -- ./blog.wasm render ./blog.json`

#### waPC guest (blog)

First you must cd into `crates/day-22/wapc-guest`

- Build with `make`

### Day 23

- `cargo run -p day-23-rc-arc --bin references`
- `cargo run -p day-23-rc-arc --bin rc`
- `cargo run -p day-23-rc-arc --bin arc`
- `cargo run -p day-23-rc-arc --bin rwlock`
- `cargo run -p day-23-rc-arc --bin async` - intentionally does not compile

## License

Book: Creative Commons BY-NC 4.0
Code: Creative Commons BY 4.0
