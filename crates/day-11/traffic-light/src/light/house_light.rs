use std::fmt::Display;

use super::Light;

impl Light for HouseLight {
  fn get_name(&self) -> &str {
    "House light"
  }

  fn get_state(&self) -> &dyn std::fmt::Debug {
    &self.on
  }
}

#[derive(Debug)]
pub(crate) struct HouseLight {
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
