use std::time::Instant;

fn main() {
  let some = returns_some();
  println!("{:?}", some);

  let none = returns_none();
  println!("{:?}", none);

  let default_string = "Default value".to_owned();

  let unwrap_or = returns_none().unwrap_or(default_string);
  println!("returns_none().unwrap_or(...): {:?}", unwrap_or);

  let unwrap_or_else = returns_none()
    .unwrap_or_else(|| format!("Default value from a function at time {:?}", Instant::now()));

  println!(
    "returns_none().unwrap_or_else(|| {{...}}): {:?}",
    unwrap_or_else
  );

  let unwrap_or_default = returns_none().unwrap_or_default();

  println!(
    "returns_none().unwrap_or_default(): {:?}",
    unwrap_or_default
  );

  let match_value = match returns_some() {
    Some(val) => val,
    None => "My default value".to_owned(),
  };

  println!("match {{...}}: {:?}", match_value);

  if let Some(val) = returns_some() {
    println!("if let : {:?}", val);
  }
}

fn returns_some() -> Option<String> {
  Some("my string".to_owned())
}

fn returns_none() -> Option<String> {
  None
}
