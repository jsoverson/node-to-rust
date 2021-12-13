use std::fs::read_to_string;

fn main() -> Result<(), std::io::Error> {
  let html = render_markdown("./README.md")?;
  println!("{}", html);
  Ok(())
}

fn render_markdown(file: &str) -> Result<String, std::io::Error> {
  let source = read_to_string(file)?;
  Ok(markdown::to_html(&source))
}
