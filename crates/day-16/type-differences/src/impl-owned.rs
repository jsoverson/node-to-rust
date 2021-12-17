use std::fmt::Display;

fn main() {
  let my_struct = MyStruct {};
  my_struct.print();

  let struct_ref = &my_struct;
  struct_ref.print();

  let mut mut_struct = MyStruct {};
  mut_struct.print();

  let ref_mut_struct = &mut_struct;
  ref_mut_struct.print();

  let mut_struct_ref = &mut mut_struct;
  mut_struct_ref.print();
}

trait Printer {
  fn print(&self);
}

struct MyStruct {}

impl Printer for MyStruct {
  fn print(&self) {
    println!("Foo")
  }
}

impl Printer for &MyStruct {
  fn print(&self) {
    println!("&Foo")
  }
}

impl Printer for &mut MyStruct {
  fn print(&self) {
    println!("&mut Foo")
  }
}
