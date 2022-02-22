#![recursion_limit = "1024"]
use std::fs::read_to_string;

error_chain::error_chain! {
  foreign_links {
    EnvironmentVariableNotFound(::std::env::VarError);
    IOError(::std::io::Error);
  }
}

fn main() -> Result<()> {
  let html = render_markdown()?;
  println!("{}", html);
  Ok(())
}

fn render_markdown() -> Result<String> {
  let file = std::env::var("MARKDOWN")?;
  let source = read_to_string(file)?;
  Ok(markdown::to_html(&source))
}
