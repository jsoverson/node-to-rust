use std::{collections::HashMap, error::Error, fs::read_to_string};

fn main() -> Result<(), Box<dyn Error>> {
  let html = render_markdown()?;
  // let result = weird_error()?; // This is a compilation error
  println!("{}", html);
  Ok(())
}

fn render_markdown() -> Result<String, Box<dyn Error>> {
  let file = std::env::var("MARKDOWN")?;
  let source = read_to_string(file)?;
  Ok(markdown::to_html(&source))
}

fn weird_error() -> Result<(), HashMap<String, String>> {
  Err(HashMap::new())
}
