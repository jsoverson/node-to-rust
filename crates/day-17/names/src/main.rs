#[derive(serde::Serialize, serde::Deserialize)]
struct Names {
  names: Vec<String>,
}

impl Names {
  fn search<T: AsRef<str>>(&self, regex_string: T) -> impl Iterator<Item = &String> {
    let regex = regex::Regex::new(regex_string.as_ref()).unwrap();
    self.names.iter().filter(move |name| regex.is_match(name))
  }
}

fn main() {
  let raw = include_str!("./names.json");
  let names: Names = serde_json::from_str(raw).unwrap();
  let mut result = names.search("er$");

  println!("First 5 names that end in 'er':");

  for i in 0..5 {
    println!("{}: {}", i + 1, result.next().unwrap());
  }
}
