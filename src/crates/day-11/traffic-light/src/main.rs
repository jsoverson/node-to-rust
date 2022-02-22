use crate::light::house_light::HouseLight;
use crate::light::traffic_light::TrafficLight;
use crate::light::Light;

mod light;

fn main() {
  let traffic_light = TrafficLight::new();
  let house_light = HouseLight::new();

  print_state(&traffic_light);
  print_state(&house_light);
}

fn print_state(light: &impl Light) {
  println!("{}'s state is : {:?}", light.get_name(), light.get_state());
}
