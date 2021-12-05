# Advent of Rust: 24 Days From node.js to Rust

This repository is for code related to the guide at: https://vino.dev/blog/node-to-rust-day-1-rustup/

## Running projects

### Day 4

- `cargo run -p day-4-hello-world`
- `cargo run -p day-4-strings-wtf-1` - intentionally does not compile.
- `cargo run -p day-4-strings-wtf-2` - intentionally does not compile.

### Day 5

Reassigning:

- JS: `node javascript/day-5/let-vs-const/reassigning.js`
- Rust: `cargo run -p day-5-let-vs-const --bin reassigning`
- `cargo run -p day-5-let-vs-const --bin reassigning-wrong-type` - intentionally does not compile

Borrowing:

- `cargo run -p day-5-borrowing --bin borrow`
- `cargo run -p day-5-borrowing --bin mutable-borrow` - intentionally does not compile
