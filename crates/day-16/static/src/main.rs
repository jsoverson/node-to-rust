use std::fmt::Display;

fn main() {
  let r1;
  let r2;
  {
    static STATIC_EXAMPLE: i32 = 42;
    r1 = &STATIC_EXAMPLE;
    let x = "&'static str";
    r2 = x;
  }
  println!("&'static i32: {}", r1);
  println!("&'static str: {}", r2);

  let r3;

  {
    let string = "String".to_owned();

    static_bound(&string); // This is *not* an error
    r3 = &string; // This *is*
  }
  println!("{}", r3);
}

fn static_bound<T: Display + 'static>(t: &T) {
  println!("{}", t);
}
