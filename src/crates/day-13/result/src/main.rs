fn main() {
  let value = returns_ok();
  println!("{:?}", value);

  let value = returns_err();
  println!("{:?}", value);
}

fn returns_ok() -> Result<String, MyError> {
  Ok("This turned out great!".to_owned())
}

fn returns_err() -> Result<String, MyError> {
  Err(MyError("This failed horribly.".to_owned()))
}

#[derive(Debug)]
struct MyError(String);
