fn main() {
  let mut light = TrafficLight::new();
  println!("{}", light);
  println!("{:?}", light);
}

impl std::fmt::Display for TrafficLight {
  fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
    write!(f, "Traffic light is {}", self.color)
  }
}

#[derive(Debug)]
struct TrafficLight {
  color: String,
}

impl TrafficLight {
  pub fn new() -> Self {
    Self {
      color: "red".to_owned(),
    }
  }
}
