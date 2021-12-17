use std::{slice::from_raw_parts, str::from_utf8_unchecked};

fn get_memory_location() -> (usize, usize) {
  let string = "Hello World!";
  let pointer = string.as_ptr() as usize;
  let length = string.len();
  (pointer, length)
  // `string` is dropped here.
  // It's no longer accessible, but the data lives on.
}

fn get_str_at_location(pointer: usize, length: usize) -> &'static str {
  // Notice the `unsafe {}` block. We can't do things like this without
  // acknowledging to Rust that we know this is dangerous.
  unsafe { from_utf8_unchecked(from_raw_parts(pointer as *const u8, length)) }
}

fn main() {
  let (pointer, length) = get_memory_location();
  let message = get_str_at_location(pointer, length);
  println!(
    "The {} bytes at 0x{:X} stored: {}",
    length, pointer, message
  );
  // If you want to see why dealing with raw pointers is dangerous,
  // uncomment this line.
  // let message = get_str_at_location(1000, 10);
}
