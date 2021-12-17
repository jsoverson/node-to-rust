use std::collections::HashMap;

fn main() {
  for_common();
  for_in();
  for_of();
  while_not_done();
  while_true();
  labels();
  loop_expressions();
}

fn for_common() {
  let max = 4;
  for i in 0..max {
    println!("{}", i);
  }
}

fn for_in() {
  let obj = HashMap::from([("key1", "value1"), ("key2", "value2")]);
  for prop in obj.keys() {
    println!("{}: {}", prop, obj.get(prop).unwrap());
  }
}

fn for_of() {
  let numbers = [1, 2, 3, 4, 5];
  for number in numbers {
    println!("{}", number);
  }
}

fn while_not_done() {
  struct Worker {
    data: Vec<&'static str>,
  }
  impl Worker {
    fn doWork(&mut self) -> Option<&'static str> {
      self.data.pop()
    }
  }
  let mut obj = Worker {
    data: vec!["a", "b", "c"],
  };

  while let Some(data) = obj.doWork() {
    println!("{}", data);
  }
}

fn while_true() {
  let mut n = 0;
  loop {
    n += 1;
    if n > 3 {
      break;
    }
  }
  println!("Finished. n={}", n);
}

#[allow(clippy::never_loop)]
fn labels() {
  println!("Start");
  'outer: loop {
    loop {
      break 'outer;
    }
  }
  println!("Finished");
}

#[allow(clippy::never_loop)]
fn loop_expressions() {
  let value = loop {
    if true {
      break "A";
    } else {
      break "B";
    }
  };
  println!("Loop value is: {}", value);
}
