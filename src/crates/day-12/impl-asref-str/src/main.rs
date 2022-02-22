use std::str::FromStr; // Imported to use Ipv4Addr::from_str

fn main() {
  let ip_address = std::net::Ipv4Addr::from_str("127.0.0.1").unwrap();
  let string_slice = "string slice";
  let string_proper = "String proper".to_owned();
  needs_string(string_slice);
  needs_string("Literal string");
  needs_string(string_proper);
  // needs_string(ip_address); // Fails now
}

fn needs_string<T: AsRef<str>>(almost_string: T) {
  let real_string = almost_string.as_ref().to_owned();
  println!("{}", real_string);
}

// fn needs_string(almost_string: impl AsRef<str>) {
//   let real_string = almost_string.as_ref().to_owned();
//   println!("{}", real_string);
// }

// fn needs_string<T>(almost_string: T)
// where
//   T: AsRef<str>,
// {
//   let real_string = almost_string.as_ref().to_owned();
//   println!("{}", real_string);
// }
