# Advent of Rust: 24 Days From node.js to Rust

This repository is for code related to the guide at: https://vino.dev/blog/node-to-rust-day-1-rustup/

## Running projects

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
