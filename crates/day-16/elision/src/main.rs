fn omits_annotations(list: &[String]) -> Option<&String> {
  list.get(0)
}

fn has_annotations<'a>(list: &'a [String]) -> Option<&'a String> {
  list.get(1)
}

fn main() {
  let authors = vec!["Samuel Clemens".to_owned(), "Jane Austen".to_owned()];
  let value = omits_annotations(&authors).unwrap();
  println!("The first author is '{}'", value);
  let value = has_annotations(&authors).unwrap();
  println!("The second author is '{}'", value);
}
