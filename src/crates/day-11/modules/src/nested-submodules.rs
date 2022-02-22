fn main() {
  my_module::print(my_module::submodule::MSG);
}

mod my_module {
  pub fn print(msg: &str) {
    println!("{}", msg);
  }

  pub mod submodule {
    pub const MSG: &str = "Hello world!";
  }
}
