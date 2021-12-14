use std::fs::read_to_string;

fn main() -> Result<(), MyError> {
  let html = render_markdown()?;
  println!("{}", html);
  Ok(())
}

fn render_markdown() -> Result<String, MyError> {
  let file = std::env::var("MARKDOWN")?;
  let source = read_to_string(file)?;
  Ok(markdown::to_html(&source))
}

#[derive(snafu::Snafu, Debug)]
enum MyError {
  #[snafu(display("Environment variable not found"))]
  EnvironmentVariableNotFound { source: std::env::VarError },

  #[snafu(display("IO Error: {}", source.to_string()))]
  IOError { source: std::io::Error },
}

impl From<std::env::VarError> for MyError {
  fn from(source: std::env::VarError) -> Self {
    Self::EnvironmentVariableNotFound { source }
  }
}

impl From<std::io::Error> for MyError {
  fn from(source: std::io::Error) -> Self {
    Self::IOError { source }
  }
}
