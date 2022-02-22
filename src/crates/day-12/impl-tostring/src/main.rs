use std::str::FromStr; // Imported to use Ipv4Addr::from_str

fn main() {
  let ip_address = std::net::Ipv4Addr::from_str("127.0.0.1").unwrap();
  let string_proper = "String proper".to_owned();
  let string_slice = "string slice";
  needs_string(string_slice);
  needs_string("Literal string");
  needs_string(string_proper);
  needs_string(ip_address);
}

fn needs_string<T: ToString>(almost_string: T) {
  let real_string = almost_string.to_string();
  println!("{}", real_string);
}

// fn needs_string(almost_string: impl ToString) {
//   let real_string = almost_string.to_string();
//   println!("{}", real_string);
// }

// fn needs_string<T>(almost_string: T)
// where
//   T: ToString,
// {
//   let real_string = almost_string.to_string();
//   println!("{}", real_string);
// }
