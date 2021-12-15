fn main() {
  let closure = || {
    println!("Hi! I'm in a closure");
  };
  closure();

  let double = |num: i64| num + num;
  let num = 4;
  println!("{} + {} = {}", num, num, double(num));

  let name = "Rebecca";
  let closure = || {
    println!("Hi, {}.", name);
  };
  closure();

  let mut counter = 0;

  let mut closure = || {
    counter += 1;
    println!(
      "This closure has a counter. I've been run {} times.",
      counter
    );
  };
  closure();
  closure();
  closure();
  println!("The closure was called a total of {} times", counter);

  let adder = |left: i32, right: i32| {
    println!("{} + {} is {}", left, right, left + right);
    left + right
  };
  adder(4, 5);

  let name = "Dwayne".to_owned();
  let consuming_closure = || name.into_bytes();
  let bytes = consuming_closure();
  // let bytes = consuming_closure(); // ← compilation error

  let plus_two = make_adder(2);
  plus_two(23);

  let times_two = |i: i32| i * 2;
  let double_plus_two = compose(plus_two, times_two);
  println!("{} * 2 + 2 = {}", 10, double_plus_two(10));

  let fn_ref = regular_function;
  fn_ref();

  let square = DynamicBehavior::new(Box::new(|num: i64| num * num));
  println!("{} squared is {}", 5, square.run(5))
}

fn regular_function() {
  println!("I'm a regular function");
}

fn make_adder(left: i32) -> impl Fn(i32) -> i32 {
  move |right: i32| {
    println!("{} + {} is {}", left, right, left + right);
    left + right
  }
}

fn compose<T>(f: impl Fn(T) -> T, g: impl Fn(T) -> T) -> impl Fn(T) -> T {
  move |i: T| f(g(i))
}

struct DynamicBehavior<T> {
  closure: Box<dyn Fn(T) -> T>,
}

impl<T> DynamicBehavior<T> {
  fn new(closure: Box<dyn Fn(T) -> T>) -> Self {
    Self { closure }
  }
  fn run(&self, arg: T) -> T {
    (self.closure)(arg)
  }
}
