use std::fmt::Display;

fn main() {
  let traffic_light = TrafficLight::new();
  let house_light = HouseLight::new();

  print_state(&traffic_light);
  print_state(&house_light);
}

fn print_state(light: &impl Light) {
  println!("{}'s state is : {:?}", light.get_name(), light.get_state());
}

trait Light {
  fn get_name(&self) -> &str;
  fn get_state(&self) -> &dyn std::fmt::Debug;
}

impl Light for HouseLight {
  fn get_name(&self) -> &str {
    "House light"
  }

  fn get_state(&self) -> &dyn std::fmt::Debug {
    &self.on
  }
}

impl Light for TrafficLight {
  fn get_name(&self) -> &str {
    "Traffic light"
  }

  fn get_state(&self) -> &dyn std::fmt::Debug {
    &self.color
  }
}

impl std::fmt::Display for TrafficLight {
  fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
    write!(f, "Traffic light is {}", self.color)
  }
}

#[derive(Debug)]
struct TrafficLight {
  color: TrafficLightColor,
}

impl TrafficLight {
  pub fn new() -> Self {
    Self {
      color: TrafficLightColor::Red,
    }
  }

  pub fn turn_green(&mut self) {
    self.color = TrafficLightColor::Green
  }
}

#[derive(Debug)]
enum TrafficLightColor {
  Red,
  Yellow,
  Green,
}

impl Display for TrafficLightColor {
  fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
    let color_string = match self {
      TrafficLightColor::Green => "green",
      TrafficLightColor::Red => "red",
      TrafficLightColor::Yellow => "yellow",
    };
    write!(f, "{}", color_string)
  }
}

#[derive(Debug)]
struct HouseLight {
  on: bool,
}

impl Display for HouseLight {
  fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
    write!(f, "Houselight is {}", if self.on { "on" } else { "off" })
  }
}

impl HouseLight {
  pub fn new() -> Self {
    Self { on: false }
  }
}
