fn main() {
  let string = "Hello, world".to_owned();
  let wrapper: MyStringWrapper = string.into();
  println!("{:?}", wrapper);
  let wrapper2 = MyStringWrapper::from("generated from MyStringWrapper::from".to_owned());
  println!("{:?}", wrapper2);

  let string = "Hello, world again".to_owned();
  let wrapper3: ADifferentStringWrapper = string.try_into().unwrap();
  println!("{:?}", wrapper3);
  let wrapper4 = ADifferentStringWrapper::try_from(
    "generated from ADifferentStringWrapper::try_from".to_owned(),
  );
  println!("{:?}", wrapper4);
}

#[derive(Debug)]
struct MyStringWrapper(String);

impl From<String> for MyStringWrapper {
  fn from(value: String) -> Self {
    Self(value)
  }
}

#[derive(Debug)]
struct ADifferentStringWrapper(String);

impl TryFrom<String> for ADifferentStringWrapper {
  type Error = String;

  fn try_from(value: String) -> Result<Self, Self::Error> {
    Ok(Self(value))
  }
}
