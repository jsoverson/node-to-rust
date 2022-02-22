pub mod error;

use std::path::PathBuf;

type Result<T> = std::result::Result<T, error::Error>;

#[tokio::main]
async fn main() -> Result<()> {
    ls(None).await?;
    Ok(())
}

async fn ls(dir: Option<PathBuf>) -> Result<()> {
    let dir = match dir {
        Some(value) => value,
        None => std::env::current_dir()?,
    };

    let mut files = tokio::fs::read_dir(dir).await?;
    while let Some(file) = files.next_entry().await? {
        println!("{}", file.file_name().to_string_lossy())
    }
    Ok(())
}
